# Authentication

Convos supports four authentication providers, selected via `CONVOS_AUTH_PROVIDER`:

| Provider | Value    | Description                                          |
| -------- | -------- | ---------------------------------------------------- |
| Local    | `local`  | Built-in password auth with Argon2id (default)       |
| Header   | `header` | Trusts an HTTP header set by a reverse proxy         |
| LDAP     | `ldap`   | Binds against an LDAP directory                      |
| OIDC     | `oidc`   | OAuth 2.0 Authorization Code flow via OpenID Connect |

For all providers the first user to authenticate is automatically granted the `admin` role.

---

## Local (default)

No extra configuration needed. Users register and log in with email and password.

---

## Header

Delegates authentication to a reverse proxy (nginx, Apache, Traefik, etc.) that sets a header containing the authenticated user's email.

### Configuration

| Variable               | Required | Default                | Description                                                    |
| ---------------------- | -------- | ---------------------- | -------------------------------------------------------------- |
| `CONVOS_AUTH_PROVIDER` | Yes      | `local`                | Set to `header`                                                |
| `CONVOS_AUTH_HEADER`   | No       | `X-Authenticated-User` | Header name containing the user's email                        |
| `CONVOS_ADMIN`         | No       |                        | If set, only this email may register as the first (admin) user |

### Example

```bash
export CONVOS_AUTH_PROVIDER=header
export CONVOS_AUTH_HEADER=X-Forwarded-User
```

Users are auto-created on first request. Make sure the header cannot be spoofed by clients (strip it in your proxy before setting it).

---

## LDAP

Authenticates by performing an LDAP bind with the user's credentials. Optionally falls back to local password auth on LDAP failure.

### Configuration

| Variable                    | Required | Default                       | Description                                      |
| --------------------------- | -------- | ----------------------------- | ------------------------------------------------ |
| `CONVOS_AUTH_PROVIDER`      | Yes      | `local`                       | Set to `ldap`                                    |
| `CONVOS_AUTH_LDAP_URL`      | No       | `ldap://localhost:389`        | LDAP server URL                                  |
| `CONVOS_AUTH_LDAP_DN`       | No       | `uid=%uid,dc=%domain,dc=%tld` | DN pattern for bind (see substitutions below)    |
| `CONVOS_AUTH_LDAP_TIMEOUT`  | No       | `10`                          | Connection timeout in seconds                    |
| `CONVOS_AUTH_LDAP_FALLBACK` | No       | `true`                        | Fall back to local password auth on LDAP failure |

#### DN pattern substitutions

Given the email `alice@example.com`:

| Placeholder | Value               |
| ----------- | ------------------- |
| `%uid`      | `alice`             |
| `%email`    | `alice@example.com` |
| `%domain`   | `example`           |
| `%tld`      | `com`               |

### LDAP Example

```bash
export CONVOS_AUTH_PROVIDER=ldap
export CONVOS_AUTH_LDAP_URL=ldaps://ldap.example.com:636
export CONVOS_AUTH_LDAP_DN="uid=%uid,ou=people,dc=%domain,dc=%tld"
export CONVOS_AUTH_LDAP_FALLBACK=false
```

Users are auto-created locally after a successful LDAP bind.

---

## OIDC

Uses the OAuth 2.0 Authorization Code flow with an OpenID Connect provider (Google, Azure AD, Keycloak, etc.).

### Configuration

| Variable                         | Required | Default                | Description                       |
| -------------------------------- | -------- | ---------------------- | --------------------------------- |
| `CONVOS_AUTH_PROVIDER`           | Yes      | `local`                | Set to `oidc`                     |
| `CONVOS_AUTH_OIDC_ISSUER`        | Yes      |                        | OIDC issuer URL                   |
| `CONVOS_AUTH_OIDC_CLIENT_ID`     | Yes      |                        | OAuth2 client ID                  |
| `CONVOS_AUTH_OIDC_CLIENT_SECRET` | Yes      |                        | OAuth2 client secret              |
| `CONVOS_AUTH_OIDC_REDIRECT_URL`  | Yes      |                        | Redirect URL after authentication |
| `CONVOS_AUTH_OIDC_SCOPES`        | No       | `openid,profile,email` | Comma-separated OAuth2 scopes     |

### OIDC Example

```bash
export CONVOS_AUTH_PROVIDER=oidc
export CONVOS_AUTH_OIDC_ISSUER=https://accounts.google.com
export CONVOS_AUTH_OIDC_CLIENT_ID=123456789.apps.googleusercontent.com
export CONVOS_AUTH_OIDC_CLIENT_SECRET=your-secret-here
export CONVOS_AUTH_OIDC_REDIRECT_URL=https://convos.example.com/auth/oidc/callback
```

### Login flow

1. User navigates to `/auth/oidc/login`
2. Redirected to the OIDC provider
3. Provider redirects back to `/auth/oidc/callback` with an authorization code
4. Convos exchanges the code for tokens and validates the ID token
5. User account is auto-created if it doesn't exist
6. User is logged in and redirected to the chat interface

The `openid` scope is always required and will be added automatically if missing. If the provider doesn't supply an `email` claim, Convos falls back to `preferred_username`.

### Troubleshooting

- **"Failed to exchange authorization code"**: Verify client secret and that the redirect URI matches exactly (protocol, domain, port, path).
- **"Email claim missing from ID token"**: Ensure the `email` scope is included.
- **"redirect_uri_mismatch"**: `CONVOS_AUTH_OIDC_REDIRECT_URL` must exactly match what is configured in the provider.
