package security

import (
	"testing"
	"time"
)

func TestAccessTokenRoundTrip(
	t *testing.T,
) {
	t.Parallel()

	secret :=
		[]byte(
			"0123456789012345678901234567890123456789",
		)

	now :=
		time.Now().UTC()

	token, err :=
		IssueAccessToken(
			"user-123",
			secret,
			now,
			15*time.Minute,
		)

	if err != nil {
		t.Fatal(err)
	}

	claims, err :=
		ParseAccessToken(
			token,
			secret,
		)

	if err != nil {
		t.Fatal(err)
	}

	if claims.UserID !=
		"user-123" {
		t.Fatalf(
			"unexpected user id: %s",
			claims.UserID,
		)
	}
}
