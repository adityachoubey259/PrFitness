package security

import "testing"

func TestPasswordHashAndVerify(
	t *testing.T,
) {
	t.Parallel()

	hash, err :=
		HashPassword(
			"correct horse battery staple",
		)

	if err != nil {
		t.Fatal(err)
	}

	ok, err :=
		VerifyPassword(
			"correct horse battery staple",
			hash,
		)

	if err != nil {
		t.Fatal(err)
	}

	if !ok {
		t.Fatal(
			"expected password to verify",
		)
	}

	wrong, err :=
		VerifyPassword(
			"incorrect password",
			hash,
		)

	if err != nil {
		t.Fatal(err)
	}

	if wrong {
		t.Fatal(
			"wrong password verified unexpectedly",
		)
	}
}
