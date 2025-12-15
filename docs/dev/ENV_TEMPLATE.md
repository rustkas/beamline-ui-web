# Environment Variables Template

Copy this file to `.env` and fill in your values.

## Phoenix Configuration

```bash
# Secret key base (generate with: mix phx.gen.secret)
SECRET_KEY_BASE=your-64-char-secret-here

# Guardian JWT secret (generate with: mix guardian.gen.secret)
GUARDIAN_SECRET_KEY=your-secret-key-here

# Phoenix server
PHX_HOST=localhost
PHX_PORT=4000
```

## OIDC Authentication (Optional)

For development, the app uses default values. Configure these for production:

```bash
# OIDC Provider Configuration
OIDC_CLIENT_ID=your-client-id
OIDC_CLIENT_SECRET=your-client-secret
OIDC_DISCOVERY_URL=https://your-provider.com/.well-known/openid-configuration
OIDC_REDIRECT_URI=http://localhost:4000/auth/oidc/callback
```

## Development Defaults

The following defaults are used in development (see `config/config.exs`):

- **OIDC_CLIENT_ID**: `dev-client-id`
- **OIDC_CLIENT_SECRET**: `dev-client-secret`
- **OIDC_DISCOVERY_URL**: `https://accounts.google.com/.well-known/openid-configuration`
- **OIDC_REDIRECT_URI**: `http://localhost:4000/auth/oidc/callback`

⚠️ **Note**: OIDC authentication will fail in development without real credentials. This is expected behavior. The login page will display, but clicking "Sign in with OIDC" requires valid OIDC provider credentials.

## Setting up OIDC (Optional)

### Google OAuth 2.0

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Enable "Google+ API"
4. Create OAuth 2.0 credentials:
   - Application type: Web application
   - Authorized redirect URIs: `http://localhost:4000/auth/oidc/callback`
5. Copy Client ID and Client Secret to your `.env` file

### Other OIDC Providers

- **Keycloak**: `https://your-keycloak.com/realms/your-realm/.well-known/openid-configuration`
- **Auth0**: `https://your-tenant.auth0.com/.well-known/openid-configuration`
- **Okta**: `https://your-domain.okta.com/.well-known/openid-configuration`

## Security Notes

- ⚠️ Never commit `.env` files to version control
- ✅ Use strong secrets in production (64+ characters)
- ✅ Rotate secrets regularly
- ✅ Use environment-specific secrets (dev/staging/prod)
