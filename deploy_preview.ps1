Write-Host "Building Flutter web with VAPID key..."
flutter build web --release --dart-define=FCM_VAPID_KEY=BJ1mdYgV4Ahkf6kosSMnYCuMHhSw0zqrbr6tVk3nEh9zhXqlH9EJ3MdgBnTV1BJ6DyVyKOqZSGsbzBOS-A3d1o8

Write-Host "Deploying to Firebase preview channel..."
firebase hosting:channel:deploy preview --project freshpunk-48db1

Write-Host "Done! Check the preview URL above."