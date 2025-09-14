@echo off
echo Building Flutter web app...
flutter build web --release
echo Deploying to Firebase...
firebase deploy --only hosting
echo Done!
pause
