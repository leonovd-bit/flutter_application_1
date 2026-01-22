curl -X POST https://us-east4-freshpunk-48db1.cloudfunctions.net/sendRestaurantOrderNotification \
  -H "Content-Type: application/json" \
  -d '{
    "orderId": "test_order_'$(date +%s%N)'",
    "restaurantId": null
  }'
