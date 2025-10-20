# LoginPageV3

## Purpose
Authentication page for returning users to sign in with email/password, Google, or Apple.

## Navigation Role
- **Entry Point**: Shown when no authenticated user exists
- **Used by**: AuthWrapper for unauthenticated users
- **Next**: HomePageV3 (successful login) or WelcomePageV3 (new users)

## Key Features
- Email/password login
- Google Sign-In integration
- Apple Sign-In integration
- "Sign Up" navigation to SignUpPageV3
- Offline demo accounts support
- Remember me functionality

## File Location
`lib/app_v3/pages/login_page_v3.dart`

## Active in Navigation
✅ **PRIMARY** - Core authentication entry point