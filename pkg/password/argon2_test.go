package password

import (
	"testing"
)

func TestArgon2(t *testing.T) {
	t.Parallel()
	password := "correct_password"
	hash, err := GenerateHash(password)
	if err != nil {
		t.Fatalf("GenerateHash failed: %v", err)
	}

	if hash == "" {
		t.Fatal("Hash is empty")
	}

	valid, err := ComparePassword(password, hash)
	if err != nil {
		t.Fatalf("ComparePassword failed: %v", err)
	}
	if !valid {
		t.Error("ComparePassword returned false for correct password")
	}

	valid, err = ComparePassword("wrong_password", hash)
	if err != nil {
		t.Fatalf("ComparePassword failed: %v", err)
	}
	if valid {
		t.Error("ComparePassword returned true for wrong password")
	}
}

func TestPerlCompatibility(t *testing.T) {
	t.Parallel()
	// Perl hash for "password123" with default Convos settings
	perlHash := "$argon2id$v=19$m=65536,t=3,p=1$2ckIfq5GA6ZdEUaPDc/yBw$jtGfy4CmIsEGuVLTVR1aFLoObknDCL1t8KiinasZhQQ"
	password := "password123"

	valid, err := ComparePassword(password, perlHash)
	if err != nil {
		t.Fatalf("ComparePassword failed for Perl hash: %v", err)
	}
	if !valid {
		t.Error("ComparePassword returned false for Perl hash")
	}
}

func TestBcryptCompatibility(t *testing.T) {
	t.Parallel()
	// Bcrypt hash for "password123"
	bcryptHash := "$2a$10$ggWPdVC4IW7wUZ3lFm.XYulqGppSw1DodJyYFjTIPLlZazDRHfO26"
	password := "password123"

	valid, err := ComparePassword(password, bcryptHash)
	if err != nil {
		t.Fatalf("ComparePassword failed for Bcrypt hash: %v", err)
	}
	if !valid {
		t.Error("ComparePassword returned false for Bcrypt hash")
	}
}
