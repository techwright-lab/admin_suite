# TechWright SSO Setup Guide

This guide will help you set up TechWright SSO for authenticating developers to access the internal admin portal at `/internal/developer`.

## Overview

The developer portal uses TechWright SSO for authentication, which is separate from regular user authentication. This allows company employees to access admin features without needing a standard user account.

### How It Works

1. Developers visit `/internal/developer` and are redirected to the login page
2. They click "Sign in with TechWright" which initiates the OAuth flow
3. After authenticating with TechWright, they're redirected back and a `Developer` record is created/updated
4. Developers can then access all admin portal features

## Prerequisites

- A TechWright organization account
- OAuth client credentials from TechWright
- Access to Rails credentials

## Step 1: Obtain TechWright OAuth Credentials

1. Log in to your TechWright admin dashboard at `https://techwright.io`
2. Navigate to **Settings > OAuth Applications**
3. Click **"New Application"**
4. Fill in the application details:
   - **Name**: `Gleania Developer Portal`
   - **Redirect URIs**: 
     - Development: `http://localhost:3000/auth/techwright/callback`
     - Production: `https://yourdomain.com/auth/techwright/callback`
   - **Scopes**: `openid email profile`
5. Click **"Create Application"**
6. Copy the **Client ID** and **Client Secret**

## Step 2: Add Credentials to Rails

### For Development

1. Open your terminal in the project directory
2. Run:
   ```bash
   EDITOR="code --wait" rails credentials:edit
   ```
   (Replace `code --wait` with your preferred editor command)

3. Add the following:
   ```yaml
   techwright:
     client_id: your_client_id_here
     client_secret: your_client_secret_here
   ```

4. Save and close the file

### For Production

1. Run:
   ```bash
   EDITOR="code --wait" rails credentials:edit --environment production
   ```

2. Add the same credentials structure

3. Save and close the file

### Using Environment Variables (Alternative)

If you prefer environment variables (e.g., with Docker/Kamal), update `config/initializers/omniauth.rb`:

```ruby
provider :techwright,
  ENV.fetch("TECHWRIGHT_CLIENT_ID"),
  ENV.fetch("TECHWRIGHT_CLIENT_SECRET"),
  scope: "openid email profile"
```

Then set the environment variables:
```bash
TECHWRIGHT_CLIENT_ID=your_client_id_here
TECHWRIGHT_CLIENT_SECRET=your_client_secret_here
```

## Step 3: Run Database Migration

Run the migration to create the `developers` table:

```bash
rails db:migrate
```

This creates the `developers` table with the following fields:
- `techwright_uid` - Unique TechWright user identifier
- `email` - Developer's email from TechWright
- `name` - Developer's name from TechWright
- `access_token` / `refresh_token` - Encrypted OAuth tokens
- `enabled` - Boolean to enable/disable access
- `last_login_at`, `last_login_ip`, `login_count` - Audit fields

## Step 4: Verify Setup

1. Start your Rails server:
   ```bash
   rails server
   ```

2. Navigate to `http://localhost:3000/internal/developer`

3. You should be redirected to the login page

4. Click **"Sign in with TechWright"**

5. After authenticating, you should be redirected to the developer portal dashboard

## Managing Developers

### Viewing Developers

Developers are created automatically on first TechWright login. You can view them via Rails console:

```ruby
Developer.all
Developer.recently_active # Developers who logged in within 30 days
```

### Disabling a Developer

To revoke a developer's access:

```ruby
developer = Developer.find_by(email: "developer@example.com")
developer.update!(enabled: false)
```

The developer will see "Your developer access has been disabled" when they try to log in.

### Re-enabling a Developer

```ruby
developer = Developer.find_by(email: "developer@example.com")
developer.update!(enabled: true)
```

## URL Reference

| URL | Description |
|-----|-------------|
| `/internal/developer/login` | Developer login page |
| `/internal/developer/logout` | Sign out |
| `/internal/developer` | Developer portal dashboard |
| `/auth/techwright/callback` | OAuth callback (handled automatically) |

## Troubleshooting

### "Authentication failed" Error

- Verify the Client ID and Client Secret are correct in Rails credentials
- Check that the redirect URI in TechWright matches exactly: `http://localhost:3000/auth/techwright/callback`
- Ensure the TechWright OAuth application has the correct scopes enabled

### "Your developer access has been disabled"

- The developer's `enabled` flag has been set to `false`
- Re-enable via Rails console (see "Managing Developers" above)

### OAuth Redirect Mismatch

- Ensure the redirect URI matches exactly (including protocol and trailing slashes)
- For production, use `https://` not `http://`

### Credentials Not Found

- Verify credentials are saved: `rails credentials:show`
- Keys should be under `techwright:` (lowercase)
- Restart Rails server after updating credentials

## Security Notes

- OAuth tokens are encrypted at rest using Rails' ActiveRecord Encryption
- Never commit credentials to version control
- Use different OAuth clients for development and production
- Regularly review the Developer records for unauthorized access
- Consider implementing domain restriction (e.g., only `@yourcompany.com` emails)

## Architecture Notes

### Files Created/Modified

| File | Purpose |
|------|---------|
| `lib/omniauth/strategies/techwright.rb` | Custom OmniAuth strategy |
| `app/models/developer.rb` | Developer model |
| `app/controllers/internal/developer/sessions_controller.rb` | Login/logout controller |
| `app/views/internal/developer/sessions/new.html.erb` | Login page |
| `config/initializers/omniauth.rb` | OAuth provider configuration |
| `config/routes/developer.rb` | Authentication routes |

### Separation from User Authentication

The developer portal authentication is completely separate from regular user authentication:

- **Users** authenticate via email/password or Google OAuth
- **Developers** authenticate via TechWright SSO
- A person can be both a User and a Developer independently
- Disabling a Developer does not affect their User account (if any)

## Additional Resources

- [TechWright OAuth Documentation](https://techwright.io/docs/oauth)
- [OmniAuth OAuth2 Strategy](https://github.com/omniauth/omniauth-oauth2)
- [Rails Credentials Guide](https://guides.rubyonrails.org/security.html#custom-credentials)
