@echo off
echo Setting up Stripe secret key for Firebase Functions...
echo.
echo Please enter your Stripe secret key (starts with sk_test_ or sk_live_):
set /p STRIPE_KEY="Secret Key: "

echo.
echo Setting Firebase Functions configuration...
firebase functions:config:set stripe.secret_key="%STRIPE_KEY%"

echo.
echo Deploying Firebase Functions...
firebase deploy --only functions

echo.
echo Setup complete! Your Stripe integration is now ready.
echo.
pause
