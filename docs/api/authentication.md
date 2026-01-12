# Authentication Endpoints

## Login

**Endpoint:** `POST /admin_users/login`

Authenticate with email and password to get access and refresh tokens.

### Request

```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

### Response (Success - 200)

```json
{
  "auth_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### Response (Error - 401)

```json
{
  "error": "Invalid email or password"
}
```

### Status Codes
- `200 OK` - Login successful
- `401 Unauthorized` - Invalid credentials
- `500 Internal Server Error` - Server error

### Example

```bash
curl -X POST http://localhost:3000/api/v1/admin_users/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "password123"
  }'
```

### Notes
- Tokens are JWT-based
- Access token is used for API requests
- Refresh token is used to get new access tokens
- Device fingerprinting is used for token rotation security

---

## Refresh Token

**Endpoint:** `POST /admin_users/refresh`

Get a new access token using a refresh token.

### Request

```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### Response (Success - 200)

```json
{
  "auth_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### Response (Error - 401)

```json
{
  "error": "Invalid refresh token"
}
```

### Status Codes
- `200 OK` - Token refreshed successfully
- `400 Bad Request` - Refresh token missing
- `401 Unauthorized` - Invalid or expired refresh token
- `500 Internal Server Error` - Server error

### Example

```bash
curl -X POST http://localhost:3000/api/v1/admin_users/refresh \
  -H "Content-Type: application/json" \
  -d '{
    "refresh_token": "YOUR_REFRESH_TOKEN"
  }'
```

### Notes
- Refresh tokens are rotated on each refresh
- Device fingerprinting validates token rotation
- Legacy clients are supported with `X-Legacy-Client: true` header

---

## Logout

**Endpoint:** `POST /admin_users/logout`

Logout from the current device.

**Authentication:** Required (Bearer token)

### Request

```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### Response (Success - 200)

```json
{
  "message": "Successfully logged out"
}
```

### Response (Error - 400)

```json
{
  "error": "Refresh token is required"
}
```

### Status Codes
- `200 OK` - Logout successful
- `400 Bad Request` - Refresh token missing
- `401 Unauthorized` - Invalid token
- `500 Internal Server Error` - Server error

### Example

```bash
curl -X POST http://localhost:3000/api/v1/admin_users/logout \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "refresh_token": "YOUR_REFRESH_TOKEN"
  }'
```

### Notes
- Invalidates the refresh token
- Only logs out from current device
- Access token becomes invalid

---

## Logout All

**Endpoint:** `POST /admin_users/logout_all`

Logout from all devices.

**Authentication:** Required (Bearer token)

### Request

No request body required.

### Response (Success - 200)

```json
{
  "message": "Successfully logged out from all devices",
  "sessions_terminated": 3
}
```

### Status Codes
- `200 OK` - Logout successful
- `401 Unauthorized` - Invalid token
- `500 Internal Server Error` - Server error

### Example

```bash
curl -X POST http://localhost:3000/api/v1/admin_users/logout_all \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Notes
- Invalidates all refresh tokens for the user
- Logs out from all devices
- All access tokens become invalid

