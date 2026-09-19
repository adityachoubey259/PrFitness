package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"prfitness/api/internal/httpapi"
)

type healthResponse struct {
	Service  string `json:"service"`
	Status   string `json:"status"`
	Database string `json:"database"`
	AuthSync string `json:"authSync"`
	TimeUTC  string `json:"timeUtc"`
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	bindAddress := os.Getenv("BIND_ADDRESS")
	if bindAddress == "" {
		bindAddress = "127.0.0.1"
	}

	root := context.Background()
	var pool *pgxpool.Pool
	databaseStatus := "not-configured"

	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL != "" {
		var err error
		pool, err = pgxpool.New(root, databaseURL)
		if err != nil {
			log.Fatalf("database pool failed: %v", err)
		}
		if err := pool.Ping(root); err != nil {
			log.Fatalf("database ping failed: %v", err)
		}
		defer pool.Close()
		databaseStatus = "connected"
	}

	api := httpapi.New(pool, []byte(os.Getenv("JWT_SECRET")))
	mux := http.NewServeMux()

	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		authStatus := "not-configured"
		if api.Ready() {
			authStatus = "ready"
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(healthResponse{
			Service:  "prfitness-api",
			Status:   "ok",
			Database: databaseStatus,
			AuthSync: authStatus,
			TimeUTC:  time.Now().UTC().Format(time.RFC3339),
		})
	})

	mux.HandleFunc("POST /v1/auth/register", api.Register)
	mux.HandleFunc("POST /v1/auth/login", api.Login)
	mux.HandleFunc("POST /v1/auth/refresh", api.Refresh)
	mux.HandleFunc("POST /v1/auth/logout", api.Logout)
	mux.Handle("POST /v1/sync", api.RequireAuth(http.HandlerFunc(api.Sync)))

	server := &http.Server{
		Addr:              bindAddress + ":" + port,
		Handler:           securityHeaders(mux),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       20 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       60 * time.Second,
		MaxHeaderBytes:    1 << 20,
	}

	signalContext, stop := signal.NotifyContext(
		context.Background(),
		os.Interrupt,
		syscall.SIGTERM,
	)
	defer stop()

	go func() {
		log.Printf("PrFitness API listening on :%s", port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal(err)
		}
	}()

	<-signalContext.Done()
	shutdownContext, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := server.Shutdown(shutdownContext); err != nil {
		log.Printf("server shutdown error: %v", err)
	}
}

func securityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("Referrer-Policy", "no-referrer")
		w.Header().Set("Cache-Control", "no-store")
		next.ServeHTTP(w, r)
	})
}
