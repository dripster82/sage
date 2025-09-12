# Token Management with Device Binding and Rotation

## Overview

This document outlines our secure token management strategy for API authentication, combining refresh token rotation with device binding. The approach prioritizes security while minimizing database storage requirements.

## Key Features

- **Short-lived Access Tokens**: 5-minute lifespan to minimize risk if compromised
- **Refresh Token Rotation**: One-time use tokens with automatic rotation
- **Device Binding**: Tokens are bound to the originating device
- **Token Families**: Logical grouping of related token rotations for a device/session
- **Minimal Storage**: Only essential reference data stored in the database
- **Comprehensive Logout**: Support for single-session and all-session logout

## System Architecture

### Token Types

1. **Access Token**: 
   - 5-minute lifespan
   - Contains user identity and permissions
   - Used for API authorization
   - JWT format, signed with server secret

2. **Refresh Token**: 
   - 7-day lifespan
   - One-time use with rotation
   - Device-bound
   - JWT format containing metadata for validation

### Database Storage

Each token family record contains:
```json
{
  "familyId": "unique-uuid-for-family",
  "userId": "user-id",
  "latestTokenId": "most-recent-valid-token-id", 
  "version": 3,
  "deviceFingerprint": "hashed-device-identifier"
}
```

## Token Flows

### Initial Authentication

1. User provides credentials and is authenticated
2. System generates device fingerprint from client information
3. System creates new token family with initial version (1)
4. System issues access token and refresh token
5. Both tokens are returned to client

### Token Refresh Process

1. Client sends refresh token with device fingerprint
2. Server validates token signature and expiration
3. Server ensures device fingerprint matches stored value
4. Server verifies token is the latest version for its family
5. Server issues new access token and rotated refresh token
6. Old refresh token is invalidated
7. Token family record is updated with new token ID and incremented version
8. New tokens are returned to client

### Session Termination (Logout)

When a user logs out of a session:
1. Client sends refresh token to logout endpoint
2. Server identifies token family from the token
3. Server deletes the token family record entirely
4. Server returns confirmation of logout
5. Client discards tokens

## Security Features

### Token Theft Detection

If a refresh token is stolen and used:

1. **Attacker uses token first**:
   - Server rotates the token and updates the token family
   - When legitimate user attempts to use their now-invalid token, system detects token version mismatch
   - System deletes the token family record
   - User is forced to re-authenticate

2. **Legitimate user uses token first**:
   - Token rotates normally
   - When attacker attempts to use the old token, system detects token version mismatch
   - System deletes the token family record
   - Attacker is denied access
   - Legitimate user is forced to re-authenticate on next refresh attempt

### Device Fingerprinting

Device fingerprint is generated from multiple client characteristics:
- User agent
- Screen dimensions
- Color depth
- Language settings
- Time zone offset

The combined fingerprint helps detect if a token is being used on a different device.

## Implementation Guidelines

### Client-Side Implementation

1. **Token Storage**:
   - Store tokens securely (memory-only for SPAs, secure storage for mobile)
   - Never persist in localStorage without encryption
   - Clear on logout/session end

2. **Fingerprint Generation**:
   ```javascript
   function generateDeviceFingerprint() {
     const components = [
       navigator.userAgent,
       navigator.language,
       screen.colorDepth,
       screen.width + 'x' + screen.height,
       new Date().getTimezoneOffset()
     ];
     return hashComponents(components.join('|'));
   }
   ```

3. **Token Refresh Logic**:
   ```javascript
   async function refreshTokens() {
     const currentRefreshToken = getStoredRefreshToken();
     const deviceFingerprint = generateDeviceFingerprint();
     
     const response = await fetch('/api/auth/refresh', {
       method: 'POST',
       headers: { 'Content-Type': 'application/json' },
       body: JSON.stringify({
         refreshToken: currentRefreshToken,
         deviceFingerprint: deviceFingerprint
       })
     });
     
     if (!response.ok) {
       // Handle error (force re-authentication)
       return redirectToLogin();
     }
     
     const tokens = await response.json();
     storeTokens(tokens);
     return tokens;
   }
   ```

### Server-Side Implementation

1. **Token Issuance**:
   ```javascript
   function issueTokenWithRotation(user, deviceFingerprint) {
     const tokenId = crypto.randomUUID();
     const familyId = crypto.randomUUID();
     
     const accessToken = generateAccessToken(user.id);
     const refreshToken = jwt.sign(
       {
         userId: user.id,
         tokenId: tokenId,
         familyId: familyId,
         deviceFingerprint: deviceFingerprint,
         version: 1
       },
       REFRESH_TOKEN_SECRET,
       { expiresIn: '7d' }
     );
     
     // Store minimal reference data
     storeTokenFamily({
       familyId,
       userId: user.id,
       latestTokenId: tokenId,
       version: 1,
       deviceFingerprint
     });
     
     return { accessToken, refreshToken };
   }
   ```

2. **Token Validation and Rotation**:
   ```javascript
   async function rotateRefreshToken(oldToken, deviceFingerprint) {
     const payload = jwt.verify(oldToken, REFRESH_TOKEN_SECRET);
     
     // Get token family
     const tokenFamily = await getTokenFamily(payload.familyId);
     
     if (!tokenFamily) {
       throw new Error('Invalid token family');
     }
     
     // Verify device binding
     if (tokenFamily.deviceFingerprint !== deviceFingerprint) {
       await deleteTokenFamily(payload.familyId);
       throw new Error('Device mismatch detected');
     }
     
     // Verify token version
     if (tokenFamily.version !== payload.version || 
         tokenFamily.latestTokenId !== payload.tokenId) {
       await deleteTokenFamily(payload.familyId);
       throw new Error('Token reuse detected');
     }
     
     // Generate new tokens with incremented version
     const newTokenId = crypto.randomUUID();
     const newVersion = payload.version + 1;
     
     await updateTokenFamily({
       familyId: payload.familyId,
       latestTokenId: newTokenId,
       version: newVersion
     });
     
     const accessToken = generateAccessToken(payload.userId);
     const refreshToken = jwt.sign(
       {
         userId: payload.userId,
         tokenId: newTokenId,
         familyId: payload.familyId,
         deviceFingerprint: deviceFingerprint,
         version: newVersion
       },
       REFRESH_TOKEN_SECRET,
       { expiresIn: '7d' }
     );
     
     return { accessToken, refreshToken };
   }
   ```

3. **Logout Handler**:
   ```javascript
   async function logoutSession(refreshToken) {
     try {
       const payload = jwt.verify(refreshToken, REFRESH_TOKEN_SECRET);
       
       // Delete token family entirely
       await deleteTokenFamily(payload.familyId);
       
       return { success: true, message: "Successfully logged out" };
     } catch (error) {
       // Handle invalid tokens gracefully
       return { success: false, message: "Invalid session" };
     }
   }
   ```

4. **Database Operations**:
   ```javascript
   // Store new token family
   async function storeTokenFamily(tokenFamily) {
     // Insert record into database
     return db.tokenFamilies.insertOne(tokenFamily);
   }
   
   // Get token family
   async function getTokenFamily(familyId) {
     return db.tokenFamilies.findOne({ familyId });
   }
   
   // Update token family during rotation
   async function updateTokenFamily({ familyId, latestTokenId, version }) {
     return db.tokenFamilies.updateOne(
       { familyId },
       { 
         $set: { 
           latestTokenId, 
           version 
         } 
       }
     );
   }
   
   // Delete token family on logout
   async function deleteTokenFamily(familyId) {
     return db.tokenFamilies.deleteOne({ familyId });
   }
   ```

## Endpoints

1. **Login** - `POST /api/auth/login`
   - Accepts user credentials
   - Returns access token and refresh token

2. **Refresh** - `POST /api/auth/refresh`
   - Accepts refresh token and device fingerprint
   - Returns new access token and refresh token

3. **Logout** - `POST /api/auth/logout` 
   - Accepts refresh token
   - Deletes the token family
   - Returns success status

4. **Logout All** - `POST /api/auth/logout-all`
   - Requires authenticated request
   - Deletes all token families for the user
   - Returns count of sessions terminated

## Error Handling

1. **Token Validation Errors**:
   - Invalid signature: 401 Unauthorized
   - Expired token: 401 Unauthorized with clear error message
   - Token reuse detected: 401 Unauthorized with appropriate message
   - Device mismatch: 401 Unauthorized with appropriate message

2. **Database Operation Errors**:
   - Return appropriate 500-series errors
   - Do not expose internal details to client

## Security Considerations

1. **JWT Signing Key Management**:
   - Use separate signing keys for access tokens and refresh tokens
   - Rotate signing keys periodically
   - Store keys securely using environment variables or a secrets manager

2. **Token Payload Security**:
   - Include only necessary claims in tokens
   - Avoid storing sensitive user data in token payloads

3. **Database Security**:
   - Ensure token family table has appropriate indexes
   - Implement rate limiting on token operations
   - Monitor for unusual patterns of token usage

## Monitoring and Maintenance

1. **Key Performance Indicators**:
   - Token refresh success rate
   - Token rotation delays
   - Token validation errors by type

2. **Security Alerts**:
   - Multiple token reuse detections
   - Device fingerprint mismatch patterns
   - Geographic anomalies in token usage

3. **Regular Cleanup**:
   - Implement job to delete expired token families
   - Monitor database size and growth rate