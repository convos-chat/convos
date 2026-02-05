// Package auth configures argon2 to be compatitle with Perl Convos.
package auth

import (
	"crypto/rand"
	"crypto/subtle"
	"encoding/base64"
	"errors"
	"fmt"
	"math"
	"strings"

	"golang.org/x/crypto/argon2"
	"golang.org/x/crypto/bcrypt"
)

var (
	ErrInvalidHash         = errors.New("the encoded hash is not in the correct format")
	ErrIncompatibleVersion = errors.New("incompatible version of argon2")
	ErrUnsupportedFormat   = errors.New("unsupported hash format")
	ErrUnsupportedVariant  = errors.New("unsupported argon2 variant")
	ErrTooLongToken        = errors.New("the encoded hash is too long to be processed")
)

type params struct {
	memory      uint32
	iterations  uint32
	parallelism uint8
	saltLength  uint32
	keyLength   uint32
}

// Perl Convos uses Argon2 with specific settings:
// encoder    => {module => 'Argon2', memory_cost => '64M'},
// It seems to use default iterations (3) and parallelism (1) from Crypt::Passphrase::Argon2
var defaultParams = &params{
	memory:      64 * 1024,
	iterations:  3,
	parallelism: 1,
	saltLength:  16,
	keyLength:   32,
}

// GenerateHash generates a hash for a password. It defaults to Argon2id for new hashes.
func GenerateHash(password string) (string, error) {
	salt := make([]byte, defaultParams.saltLength)
	if _, err := rand.Read(salt); err != nil {
		return "", err
	}

	hash := argon2.IDKey([]byte(password), salt, defaultParams.iterations, defaultParams.memory, defaultParams.parallelism, defaultParams.keyLength)

	b64Salt := base64.RawStdEncoding.EncodeToString(salt)
	b64Hash := base64.RawStdEncoding.EncodeToString(hash)

	// Format: $argon2id$v=19$m=65536,t=3,p=1$salt$hash
	encoded := fmt.Sprintf("$argon2id$v=%d$m=%d,t=%d,p=%d$%s$%s", argon2.Version, defaultParams.memory, defaultParams.iterations, defaultParams.parallelism, b64Salt, b64Hash)

	return encoded, nil
}

// ComparePassword compares a password with a hash (Argon2 or Bcrypt).
func ComparePassword(password, encodedHash string) (bool, error) {
	if strings.HasPrefix(encodedHash, "$argon2") {
		return compareArgon2(password, encodedHash)
	}
	if strings.HasPrefix(encodedHash, "$2a$") || strings.HasPrefix(encodedHash, "$2b$") {
		err := bcrypt.CompareHashAndPassword([]byte(encodedHash), []byte(password))
		return err == nil, nil
	}
	return false, ErrUnsupportedFormat
}

func compareArgon2(password, encodedHash string) (bool, error) {
	p, salt, hash, err := decodeHash(encodedHash)
	if err != nil {
		return false, err
	}

	var otherHash []byte
	switch {
	case strings.Contains(encodedHash, "$argon2id$"):
		otherHash = argon2.IDKey([]byte(password), salt, p.iterations, p.memory, p.parallelism, p.keyLength)
	case strings.Contains(encodedHash, "$argon2i$"):
		otherHash = argon2.Key([]byte(password), salt, p.iterations, p.memory, p.parallelism, p.keyLength)
	default:
		return false, ErrUnsupportedVariant
	}

	if subtle.ConstantTimeCompare(hash, otherHash) == 1 {
		return true, nil
	}
	return false, nil
}

func decodeHash(encodedHash string) (*params, []byte, []byte, error) {
	vals := strings.Split(encodedHash, "$")
	if len(vals) != 6 {
		return nil, nil, nil, ErrInvalidHash
	}

	var version int
	if _, err := fmt.Sscanf(vals[2], "v=%d", &version); err != nil {
		return nil, nil, nil, err
	}
	if version != argon2.Version {
		return nil, nil, nil, ErrIncompatibleVersion
	}

	p := &params{}
	if _, err := fmt.Sscanf(vals[3], "m=%d,t=%d,p=%d", &p.memory, &p.iterations, &p.parallelism); err != nil {
		return nil, nil, nil, err
	}

	salt, err := base64.RawStdEncoding.DecodeString(vals[4])
	if err != nil {
		return nil, nil, nil, err
	}
	saltlen := len(salt)
	if saltlen < math.MaxInt32 {
		p.saltLength = uint32(saltlen)
	} else {
		return nil, nil, nil, ErrTooLongToken
	}

	hash, err := base64.RawStdEncoding.DecodeString(vals[5])
	if err != nil {
		return nil, nil, nil, err
	}
	hashlen := len(hash)
	if hashlen < math.MaxInt32 {
		p.keyLength = uint32(hashlen)
	} else {
		return nil, nil, nil, ErrTooLongToken
	}

	return p, salt, hash, nil
}
