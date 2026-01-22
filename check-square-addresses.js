#!/usr/bin/env node
/**
 * Quick script to check what's in a Square order
 */

const fetch = require('node-fetch');

async function testSquareOrder() {
  const accessToken = process.env.SQUARE_ACCESS_TOKEN || '';
  const locationId = 'LGBRPB437S6KJ';
  
  if (!accessToken) {
    console.error('Missing SQUARE_ACCESS_TOKEN');
    process.exit(1);
  }

  try {
    const now = new Date();
    const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000);

    // Search for recent orders
    const searchResp = await fetch('https://connect.squareup.com/v2/orders/search', {
      method: 'POST',
      headers: {
        'Square-Version': '2023-10-18',
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        location_ids: [locationId],
        query: {
          filter: {
            date_time_filter: {
              created_at: {
                start_at: yesterday.toISOString(),
              },
            },
          },
          sort: {
            sort_field: 'CREATED_AT',
            sort_order: 'DESC',
          },
        },
        limit: 3,
      }),
    });

    const data = await searchResp.json();
    const orders = data.orders || [];

    console.log('\n=== Recent Orders ===\n');
    
    for (const order of orders) {
      const delivery = order.fulfillments?.find(f => f.type === 'DELIVERY');
      if (delivery) {
        const addr = delivery.delivery_details?.delivery_address;
        console.log(`Order: ${order.id.substring(0, 8)}`);
        console.log(`Reference: ${order.reference_id}`);
        console.log(`Recipient: ${delivery.delivery_details?.recipient?.display_name}`);
        console.log(`Address stored: ${JSON.stringify(addr, null, 2)}`);
        console.log('---');
      }
    }
  } catch (error) {
    console.error('Error:', error.message);
  }
}

testSquareOrder();
