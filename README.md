# FreshPunk (Flutter + Firebase)

Modern meal subscription experience powered by Flutter Web, Firebase Auth, Firestore, Cloud Functions, and Stripe billing.

## Requirements

- Flutter 3.24+ with web support enabled
- Firebase CLI (for deploys and Firestore rules)
- Node 20 (for Cloud Functions)
- A Firebase project with Auth, Firestore, Functions, and Hosting configured
- API keys:
	- `FCM_VAPID_KEY` – already baked into build scripts for push messaging
	- `GOOGLE_GEOCODE_KEY` – **required** for address validation via `SimpleGoogleMapsService`

## Local development

1. Install dependencies:
	 ```powershell
	 flutter pub get
	 ```
2. Run the app (Chrome example) with required dart-defines:
	 ```powershell
	 $env:GOOGLE_GEOCODE_KEY="<server-side-geocode-key>"
	 flutter run -d chrome --dart-define=FCM_VAPID_KEY=$env:FCM_VAPID_KEY --dart-define=GOOGLE_GEOCODE_KEY=$env:GOOGLE_GEOCODE_KEY
	 ```
	 - If you do not set `GOOGLE_GEOCODE_KEY`, address validation will be skipped and `AddressPage` will warn in the console.
	 - Use a **server-side** Geocoding key (not browser-restricted). Restrict it by IP if you proxy calls via Cloud Functions.

## Building & deploying

- The `deploy.ps1` script wraps the necessary `flutter build web --release` call and deploys Hosting.
- Set the geocode key before running the script:
	```powershell
	$env:GOOGLE_GEOCODE_KEY="<server-side-geocode-key>"
	./deploy.ps1
	```
- The script will warn if the key is missing and proceed with validation disabled.

## Firestore rules & permissions

- Rules live in `firestore.rules`. Deploy updates with:
	```powershell
	firebase deploy --only firestore:rules
	```
- Subscription documents live at `/subscriptions/{uid}`. Users must be authenticated, but email verification is *not* required for Manage Subscription flows to function. Admin accounts (custom claim `admin: true`) retain full access, while Stripe webhooks bypass rules via the Admin SDK.

## Troubleshooting

- **Address validation skipped** – ensure `GOOGLE_GEOCODE_KEY` is present in dart-defines for the build/run you are testing.
- **Firestore permission-denied on subscriptions** – confirm the signed-in user matches the subscription document owner or use an admin account. After updating rules, redeploy them and refresh the client to pick up the new security model.
- **Stripe callable errors** – verify you are invoking via `CloudFunctionsHelper` so Auth tokens are forwarded.

Feel free to expand this README as new workflows are added (phone verification, Stripe onboarding, etc.).
