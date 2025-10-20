# DoorDash API Integration Setup Guide

## Overview
This guide will help you integrate DoorDash Drive API for third-party delivery services in your FreshPunk meal delivery app.

## Prerequisites
1. DoorDash Drive Account (Business account required)
2. API credentials from DoorDash Developer Portal
3. JWT signing keys for authentication

## Setup Instructions

### 1. Get DoorDash API Credentials
1. Sign up for DoorDash Drive at https://get.doordash.com/drive/
2. Contact DoorDash business development for API access
3. Obtain your API credentials:
   - Developer ID
   - Key ID
   - Signing Key (private key for JWT)

### 2. Configure API Credentials
Add your DoorDash credentials to your app configuration:

#### Option A: Environment Variables (Recommended for Production)
```bash
# Add to your environment or .env file
DOORDASH_DEVELOPER_ID=your_developer_id
DOORDASH_KEY_ID=your_key_id
DOORDASH_SIGNING_KEY=your_private_key
```

#### Option B: Firebase Remote Config
Store credentials securely in Firebase Remote Config for dynamic updates.

#### Option C: Local Configuration (Development Only)
Create a config file (do not commit to version control):
```dart
// lib/config/doordash_config.dart
class DoorDashConfig {
  static const String developerId = 'your_developer_id';
  static const String keyId = 'your_key_id';
  static const String signingKey = '''your_private_key''';
}
```

### 3. Update DoorDash Service
Update the `DoorDashService` class to use your credentials:

```dart
// In lib/app_v3/services/doordash_service.dart
class DoorDashService {
  // Update these with your actual credentials
  static const String _developerId = 'YOUR_DEVELOPER_ID';
  static const String _keyId = 'YOUR_KEY_ID';
  static const String _signingKey = '''
-----BEGIN PRIVATE KEY-----
YOUR_PRIVATE_KEY_HERE
-----END PRIVATE KEY-----
''';
}
```

### 4. Add Required Dependencies
Ensure your `pubspec.yaml` includes the JWT dependency:

```yaml
dependencies:
  dart_jsonwebtoken: ^2.12.1
  # Other existing dependencies...
```

Run `flutter pub get` to install dependencies.

### 5. Integration Points

#### Create Orders with DoorDash Delivery
```dart
// Example usage in your order flow
final orderResult = await EnhancedOrderService.instance.createOrderWithDelivery(
  userId: currentUser.uid,
  meals: selectedMeals,
  deliveryAddress: customerAddress,
  customerName: 'John Doe',
  customerPhone: '+1234567890',
  requestedDeliveryTime: DateTime.now().add(Duration(hours: 1)),
  useDoorDashDelivery: true, // Enable DoorDash
);
```

#### Track Delivery Status
```dart
// Get real-time delivery tracking
final trackingInfo = await EnhancedOrderService.instance.getDeliveryTracking(orderId);
if (trackingInfo != null) {
  print('Driver: ${trackingInfo.driverName}');
  print('Status: ${trackingInfo.status}');
  print('ETA: ${trackingInfo.estimatedDeliveryTime}');
}
```

#### Cancel Orders
```dart
// Cancel DoorDash delivery
final success = await EnhancedOrderService.instance.cancelOrder(
  orderId, 
  'Customer requested cancellation'
);
```

## Integration with Existing Pages

### 1. Delivery Schedule Page Integration
Update `delivery_schedule_page_v4.dart` to include DoorDash option:

```dart
// Add DoorDash toggle in delivery options
SwitchListTile(
  title: Text('Use DoorDash Delivery'),
  subtitle: Text('Professional delivery service'),
  value: _useDoorDashDelivery,
  onChanged: (value) {
    setState(() {
      _useDoorDashDelivery = value;
    });
  },
),
```

### 2. Order Tracking Integration
Update order tracking pages to show DoorDash-specific information:

```dart
// In order status widgets
if (order.deliveryMethod == 'doordash') {
  // Show DoorDash tracking UI
  DoorDashTrackingWidget(
    trackingUrl: order.trackingUrl,
    driverInfo: order.driverInfo,
  );
}
```

### 3. Admin Dashboard Integration
Add DoorDash metrics to kitchen dashboard:

```dart
// Show DoorDash delivery statistics
DoorDashMetricsCard(
  activeDeliveries: dashboardData.activeDoorDashDeliveries,
  totalDeliveries: dashboardData.totalDoorDashDeliveries,
  averageDeliveryTime: dashboardData.avgDoorDashDeliveryTime,
);
```

## Testing

### 1. Sandbox Testing
DoorDash provides a sandbox environment for testing:
```dart
// In DoorDashService, set sandbox mode
static const bool _isProduction = false; // Set to true for production
static String get _baseUrl => _isProduction 
    ? 'https://openapi.doordash.com' 
    : 'https://openapi.doordash.com'; // Use sandbox URL when available
```

### 2. Test Orders
Create test orders with DoorDash:
```dart
// Test delivery creation
final testOrder = await EnhancedOrderService.instance.createOrderWithDelivery(
  userId: 'test_user',
  meals: [testMeal],
  deliveryAddress: testAddress,
  customerName: 'Test Customer',
  customerPhone: '+15555551234',
  useDoorDashDelivery: true,
);
```

## Monitoring and Analytics

### 1. Order Success Rates
Track DoorDash vs internal delivery success rates:
```dart
// Add analytics tracking
Analytics.track('doordash_delivery_created', {
  'order_id': orderId,
  'delivery_fee': quote.deliveryFeeInDollars,
  'estimated_duration': quote.estimatedDurationMinutes,
});
```

### 2. Performance Metrics
Monitor delivery performance:
- Average delivery time
- Customer satisfaction
- Delivery fee impact
- Driver ratings

## Error Handling

### 1. Fallback to Internal Delivery
```dart
// Automatic fallback if DoorDash is unavailable
if (!doorDashAvailable) {
  // Fall back to internal delivery system
  await createInternalDelivery(orderData);
}
```

### 2. Common Error Scenarios
- API rate limiting
- Invalid delivery address
- Service area restrictions
- Driver unavailability

## Security Considerations

### 1. API Key Security
- Never commit API keys to version control
- Use environment variables or secure config
- Rotate keys regularly
- Monitor API usage

### 2. JWT Token Security
- Generate tokens server-side when possible
- Use short token expiration times
- Validate tokens before API calls

## Support and Documentation

### DoorDash Resources
- Developer Portal: https://developer.doordash.com/
- API Documentation: https://developer.doordash.com/docs
- Support: Contact your DoorDash business representative

### Implementation Support
- Review the `DoorDashService` class for all available methods
- Check `EnhancedOrderService` for integration examples
- Monitor Firebase logs for delivery tracking events

## Production Deployment Checklist

- [ ] DoorDash API credentials configured
- [ ] JWT signing implemented and tested
- [ ] Sandbox testing completed
- [ ] Production API access approved
- [ ] Error handling implemented
- [ ] Monitoring and analytics set up
- [ ] Customer support process defined
- [ ] Driver issue escalation process
- [ ] Delivery fee calculation verified
- [ ] Integration testing with real orders

## Next Steps

1. Contact DoorDash to get production API access
2. Implement JWT token generation
3. Test with sandbox environment
4. Add DoorDash delivery option to your order flow
5. Monitor delivery performance and customer feedback

This integration will provide your customers with professional delivery service while maintaining control over your order management and customer experience.