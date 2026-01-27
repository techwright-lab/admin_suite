# CASA Tier 2 Control Narrative — Initial Passwords / Activation Codes

## Control statement (SAQ)

System-generated initial passwords or activation codes **should** be securely randomly generated, **should** be at least 6 characters long, **may** contain letters and numbers, and **expire after a short period of time**. These initial secrets **must not** be permitted to become the long-term password.

## How Gleania satisfies this control

Gleania does **not** issue system-generated “initial passwords” for user login. Instead, we use **time-limited, cryptographically signed tokens** (“initial secrets”) for:

1. **Password reset** (temporary, one-time use within an expiry window)
2. **Email verification / activation** (temporary verification token with expiry)

These tokens are used only to authorize a specific action (reset password / verify email) and are **not** used as long-term authentication credentials.

## Implementation details (what makes it secure)

### A) Password reset links (initial secret)

- **Secure random generation**: Password reset tokens are generated using Rails’ signed-token mechanism (cryptographic signing) and are not guessable.
- **Length**: Tokens are long (substantially more than 6 characters).
- **Expiration**: Password reset tokens expire after a short period (**15 minutes / 900 seconds**).
- **Not a long-term password**:
  - The reset token is only used to locate/authorize the password reset request.
  - The user must set a new password (via `password` + `password_confirmation`).
  - Existing sessions are invalidated after reset so old credentials/sessions cannot persist.
- **Abuse prevention**: Password reset requests are rate-limited.

### B) Email verification links (activation code equivalent)

- **Secure random generation**: Email verification tokens are generated using Rails’ signed-token mechanism and are not guessable.
- **Length**: Tokens are long (substantially more than 6 characters).
- **Expiration**: Verification tokens expire after a short period (**24 hours**).
- **Not a long-term password**: Email verification tokens only mark `email_verified_at` and do not grant ongoing authentication.
- **Abuse prevention**: Verification resend requests are rate-limited.

## Evidence to provide (recommended packet)

### 1) Code evidence (primary)

- **Password reset flow + expiry enforcement**
  - `app/controllers/passwords_controller.rb` (`User.find_by_password_reset_token!` and expired-token handling)
  - `app/views/passwords_mailer/reset.text.erb` (explicit expiry messaging and use of `password_reset_token_expires_in`)

- **Email verification flow + expiry enforcement**
  - `app/models/user.rb` (`generates_token_for :email_verification, expires_in: 24.hours`)
  - `app/controllers/email_verifications_controller.rb` (`find_by_token_for(:email_verification, ...)` with invalid/expired handling)
  - `app/mailers/user_mailer.rb` (generation of verification URL using `generate_token_for`)
  - `app/views/user_mailer/verify_email.text.erb` (explicit expiry messaging)

### 2) Operational evidence (supporting)

- **Token expiry value & length (password reset)**: capture command output (screenshot) from:

```bash
bin/rails runner 'u=User.first; puts u.password_reset_token_expires_in; puts u.password_reset_token.length'
```

Expected:
- expiry window is **900 seconds**
- token length is **≫ 6 characters**

### 3) UI/flow evidence (supporting)

- Screenshot of the password reset email showing the reset link and expiry statement.
- Screenshot of the “invalid or expired” reset token error state.
- Screenshot of the verification email and “invalid or expired” verification token message.

## Notes / assumptions

- Tokens are treated as short-lived “initial secrets” rather than passwords.
- End-user authentication uses `has_secure_password` and user-chosen passwords; tokens do not become long-term credentials.

