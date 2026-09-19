package security

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

type AccessClaims struct {
	UserID string `json:"uid"`

	jwt.RegisteredClaims
}

func IssueAccessToken(
	userID string,
	secret []byte,
	now time.Time,
	lifetime time.Duration,
) (string, error) {
	if userID == "" {
		return "", errors.New(
			"user id is required",
		)
	}

	if len(secret) < 32 {
		return "", errors.New(
			"jwt secret must be at least 32 bytes",
		)
	}

	if lifetime <= 0 {
		return "", errors.New(
			"token lifetime must be positive",
		)
	}

	claims := AccessClaims{
		UserID: userID,
		RegisteredClaims: jwt.RegisteredClaims{
			Issuer:    "prfitness-api",
			Subject:   userID,
			IssuedAt:  jwt.NewNumericDate(now),
			NotBefore: jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(
				now.Add(lifetime),
			),
		},
	}

	token :=
		jwt.NewWithClaims(
			jwt.SigningMethodHS256,
			claims,
		)

	return token.SignedString(secret)
}

func ParseAccessToken(
	rawToken string,
	secret []byte,
) (*AccessClaims, error) {
	if len(secret) < 32 {
		return nil, errors.New(
			"jwt secret must be at least 32 bytes",
		)
	}

	claims := &AccessClaims{}

	token, err :=
		jwt.ParseWithClaims(
			rawToken,
			claims,
			func(
				token *jwt.Token,
			) (any, error) {
				if token.Method.Alg() !=
					jwt.SigningMethodHS256.Alg() {
					return nil, errors.New(
						"unexpected signing algorithm",
					)
				}

				return secret, nil
			},
			jwt.WithValidMethods(
				[]string{
					jwt.SigningMethodHS256.Alg(),
				},
			),
			jwt.WithIssuer(
				"prfitness-api",
			),
		)

	if err != nil {
		return nil, err
	}

	if !token.Valid ||
		claims.UserID == "" {
		return nil, errors.New(
			"invalid access token",
		)
	}

	return claims, nil
}
