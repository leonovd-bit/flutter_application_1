const admin = require('firebase-admin');

// Initialize Firebase Admin SDK with default credentials
admin.initializeApp();

const db = admin.firestore();

async function sendTestEmail() {
  try {
    console.log('🧪 Creating test restaurant...');

    // Create test restaurant
    const restaurantId = 'test_restaurant_' + Date.now();
    await db.collection('restaurant_partners').doc(restaurantId).set({
      id: restaurantId,
      name: 'Test Restaurant',
      contactEmail: 'dleonovets@gmail.com',
      contactPhone: '+1 (555) 123-4567',
      address: '123 Test St, New York, NY 10001',
      businessType: 'restaurant',
      description: 'Test restaurant for email verification',
      status: 'active',
      notificationMethods: {
        email: true,
        sms: false,
        dashboard: true,
      },
      stats: {
        totalOrders: 0,
        completedOrders: 0,
        totalRevenue: 0,
        averageOrderValue: 0,
        lastOrderDate: null,
      },
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    });

    console.log('✅ Test restaurant created:', restaurantId);
    console.log('📧 Email:', 'dleonovets@gmail.com');

    console.log('\n🍽️  Creating test order with meals...');

    // Create test order
    const orderId = 'test_order_' + Date.now();
    await db.collection('orders').doc(orderId).set({
      id: orderId,
      userId: 'test_user_123',
      userEmail: 'testcustomer@example.com',
      customerName: 'John Test',
      customerPhone: '+1 (555) 987-6543',
      deliveryAddress: '456 Customer Ave, New York, NY 10002',
      deliveryDate: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
      deliveryTime: '12:00 PM',
      status: 'confirmed',
      mealPlanType: 'pro',
      dayName: 'Monday',
      mealType: 'lunch',
      specialInstructions: 'No onions please!',
      totalAmount: 45.99,
      meals: [
        {
          id: 'meal_1',
          name: 'Grilled Salmon with Vegetables',
          description: 'Fresh Atlantic salmon with seasonal vegetables',
          quantity: 1,
          price: 18.99,
          calories: 450,
          protein: 35,
          restaurantId: restaurantId,
          squareItemId: 'SQ_ITEM_001',
          squareVariationId: 'SQ_VAR_001',
        },
        {
          id: 'meal_2',
          name: 'Quinoa Buddha Bowl',
          description: 'Organic quinoa with roasted chickpeas and tahini dressing',
          quantity: 1,
          price: 14.99,
          calories: 380,
          protein: 12,
          restaurantId: restaurantId,
          squareItemId: 'SQ_ITEM_002',
          squareVariationId: 'SQ_VAR_002',
        },
        {
          id: 'meal_3',
          name: 'Chocolate Avocado Mousse',
          description: 'Rich and creamy healthy dessert',
          quantity: 1,
          price: 12.01,
          calories: 220,
          protein: 5,
          restaurantId: restaurantId,
          squareItemId: 'SQ_ITEM_003',
          squareVariationId: 'SQ_VAR_003',
        },
      ],
      orderDate: admin.firestore.FieldValue.serverTimestamp(),
      source: 'test_email_verification',
      userConfirmed: true,
      userConfirmedAt: new Date().toISOString(),
      dispatchReadyAt: new Date().toISOString(),
      dispatchWindowMinutes: 60,
    });

    console.log('✅ Test order created:', orderId);
    console.log('\n📬 Email should arrive at: dleonovets@gmail.com');
    console.log('⏱️  Check your inbox in the next few seconds...');
    console.log('\n📋 Order Details:');
    console.log('   - Restaurant: Test Restaurant');
    console.log('   - Customer: John Test');
    console.log('   - Meals: 3 items');
    console.log('   - Total: $45.99');

    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

sendTestEmail();
