# EmailVerificationPageV3

## Purpose
Email verification step requiring users to verify their email address before proceeding.

## Navigation Role
- **From**: SignUpPageV3 (email registration)
- **Next**: OnboardingChoicePageV3 (verified) or stays on page (unverified)
- **Required Parameter**: email address

## Key Features
- Email verification status checking
- Resend verification email option
- Auto-polling for verification status
- Countdown timer for resend cooldown
- Firebase Auth email verification integration

## File Location
`lib/app_v3/pages/email_verification_page_v3.dart`

## Active in Navigation
✅ **PRIMARY** - Required step in email signup flow