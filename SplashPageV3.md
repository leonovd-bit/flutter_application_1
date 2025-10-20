# SplashPageV3

## Purpose
Initial loading/boot screen shown while the app initializes and authenticates users.

## Navigation Role
- **Entry Point**: First page shown when app launches
- **Used by**: AuthWrapper as default loading screen
- **Duration**: Minimum 5 seconds for UX consistency
- **Next**: Transitions to LoginPageV3 or HomePageV3 based on auth state

## Key Features
- Shows FreshPunk branding/logo
- Loading indicator
- Authentication state checking
- Admin seed button (temporary)

## File Location
`lib/app_v3/pages/splash_page_v3.dart`

## Active in Navigation
✅ **PRIMARY** - Core entry point for all users