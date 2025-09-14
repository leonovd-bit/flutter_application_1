@echo off
echo Copying updated kitchen.html to build folder...
copy "web\kitchen.html" "build\web\kitchen.html" /Y
echo Kitchen.html updated successfully!
echo Deploying to Firebase...
firebase deploy --only hosting
echo Deployment complete!
