# Cloudflare Turnstile Setup

This guide explains how to set up Cloudflare Turnstile for bot protection on the sign-up and contact forms.

## What is Turnstile?

Cloudflare Turnstile is a privacy-first alternative to CAPTCHA that protects forms from bot submissions without requiring users to solve puzzles.

## Step 1: Create a Turnstile Site

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Navigate to **Turnstile** in the sidebar
3. Click **Add Site**
4. Fill in the form:
   - **Site name**: `Gleania` (or your preferred name)
   - **Domain**: Your domain (e.g., `gleania.com`, `*.gleania.com`)
   - **Widget mode**: Choose **Managed** (recommended) or **Non-interactive**
5. Click **Create**
6. **Copy both keys**:
   - **Site Key** (public, used in frontend)
   - **Secret Key** (private, used in backend)

## Step 2: Add Credentials to Rails

### Option A: Using Rails Credentials (Recommended)

1. Open your terminal in the project directory
2. Run: `EDITOR="code --wait" rails credentials:edit` (or use your preferred editor)
3. Add the following under a new `cloudflare:` key:

```yaml
cloudflare:
  turnstile_site_key: your_site_key_here
  turnstile_secret_key: your_secret_key_here
```

4. Save and close the file

### Option B: Using Environment Variables

If you prefer environment variables (e.g., with Docker/Kamal):

```bash
CLOUDFLARE_TURNSTILE_SITE_KEY=your_site_key_here
CLOUDFLARE_TURNSTILE_SECRET_KEY=your_secret_key_here
```

## Step 3: Verify Setup

1. Start your Rails server: `rails server`
2. Navigate to the sign-up page (`/registrations/new`)
3. You should see a Turnstile widget above the submit button
4. Navigate to the contact page (`/contact`)
5. You should see a Turnstile widget above the submit button

## How It Works

- **Frontend**: The Turnstile widget is automatically loaded on sign-up and contact pages
- **Backend**: When forms are submitted, the token is verified server-side
- **Graceful Degradation**: If Turnstile is not configured, forms will still work (no protection)

## Testing

### Development

For local development, you can use Cloudflare's test keys:

- **Site Key**: `1x00000000000000000000AA`
- **Secret Key**: `1x0000000000000000000000000000000AA`

These keys will always pass verification in development.

### Production

Use your actual keys from the Cloudflare dashboard.

## Troubleshooting

### Widget Not Showing

- Check that `turnstile_site_key` is set in credentials or environment
- Check browser console for JavaScript errors
- Verify the Turnstile script is loaded (check Network tab)

### Verification Failing

- Check that `turnstile_secret_key` is set correctly
- Verify the secret key matches the site key in Cloudflare dashboard
- Check Rails logs for verification errors
- Ensure your domain is added to the Turnstile site configuration

### Forms Still Work Without Turnstile

This is intentional - the system gracefully degrades if Turnstile is not configured. For production, always configure Turnstile for bot protection.

## Additional Resources

- [Cloudflare Turnstile Documentation](https://developers.cloudflare.com/turnstile/)
- [Turnstile API Reference](https://developers.cloudflare.com/turnstile/get-started/server-side-validation/)

