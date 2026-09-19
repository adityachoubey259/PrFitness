package security

import (
	"crypto/rand"
	"crypto/subtle"
	"encoding/base64"
	"errors"
	"fmt"
	"strconv"
	"strings"

	"golang.org/x/crypto/argon2"
)

const (
	argonMemory      uint32 = 64 * 1024
	argonIterations  uint32 = 3
	argonParallelism uint8  = 4
	argonSaltLength         = 16
	argonKeyLength   uint32 = 32
)

func HashPassword(
	password string,
) (string, error) {
	if len(password) < 10 {
		return "", errors.New(
			"password must contain at least 10 characters",
		)
	}

	salt := make(
		[]byte,
		argonSaltLength,
	)

	if _, err := rand.Read(salt); err != nil {
		return "", err
	}

	hash := argon2.IDKey(
		[]byte(password),
		salt,
		argonIterations,
		argonMemory,
		argonParallelism,
		argonKeyLength,
	)

	return fmt.Sprintf(
		"$argon2id$v=%d$m=%d,t=%d,p=%d$%s$%s",
		argon2.Version,
		argonMemory,
		argonIterations,
		argonParallelism,
		base64.RawStdEncoding.EncodeToString(
			salt,
		),
		base64.RawStdEncoding.EncodeToString(
			hash,
		),
	), nil
}

func VerifyPassword(
	password string,
	encoded string,
) (bool, error) {
	parts := strings.Split(
		encoded,
		"$",
	)

	if len(parts) != 6 ||
		parts[1] != "argon2id" {
		return false, errors.New(
			"invalid argon2id hash",
		)
	}

	version, err :=
		strconv.Atoi(
			strings.TrimPrefix(
				parts[2],
				"v=",
			),
		)

	if err != nil ||
		version != argon2.Version {
		return false, errors.New(
			"unsupported argon2 version",
		)
	}

	params :=
		strings.Split(
			parts[3],
			",",
		)

	if len(params) != 3 {
		return false, errors.New(
			"invalid argon2 parameters",
		)
	}

	values :=
		map[string]uint64{}

	for _, param := range params {
		pair :=
			strings.SplitN(
				param,
				"=",
				2,
			)

		if len(pair) != 2 {
			return false, errors.New(
				"invalid argon2 parameter",
			)
		}

		value, parseErr :=
			strconv.ParseUint(
				pair[1],
				10,
				32,
			)

		if parseErr != nil {
			return false, parseErr
		}

		values[pair[0]] = value
	}

	memory := values["m"]
	iterations := values["t"]
	parallelism := values["p"]

	if memory == 0 ||
		iterations == 0 ||
		parallelism == 0 ||
		parallelism > 255 {
		return false, errors.New(
			"invalid argon2 parameters",
		)
	}

	salt, err :=
		base64.RawStdEncoding.DecodeString(
			parts[4],
		)

	if err != nil {
		return false, err
	}

	expected, err :=
		base64.RawStdEncoding.DecodeString(
			parts[5],
		)

	if err != nil ||
		len(expected) == 0 {
		return false, errors.New(
			"invalid argon2 hash payload",
		)
	}

	actual :=
		argon2.IDKey(
			[]byte(password),
			salt,
			uint32(iterations),
			uint32(memory),
			uint8(parallelism),
			uint32(len(expected)),
		)

	return subtle.ConstantTimeCompare(
		actual,
		expected,
	) == 1, nil
}
