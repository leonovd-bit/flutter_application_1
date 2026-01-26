#!/usr/bin/env node
/**
 * Convert Firebase CI token to application default credentials
 * Then use test_order.js to create the order
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

async function setupAndCreateOrder() {
  try {
    const token = process.env.FIREBASE_TOKEN;
    
    if (!token) {
      console.error('❌ FIREBASE_TOKEN not set');
      console.error('Set it first: $env:FIREBASE_TOKEN = "your-token"');
      process.exit(1);
    }

    console.log('🔧 Setting up authentication...');
    
    // Create a temporary credentials file that firebase-admin can use
    // Note: This is a simplified approach - in production you'd use a proper service account
    
    // For now, let's just try to run the existing test_order.js with the token set
    console.log('\n📝 Running existing test_order.js script...');
    console.log('   This script creates a test order and sends it to Square\n');
    
    try {
      // Set the token in environment and run test_order.js
      process.env.FIREBASE_TOKEN = token;
      
      // Run test_order.js
      const result = execSync('node test_order.js', {
        cwd: __dirname,
        stdio: 'inherit',
        env: {...process.env, FIREBASE_TOKEN: token}
      });
      
      console.log('\n✅ Order created successfully!');
    } catch (error) {
      console.log('\n⚠️  test_order.js needs service account credentials.');
      console.log('\nThe script needs a service account key from Google Cloud Console.');
      console.log('Download it from:');
      console.log('  → https://console.cloud.google.com/iam-admin/serviceaccounts');
      console.log('  → Project: freshpunk-48db1');
      console.log('  → Create a new service account or use existing one');
      console.log('  → Create a key (JSON format)');
      console.log('  → Save as: functions/serviceAccountKey.json');
    }

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

setupAndCreateOrder();
