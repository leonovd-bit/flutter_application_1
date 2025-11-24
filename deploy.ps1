# Build Flutter web with environment variables
$flutterArgs = @("build", "web", "--release", "--dart-define=FCM_VAPID_KEY=BJ1mdYgV4Ahkf6kosSMnYCuMHhSw0zqrbr6tVk3nEh9zhXqlH9EJ3MdgBnTV1BJ6DyVyKOqZSGsbzBOS-A3d1o8")

if (![string]::IsNullOrWhiteSpace($env:GOOGLE_GEOCODE_KEY)) {
	$flutterArgs += "--dart-define=GOOGLE_GEOCODE_KEY=$($env:GOOGLE_GEOCODE_KEY)"
	Write-Host "🔨 Building Flutter web with VAPID + Google Geocode dart-defines..."
} else {
	Write-Warning "GOOGLE_GEOCODE_KEY env var not set. Address validation will be skipped in this build."
	Write-Host "🔨 Building Flutter web with VAPID key only..."
}

flutter @flutterArgs

# Deploy to Firebase live channel
Write-Host "🚀 Deploying to Firebase live channel..."
firebase deploy --only hosting --project freshpunk-48db1

Write-Host "✅ Done! Site is live."