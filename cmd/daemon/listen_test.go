package daemon

import (
	"testing"
)

func TestParseListen(t *testing.T) {
	t.Parallel()

	tests := map[string]struct {
		input    string
		expected ListenerConfig
		wantErr  bool
	}{
		"http://*:8080": {
			expected: ListenerConfig{
				Network: "tcp",
				Address: "*:8080",
			},
		},
		"http://127.0.0.1:8080": {
			expected: ListenerConfig{
				Network: "tcp",
				Address: "127.0.0.1:8080",
			},
		},
		"http://[::]:8000": {
			expected: ListenerConfig{
				Network: "tcp",
				Address: "[::]:8000",
			},
		},
		"http+unix://%2Ftmp%2Fmyapp.sock": {
			expected: ListenerConfig{
				Network: "unix",
				Address: "/tmp/myapp.sock",
			},
		},
		"https://*:4000": {
			expected: ListenerConfig{
				Network: "tcp",
				Address: "*:4000",
				IsHTTPS: true,
			},
		},
		"https://*:8000?cert=/path/to/server.crt&key=/path/to/server.key": {
			expected: ListenerConfig{
				Network:  "tcp",
				Address:  "*:8000",
				IsHTTPS:  true,
				CertFile: "/path/to/server.crt",
				KeyFile:  "/path/to/server.key",
			},
		},
		"HTTP+UNIX://%2Ftmp%2Fmyapp.sock": {
			expected: ListenerConfig{
				Network: "unix",
				Address: "/tmp/myapp.sock",
			},
		},
		"HTTPS://*:9000": {
			expected: ListenerConfig{
				Network: "tcp",
				Address: "*:9000",
				IsHTTPS: true,
			},
		},
		"invalid://foo:80": {
			wantErr: true,
		},
		"http://localhost": {
			wantErr: true,
		},
		"https://127.0.0.1": {
			wantErr: true,
		},
		"http://[::1]": {
			wantErr: true,
		},
	}

	for input, tt := range tests {
		t.Run(input, func(t *testing.T) {
			t.Parallel()

			got, err := parseListen(input)
			if (err != nil) != tt.wantErr {
				t.Fatalf("parseListen() error = %v, wantErr %v", err, tt.wantErr)
			}
			if tt.wantErr {
				return
			}
			if got != tt.expected {
				t.Errorf("parseListen() = %+v, want %+v", got, tt.expected)
			}
		})
	}
}
