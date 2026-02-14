package daemon

import (
	"testing"
)

func TestParseListen(t *testing.T) {
	t.Parallel()

	tests := []struct {
		input    string
		expected ListenerConfig
		wantErr  bool
	}{
		{
			input: "http://*:8080",
			expected: ListenerConfig{
				Network: "tcp",
				Address: "*:8080",
			},
		},
		{
			input: "http://127.0.0.1:8080",
			expected: ListenerConfig{
				Network: "tcp",
				Address: "127.0.0.1:8080",
			},
		},
		{
			input: "http://[::]:8000",
			expected: ListenerConfig{
				Network: "tcp",
				Address: "[::]:8000",
			},
		},
		{
			input: "http+unix://%2Ftmp%2Fmyapp.sock",
			expected: ListenerConfig{
				Network: "unix",
				Address: "/tmp/myapp.sock",
			},
		},
		{
			input: "https://*:4000",
			expected: ListenerConfig{
				Network: "tcp",
				Address: "*:4000",
				IsHTTPS: true,
			},
		},
		{
			input: "https://*:8000?cert=/path/to/server.crt&key=/path/to/server.key",
			expected: ListenerConfig{
				Network:  "tcp",
				Address:  "*:8000",
				IsHTTPS:  true,
				CertFile: "/path/to/server.crt",
				KeyFile:  "/path/to/server.key",
			},
		},
		{
			input: "HTTP+UNIX://%2Ftmp%2Fmyapp.sock",
			expected: ListenerConfig{
				Network: "unix",
				Address: "/tmp/myapp.sock",
			},
		},
		{
			input: "HTTPS://*:9000",
			expected: ListenerConfig{
				Network: "tcp",
				Address: "*:9000",
				IsHTTPS: true,
			},
		},
		{
			input:   "invalid://foo:80",
			wantErr: true,
		},
		{
			input:   "http://localhost",
			wantErr: true,
		},
		{
			input:   "https://127.0.0.1",
			wantErr: true,
		},
		{
			input:   "http://[::1]",
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			t.Parallel()

			got, err := parseListen(tt.input)
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
