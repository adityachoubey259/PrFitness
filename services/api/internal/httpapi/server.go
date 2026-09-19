package httpapi

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"net"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"prfitness/api/internal/security"
)

type accountContextKey struct{}

const maxActiveSessionsPerAccount = 2

var errSessionLimit = errors.New("account session limit reached")

type rateBucket struct {
	window time.Time
	count  int
}

type Server struct {
	pool      *pgxpool.Pool
	jwtSecret []byte

	limitMu sync.Mutex
	limits  map[string]rateBucket
}

func New(pool *pgxpool.Pool, jwtSecret []byte) *Server {
	return &Server{
		pool:      pool,
		jwtSecret: jwtSecret,
		limits:    make(map[string]rateBucket),
	}
}

func (s *Server) Ready() bool {
	return s.pool != nil && len(s.jwtSecret) >= 32
}

type credentialsRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
	DeviceID string `json:"deviceId"`
}

type refreshRequest struct {
	RefreshToken string `json:"refreshToken"`
}

type accountResponse struct {
	ID    string `json:"id"`
	Email string `json:"email"`
}

type authResponse struct {
	AccessToken  string          `json:"accessToken"`
	RefreshToken string          `json:"refreshToken"`
	Account      accountResponse `json:"account"`
}

func (s *Server) Register(w http.ResponseWriter, r *http.Request) {
	if !s.allowAuth(r) {
		writeError(w, http.StatusTooManyRequests, "too many authentication attempts")
		return
	}
	if !s.requireReady(w) {
		return
	}

	var request credentialsRequest
	if err := decodeJSON(w, r, &request); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request")
		return
	}

	loginID, err := normalizeEmail(request.Email)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	deviceID, err := normalizeDeviceID(request.DeviceID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid device")
		return
	}

	hash, err := security.HashPassword(request.Password)
	if err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	accountID, err := randomUUID()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "unable to create account")
		return
	}

	_, err = s.pool.Exec(
		r.Context(),
		`INSERT INTO prfitness.accounts (id, email, password_hash)
         VALUES ($1, $2, $3)`,
		accountID,
		loginID,
		hash,
	)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			writeError(w, http.StatusConflict, "account ID already exists")
			return
		}
		writeError(w, http.StatusInternalServerError, "account creation failed")
		return
	}

	session, err := s.issueSession(
		r.Context(),
		accountID,
		loginID,
		deviceID,
	)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "unable to create session")
		return
	}

	writeJSON(w, http.StatusCreated, session)
}

func (s *Server) Login(w http.ResponseWriter, r *http.Request) {
	if !s.allowAuth(r) {
		writeError(w, http.StatusTooManyRequests, "too many authentication attempts")
		return
	}
	if !s.requireReady(w) {
		return
	}

	var request credentialsRequest
	if err := decodeJSON(w, r, &request); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request")
		return
	}

	loginID, err := normalizeEmail(request.Email)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "invalid credentials")
		return
	}

	deviceID, err := normalizeDeviceID(request.DeviceID)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "invalid credentials")
		return
	}

	var accountID string
	var passwordHash string

	err = s.pool.QueryRow(
		r.Context(),
		`SELECT id::text, password_hash
         FROM prfitness.accounts
         WHERE email = $1`,
		loginID,
	).Scan(&accountID, &passwordHash)

	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusUnauthorized, "invalid credentials")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "login failed")
		return
	}

	ok, err := security.VerifyPassword(request.Password, passwordHash)
	if err != nil || !ok {
		writeError(w, http.StatusUnauthorized, "invalid credentials")
		return
	}

	session, err := s.issueSession(
		r.Context(),
		accountID,
		loginID,
		deviceID,
	)
	if errors.Is(err, errSessionLimit) {
		writeError(
			w,
			http.StatusConflict,
			"this account already has 2 active devices; sign out from one device first",
		)
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "unable to create session")
		return
	}

	writeJSON(w, http.StatusOK, session)
}

func (s *Server) Refresh(w http.ResponseWriter, r *http.Request) {
	if !s.allowAuth(r) {
		writeError(w, http.StatusTooManyRequests, "too many authentication attempts")
		return
	}
	if !s.requireReady(w) {
		return
	}

	var request refreshRequest
	if err := decodeJSON(w, r, &request); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request")
		return
	}
	if len(request.RefreshToken) < 32 || len(request.RefreshToken) > 512 {
		writeError(w, http.StatusUnauthorized, "invalid refresh token")
		return
	}

	oldHash := sha256.Sum256([]byte(request.RefreshToken))

	tx, err := s.pool.Begin(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, "refresh failed")
		return
	}
	defer func() {
		_ = tx.Rollback(context.Background())
	}()

	var tokenID string
	var accountID string
	var loginID string
	var deviceID string

	err = tx.QueryRow(
		r.Context(),
		`SELECT rt.id::text, a.id::text, a.email, rt.device_id
         FROM prfitness.refresh_tokens rt
         JOIN prfitness.accounts a ON a.id = rt.account_id
         WHERE rt.token_hash = $1
           AND rt.revoked_at IS NULL
           AND rt.expires_at > NOW()
         FOR UPDATE`,
		oldHash[:],
	).Scan(
		&tokenID,
		&accountID,
		&loginID,
		&deviceID,
	)

	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusUnauthorized, "invalid refresh token")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "refresh failed")
		return
	}

	if _, err = tx.Exec(
		r.Context(),
		`UPDATE prfitness.refresh_tokens
         SET revoked_at = NOW()
         WHERE id = $1`,
		tokenID,
	); err != nil {
		writeError(w, http.StatusInternalServerError, "refresh failed")
		return
	}

	accessToken, err := security.IssueAccessToken(
		accountID,
		s.jwtSecret,
		time.Now().UTC(),
		15*time.Minute,
	)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "refresh failed")
		return
	}

	newRefreshToken, err := randomOpaqueToken()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "refresh failed")
		return
	}

	newHash := sha256.Sum256([]byte(newRefreshToken))

	refreshID, err := randomUUID()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "refresh failed")
		return
	}

	_, err = tx.Exec(
		r.Context(),
		`INSERT INTO prfitness.refresh_tokens
         (id, account_id, token_hash, device_id, expires_at)
         VALUES ($1, $2, $3, $4, NOW() + INTERVAL '30 days')`,
		refreshID,
		accountID,
		newHash[:],
		deviceID,
	)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "refresh failed")
		return
	}

	if err = tx.Commit(r.Context()); err != nil {
		writeError(w, http.StatusInternalServerError, "refresh failed")
		return
	}

	writeJSON(
		w,
		http.StatusOK,
		authResponse{
			AccessToken:  accessToken,
			RefreshToken: newRefreshToken,
			Account: accountResponse{
				ID:    accountID,
				Email: loginID,
			},
		},
	)
}

func (s *Server) Logout(w http.ResponseWriter, r *http.Request) {
	if !s.requireReady(w) {
		return
	}

	var request refreshRequest
	if err := decodeJSON(w, r, &request); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	tokenHash := sha256.Sum256([]byte(request.RefreshToken))
	_, _ = s.pool.Exec(
		r.Context(),
		`UPDATE prfitness.refresh_tokens
         SET revoked_at = NOW()
         WHERE token_hash = $1 AND revoked_at IS NULL`,
		tokenHash[:],
	)
	w.WriteHeader(http.StatusNoContent)
}

type syncRequest struct {
	Cursor   int64        `json:"cursor"`
	DeviceID string       `json:"deviceId"`
	Changes  []syncChange `json:"changes"`
}

type syncChange struct {
	EntityType  string          `json:"entityType"`
	EntityID    string          `json:"entityId"`
	Operation   string          `json:"operation"`
	BaseVersion int64           `json:"baseVersion"`
	Payload     json.RawMessage `json:"payload"`
}

type acceptedChange struct {
	EntityType    string `json:"entityType"`
	EntityID      string `json:"entityId"`
	ServerVersion int64  `json:"serverVersion"`
}

type syncRecord struct {
	EntityType    string          `json:"entityType"`
	EntityID      string          `json:"entityId"`
	Payload       json.RawMessage `json:"payload"`
	Deleted       bool            `json:"deleted"`
	ServerVersion int64           `json:"serverVersion"`
}

type syncResponse struct {
	Accepted  []acceptedChange `json:"accepted"`
	Conflicts []syncRecord     `json:"conflicts"`
	Records   []syncRecord     `json:"records"`
	Cursor    int64            `json:"cursor"`
	HasMore   bool             `json:"hasMore"`
}

var allowedEntityTypes = map[string]struct{}{
	"profile":            {},
	"food":               {},
	"activity":           {},
	"water":              {},
	"study":              {},
	"goal":               {},
	"goal_completion":    {},
	"routine":            {},
	"routine_completion": {},
	"reminder":           {},
	"weight":             {},
}

func (s *Server) Sync(w http.ResponseWriter, r *http.Request) {
	if !s.requireReady(w) {
		return
	}

	accountID, ok := accountIDFromContext(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	var request syncRequest
	if err := decodeJSON(w, r, &request); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	if strings.TrimSpace(request.DeviceID) == "" {
		writeError(w, http.StatusBadRequest, "deviceId is required")
		return
	}
	if len(request.Changes) > 500 {
		writeError(w, http.StatusBadRequest, "too many changes in one request")
		return
	}

	tx, err := s.pool.Begin(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, "sync unavailable")
		return
	}
	defer func() { _ = tx.Rollback(context.Background()) }()

	response := syncResponse{
		Accepted:  []acceptedChange{},
		Conflicts: []syncRecord{},
		Records:   []syncRecord{},
		Cursor:    request.Cursor,
	}

	for _, change := range request.Changes {
		if _, allowed := allowedEntityTypes[change.EntityType]; !allowed {
			writeError(w, http.StatusBadRequest, "unsupported entity type")
			return
		}
		if strings.TrimSpace(change.EntityID) == "" || len(change.EntityID) > 160 {
			writeError(w, http.StatusBadRequest, "invalid entity id")
			return
		}
		if change.Operation != "upsert" && change.Operation != "delete" {
			writeError(w, http.StatusBadRequest, "invalid sync operation")
			return
		}
		if change.Operation == "upsert" &&
			(len(change.Payload) == 0 || !json.Valid(change.Payload)) {
			writeError(w, http.StatusBadRequest, "invalid sync payload")
			return
		}

		var existing syncRecord
		err := tx.QueryRow(
			r.Context(),
			`SELECT entity_type, entity_id, COALESCE(payload::text, 'null'), deleted, server_version
             FROM prfitness.sync_records
             WHERE account_id = $1 AND entity_type = $2 AND entity_id = $3
             FOR UPDATE`,
			accountID,
			change.EntityType,
			change.EntityID,
		).Scan(
			&existing.EntityType,
			&existing.EntityID,
			&existing.Payload,
			&existing.Deleted,
			&existing.ServerVersion,
		)

		if err != nil && !errors.Is(err, pgx.ErrNoRows) {
			writeError(w, http.StatusInternalServerError, "sync read failed")
			return
		}
		if err == nil && existing.ServerVersion > change.BaseVersion {
			response.Conflicts = append(response.Conflicts, existing)
			continue
		}

		deleted := change.Operation == "delete"
		var payload any
		if !deleted {
			payload = string(change.Payload)
		}

		var serverVersion int64
		err = tx.QueryRow(
			r.Context(),
			`INSERT INTO prfitness.sync_records
             (account_id, entity_type, entity_id, payload, deleted, device_id, updated_at, server_version)
             VALUES ($1, $2, $3, $4::jsonb, $5, $6, NOW(), nextval('prfitness.sync_version_seq'))
             ON CONFLICT (account_id, entity_type, entity_id)
             DO UPDATE SET
               payload = EXCLUDED.payload,
               deleted = EXCLUDED.deleted,
               device_id = EXCLUDED.device_id,
               updated_at = NOW(),
               server_version = nextval('prfitness.sync_version_seq')
             RETURNING server_version`,
			accountID,
			change.EntityType,
			change.EntityID,
			payload,
			deleted,
			request.DeviceID,
		).Scan(&serverVersion)

		if err != nil {
			writeError(w, http.StatusInternalServerError, "sync write failed")
			return
		}

		response.Accepted = append(response.Accepted, acceptedChange{
			EntityType:    change.EntityType,
			EntityID:      change.EntityID,
			ServerVersion: serverVersion,
		})
	}

	rows, err := tx.Query(
		r.Context(),
		`SELECT entity_type, entity_id, COALESCE(payload::text, 'null'), deleted, server_version
         FROM prfitness.sync_records
         WHERE account_id = $1 AND server_version > $2
         ORDER BY server_version ASC
         LIMIT 1001`,
		accountID,
		request.Cursor,
	)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "sync pull failed")
		return
	}
	defer rows.Close()

	for rows.Next() {
		var record syncRecord
		if err := rows.Scan(
			&record.EntityType,
			&record.EntityID,
			&record.Payload,
			&record.Deleted,
			&record.ServerVersion,
		); err != nil {
			writeError(w, http.StatusInternalServerError, "sync pull failed")
			return
		}
		response.Records = append(response.Records, record)
	}
	if err := rows.Err(); err != nil {
		writeError(w, http.StatusInternalServerError, "sync pull failed")
		return
	}

	if len(response.Records) > 1000 {
		response.HasMore = true
		response.Records = response.Records[:1000]
	}
	if len(response.Records) > 0 {
		response.Cursor = response.Records[len(response.Records)-1].ServerVersion
	}

	if err := tx.Commit(r.Context()); err != nil {
		writeError(w, http.StatusInternalServerError, "sync commit failed")
		return
	}

	writeJSON(w, http.StatusOK, response)
}

func (s *Server) RequireAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		const prefix = "Bearer "
		header := strings.TrimSpace(r.Header.Get("Authorization"))
		if !strings.HasPrefix(header, prefix) {
			writeError(w, http.StatusUnauthorized, "missing bearer token")
			return
		}

		claims, err := security.ParseAccessToken(
			strings.TrimSpace(strings.TrimPrefix(header, prefix)),
			s.jwtSecret,
		)
		if err != nil {
			writeError(w, http.StatusUnauthorized, "invalid or expired access token")
			return
		}

		ctx := context.WithValue(r.Context(), accountContextKey{}, claims.UserID)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func (s *Server) issueSession(
	ctx context.Context,
	accountID string,
	email string,
	deviceID string,
) (authResponse, error) {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return authResponse{}, err
	}
	defer func() {
		_ = tx.Rollback(context.Background())
	}()

	var lockedAccountID string
	if err = tx.QueryRow(
		ctx,
		`SELECT id::text
         FROM prfitness.accounts
         WHERE id = $1
         FOR UPDATE`,
		accountID,
	).Scan(&lockedAccountID); err != nil {
		return authResponse{}, err
	}

	if _, err = tx.Exec(
		ctx,
		`UPDATE prfitness.refresh_tokens
         SET revoked_at = NOW()
         WHERE account_id = $1
           AND device_id = $2
           AND revoked_at IS NULL`,
		accountID,
		deviceID,
	); err != nil {
		return authResponse{}, err
	}

	var active int
	if err = tx.QueryRow(
		ctx,
		`SELECT COUNT(*)
         FROM prfitness.refresh_tokens
         WHERE account_id = $1
           AND revoked_at IS NULL
           AND expires_at > NOW()`,
		accountID,
	).Scan(&active); err != nil {
		return authResponse{}, err
	}

	if sessionLimitReached(active) {
		return authResponse{}, errSessionLimit
	}

	accessToken, err := security.IssueAccessToken(
		accountID,
		s.jwtSecret,
		time.Now().UTC(),
		15*time.Minute,
	)
	if err != nil {
		return authResponse{}, err
	}

	refreshToken, err := randomOpaqueToken()
	if err != nil {
		return authResponse{}, err
	}

	hash := sha256.Sum256([]byte(refreshToken))

	refreshID, err := randomUUID()
	if err != nil {
		return authResponse{}, err
	}

	_, err = tx.Exec(
		ctx,
		`INSERT INTO prfitness.refresh_tokens
         (id, account_id, token_hash, device_id, expires_at)
         VALUES ($1, $2, $3, $4, NOW() + INTERVAL '30 days')`,
		refreshID,
		accountID,
		hash[:],
		deviceID,
	)
	if err != nil {
		return authResponse{}, err
	}

	if err = tx.Commit(ctx); err != nil {
		return authResponse{}, err
	}

	return authResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		Account: accountResponse{
			ID:    accountID,
			Email: email,
		},
	}, nil
}

func (s *Server) requireReady(w http.ResponseWriter) bool {
	if s.Ready() {
		return true
	}
	writeError(w, http.StatusServiceUnavailable, "authentication and sync are not configured")
	return false
}

func (s *Server) allowAuth(r *http.Request) bool {
	host := r.RemoteAddr
	if parsedHost, _, err := net.SplitHostPort(r.RemoteAddr); err == nil {
		host = parsedHost
	}

	now := time.Now()
	s.limitMu.Lock()
	defer s.limitMu.Unlock()

	if len(s.limits) > 10000 {
		for key, bucket := range s.limits {
			if now.Sub(bucket.window) > 10*time.Minute {
				delete(s.limits, key)
			}
		}
	}

	bucket := s.limits[host]
	if bucket.window.IsZero() || now.Sub(bucket.window) >= time.Minute {
		s.limits[host] = rateBucket{window: now, count: 1}
		return true
	}
	if bucket.count >= 20 {
		return false
	}
	bucket.count++
	s.limits[host] = bucket
	return true
}

func normalizeEmail(source string) (string, error) {
	value := strings.ToLower(strings.TrimSpace(source))
	if len(value) < 3 || len(value) > 64 {
		return "", errors.New("account ID must contain 3–64 characters")
	}

	for _, char := range value {
		valid := char >= 'a' && char <= 'z' ||
			char >= '0' && char <= '9' ||
			char == '@' ||
			char == '.' ||
			char == '_' ||
			char == '-'
		if !valid {
			return "", errors.New("account ID contains unsupported characters")
		}
	}

	return value, nil
}

func normalizeDeviceID(source string) (string, error) {
	value := strings.TrimSpace(source)
	if len(value) < 24 || len(value) > 128 {
		return "", errors.New("invalid device ID")
	}

	for _, char := range value {
		valid := char >= 'a' && char <= 'z' ||
			char >= 'A' && char <= 'Z' ||
			char >= '0' && char <= '9' ||
			char == '_' ||
			char == '-'
		if !valid {
			return "", errors.New("invalid device ID")
		}
	}

	return value, nil
}

func sessionLimitReached(active int) bool {
	return active >= maxActiveSessionsPerAccount
}

func randomOpaqueToken() (string, error) {
	bytes := make([]byte, 32)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(bytes), nil
}

func randomUUID() (string, error) {
	bytes := make([]byte, 16)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	value := hex.EncodeToString(bytes)
	return value[0:8] + "-" + value[8:12] + "-" + value[12:16] + "-" + value[16:20] + "-" + value[20:32], nil
}

func accountIDFromContext(ctx context.Context) (string, bool) {
	value, ok := ctx.Value(accountContextKey{}).(string)
	return value, ok && value != ""
}

func decodeJSON(w http.ResponseWriter, r *http.Request, target any) error {
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil {
		return err
	}
	if err := decoder.Decode(&struct{}{}); err != io.EOF {
		return errors.New("request body must contain exactly one JSON object")
	}
	return nil
}

func writeError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, map[string]string{"error": message})
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}
