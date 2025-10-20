#!/bin/bash

# Restaurant Portal Deployment Script
# This script copies the restaurant portal files to the build/web directory and deploys to Firebase Hosting

echo "🍴 FreshPunk Restaurant Portal Deployment"
echo "==========================================="

# Check if build/web directory exists
if [ ! -d "build/web" ]; then
    echo "❌ build/web directory not found. Please run 'flutter build web' first."
    exit 1
fi

# Copy restaurant portal files
echo "📂 Copying restaurant portal files..."
cp restaurant_portal/index.html build/web/restaurant.html
cp restaurant_portal/styles.css build/web/restaurant-styles.css
cp restaurant_portal/script.js build/web/restaurant-script.js

# Update file references in restaurant.html
echo "🔧 Updating file references..."
sed -i 's/href="styles.css"/href="restaurant-styles.css"/g' build/web/restaurant.html
sed -i 's/src="script.js"/src="restaurant-script.js"/g' build/web/restaurant.html

echo "✅ Restaurant portal files prepared"

# Deploy to Firebase Hosting
echo "🚀 Deploying to Firebase Hosting..."
firebase deploy --only hosting

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 Deployment successful!"
    echo ""
    echo "📱 Your app: https://freshpunk-48db1.web.app"
    echo "🏪 Restaurant portal: https://freshpunk-48db1.web.app/restaurant"
    echo ""
    echo "Share the restaurant portal URL with your restaurant partners!"
else
    echo "❌ Deployment failed"
    exit 1
fi