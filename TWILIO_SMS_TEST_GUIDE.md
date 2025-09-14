# Twilio SMS Test Guide

## ✅ Deployment Status
- Firebase Functions deployed successfully
- Twilio secrets configured (TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN)
- SMS functions available: `sendSMS`, `sendOrderConfirmationSMS`, `sendOrderStatusSMS`

## 📱 Next Steps to Complete Setup

### 1. Update Twilio Phone Number
Once you get your Twilio phone number, update these files:

**File:** `functions/src/index.ts`
- Line ~1760: Replace `"+1234567890"` with your actual Twilio number
- Line ~1921: Replace `"+1234567890"` with your actual Twilio number

### 2. Redeploy Functions
After updating the phone number:
```bash
cd functions
firebase deploy --only functions
```

## 🧪 Testing SMS Functionality

### Test 1: Basic SMS Function
Use Firebase Console > Functions > sendSMS:
```json
{
  "to": "+1YOUR_PHONE_NUMBER",
  "message": "Test SMS from FreshPunk!"
}
```

### Test 2: Order Confirmation SMS
Use Firebase Console > Functions > sendOrderConfirmationSMS:
```json
{
  "customerPhone": "+1YOUR_PHONE_NUMBER",
  "orderId": "TEST123",
  "estimatedDelivery": "45 minutes"
}
```

### Test 3: Order Status Update SMS
Use Firebase Console > Functions > sendOrderStatusSMS:
```json
{
  "customerPhone": "+1YOUR_PHONE_NUMBER",
  "orderId": "TEST123",
  "status": "preparing",
  "estimatedDelivery": "30 minutes"
}
```

## 📊 Expected SMS Messages

### Order Confirmation:
```
🍽️ FreshPunk Order Confirmed!

Order #TEST123 received and will be delivered in approximately 45 minutes.

Track your order in the app. Questions? Reply to this message.

Thank you for choosing FreshPunk! 
```

### Status Updates:
```
📱 Order #TEST123 Update

Status: Preparing your delicious meal
Estimated delivery: 30 minutes

Track live updates in the FreshPunk app.
```

## 🔧 Integration with Flutter App

The SMS service is automatically integrated with your order system:
- Order confirmations sent when orders are placed
- Status updates sent when kitchen updates order status
- Driver arrival notifications sent automatically

## 💰 Cost Tracking
- SMS cost: $0.0075 per message
- Monitor usage in Twilio Console
- Set up billing alerts for cost management

## 🚨 Troubleshooting

### If SMS fails:
1. Check Twilio Console for error logs
2. Verify phone number format (+1XXXXXXXXXX)
3. Check Firebase Functions logs
4. Ensure Twilio account is verified and has balance

### Common Issues:
- **"Unverified number"**: Add recipient to Twilio verified numbers (trial accounts)
- **"Insufficient balance"**: Add funds to Twilio account
- **"Invalid phone number"**: Use E.164 format (+1XXXXXXXXXX)

## 📞 Support
- Twilio Documentation: https://www.twilio.com/docs/sms
- Firebase Functions Logs: Firebase Console > Functions > Logs
- Test in development before production deployment
