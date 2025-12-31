const jwt = require('jsonwebtoken');
const axios = require('axios');

const accessKey = {
  developer_id: '0d49eb6a-e781-452e-8ee1-dc04505eade1',
  key_id: '498ce2b7-4573-408e-a1cf-967ad119855b',
  signing_secret: 'G7Z9g4goWZ-HcKvfOEU3q2_ylkDtQsqu95bisRmWk5o'
};

const data = {
  aud: 'doordash',
  iss: accessKey.developer_id,
  kid: accessKey.key_id,
  exp: Math.floor(Date.now() / 1000 + 300),
  iat: Math.floor(Date.now() / 1000),
};

const headers = {
  algorithm: 'HS256',
  header: {
    'dd-ver': 'DD-JWT-V1'
  }
};

const token = jwt.sign(
  data,
  Buffer.from(accessKey.signing_secret, 'base64'),
  headers,
);

console.log('JWT Token:', token);

const body = JSON.stringify({
  external_delivery_id: 'D-12345',
  pickup_address: '901 Market Street 6th Floor San Francisco, CA 94103',
  pickup_business_name: 'Wells Fargo SF Downtown',
  pickup_phone_number: '+16505555555',
  pickup_instructions: 'Enter gate code 1234 on the callbox.',
  dropoff_address: '901 Market Street 6th Floor San Francisco, CA 94103',
  dropoff_business_name: 'Wells Fargo SF Downtown',
  dropoff_phone_number: '+16505555555',
  dropoff_instructions: 'Enter gate code 1234 on the callbox.',
  order_value: 1999,
});

axios
  .post('https://openapi.doordash.com/drive/v2/deliveries', body, {
    headers: {
      Authorization: 'Bearer ' + token,
      'Content-Type': 'application/json',
    },
  })
  .then(function (response) {
    console.log('Delivery created successfully:');
    console.log(response.data);
  })
  .catch(function (error) {
    console.log('Error creating delivery:');
    console.log(error.response ? error.response.data : error.message);
  });
