# Google OAuth Setup Guide

This guide will help you set up Google OAuth for user sign-in/sign-up and Gmail integration in Gleania.

## Prerequisites

- A Google account
- Access to [Google Cloud Console](https://console.cloud.google.com/)

## Step 1: Create a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click the project dropdown at the top
3. Click **"New Project"**
4. Enter project name: `Gleania` (or your preferred name)
5. Click **"Create"**
6. Wait for the project to be created and select it

## Step 2: Enable Required APIs

1. In the Google Cloud Console, go to **"APIs & Services" > "Library"**
2. Search for and enable the following APIs:
   - **Gmail API** (for email syncing)
   - (Optional) **Google Calendar API** (only if/when you add calendar features)

## Step 3: Configure OAuth Consent Screen

1. Go to **"APIs & Services" > "OAuth consent screen"**
2. Choose **"External"** user type (unless you have a Google Workspace account)
3. Click **"Create"**

### OAuth Consent Screen Details

Fill in the following information:

**App Information:**
- **App name**: `Gleania`
- **User support email**: Your email address
- **App logo**: (Optional) Upload your Gleania logo
- **Application home page**: `https://yourdomain.com` (or `http://localhost:3000` for development)
- **Application privacy policy link**: `https://yourdomain.com/privacy` (create this page)
- **Application terms of service link**: `https://yourdomain.com/terms` (create this page)
- **Authorized domains**: Add your domain (e.g., `yourdomain.com`)

**Developer contact information:**
- **Email addresses**: Your email address

**Scopes:**
Click **"Add or Remove Scopes"** and add:
- `email` - See your primary Google Account email address
- `profile` - See your personal info, including any personal info you've made publicly available
- `https://www.googleapis.com/auth/gmail.readonly` - View your Gmail messages

**Test users** (for development):
- Add your own Google account email address
- Add any test accounts you want to use during development

4. Click **"Save and Continue"** through all steps
5. Click **"Back to Dashboard"**

## Step 4: Create OAuth 2.0 Credentials

1. Go to **"APIs & Services" > "Credentials"**
2. Click **"+ CREATE CREDENTIALS"** at the top
3. Select **"OAuth client ID"**
4. If prompted, configure the OAuth consent screen first (follow Step 3 above)

### Application Type

Select **"Web application"**

### OAuth Client Details

**Name**: `Gleania Web Client` (or your preferred name)

**Authorized JavaScript origins**:
- Development: `http://localhost:3000`
- Production: `https://yourdomain.com`

**Authorized redirect URIs**:
- Development: `http://localhost:3000/auth/google_oauth2/callback`
- Production: `https://yourdomain.com/auth/google_oauth2/callback`

**Important**: You must add both development and production URLs if you're using both environments.

5. Click **"Create"**
6. **Copy the Client ID and Client Secret** - you'll need these in the next step

## Step 5: Add Credentials to Rails

### For Development

1. Open your terminal in the project directory
2. Run: `EDITOR="code --wait" rails credentials:edit` (or use your preferred editor)
3. Add the following under the `google:` key:

```yaml
google:
  client_id: your_client_id_here
  client_secret: your_client_secret_here
```

4. Save and close the file

### For Production

1. Run: `EDITOR="code --wait" rails credentials:edit --environment production`
2. Add the same credentials structure
3. Save and close the file

**Alternative**: If using environment variables (e.g., with Kamal/Docker):

```bash
GOOGLE_CLIENT_ID=your_client_id_here
GOOGLE_CLIENT_SECRET=your_client_secret_here
```

Then update `config/initializers/omniauth.rb` to use:
```ruby
ENV['GOOGLE_CLIENT_ID']
ENV['GOOGLE_CLIENT_SECRET']
```

## Step 6: Verify Setup

1. Start your Rails server: `rails server`
2. Navigate to `http://localhost:3000/registrations/new`
3. Click **"Sign up with Google"**
4. You should be redirected to Google's OAuth consent screen
5. After authorizing, you should be redirected back and signed in

## Troubleshooting

### "redirect_uri_mismatch" Error

- Make sure the redirect URI in Google Cloud Console exactly matches: `http://localhost:3000/auth/google_oauth2/callback`
- Check for trailing slashes or protocol mismatches (http vs https)

### "access_denied" Error

- Make sure you've added your email as a test user in the OAuth consent screen
- Verify all required scopes are added in the consent screen configuration

### Credentials Not Found

- Verify credentials are saved correctly: `rails credentials:show`
- Check that the keys are under `google:` (not `Google:` or `GOOGLE:`)
- Restart your Rails server after updating credentials

### OAuth Consent Screen Not Showing

- Make sure the OAuth consent screen is published (for production) or you're using a test user (for development)
- Check that all required fields in the consent screen are filled out

## Production Checklist

Before going to production:

- [ ] OAuth consent screen is published (not in "Testing" mode)
- [ ] Production redirect URI is added to Google Cloud Console
- [ ] Production credentials are added to Rails encrypted credentials
- [ ] Privacy policy and Terms of Service pages are created and linked
- [ ] App logo is uploaded to OAuth consent screen
- [ ] All required scopes are approved

## Security Notes

- Never commit credentials to version control
- Use Rails encrypted credentials for storing secrets
- Rotate credentials if they're ever exposed
- Use different OAuth clients for development and production
- Regularly review authorized applications in Google Account settings

## Additional Resources

- [Google OAuth 2.0 Documentation](https://developers.google.com/identity/protocols/oauth2)
- [OmniAuth Google OAuth2 Strategy](https://github.com/zquestz/omniauth-google-oauth2)
- [Rails Credentials Guide](https://guides.rubyonrails.org/security.html#custom-credentials)

