# Google OAuth Verification Checklist (Gleania)

This checklist is designed to make Google OAuth consent screen configuration and verification straightforward for Gleania.

## 1) URLs you must provide (production)

- Application home page: `https://<your-domain>/`
- Privacy Policy: `https://<your-domain>/privacy`
- Terms of Service: `https://<your-domain>/terms`
- Cookie Policy (optional but recommended): `https://<your-domain>/cookies`

## 2) Authorized domains

- Add your production domain to **Authorized domains** (e.g. `gleania.com`).
- Ensure your app is actually reachable on that domain (no auth wall for the legal pages).

## 3) OAuth redirect URIs

Add these under your OAuth client credentials:

- `https://<your-domain>/auth/google_oauth2/callback`

## 4) Scopes requested by the app

From the app configuration (`config/initializers/omniauth.rb`), Gleania requests:

- `email`
- `profile`
- `https://www.googleapis.com/auth/gmail.readonly`

Tip: Keep the scope list minimal. Only request additional scopes when the corresponding feature is live.

## 5) What the app does with Gmail data (use in verification answers)

Gleania uses Gmail read-only access to help users manage job search communications. Specifically:

- Fetches interview-related emails using Gmail search queries.
- Stores limited derived fields used in the product UI:
  - sender (name/email), subject, date, labels
  - snippet, and a short body preview (truncated)
- Uses the stored fields to:
  - show a review queue for unmatched emails
  - match emails to interview applications
  - detect recruiter outreach and create opportunities

Users can disconnect their Google account in Settings to stop future syncing.

## 6) Google API Services User Data Policy (Limited Use)

When completing verification and your Privacy Policy, ensure you can truthfully state:

- You only use Google user data to provide or improve user-facing features.
- You do not sell Google user data.
- You do not use Google user data for advertising or profiling for ads.
- You restrict access to the minimum needed (least privilege) and protect data in transit and at rest.

## 7) Common verification artifacts Google may ask for

- A short screen recording showing:
  - Sign in / connect Google account
  - Consent screen showing requested scopes
  - Where Gmail-derived data appears in the app (inbox/review queue, matching workflow)
  - How to disconnect the account
- Clear explanation of:
  - why you need Gmail read-only access
  - what you store vs. what you do not store
  - how users control the integration


