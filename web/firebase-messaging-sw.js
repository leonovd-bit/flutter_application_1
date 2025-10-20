// Import and configure the Firebase SDK
importScripts('https://www.gstatic.com/firebasejs/10.4.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.4.0/firebase-messaging-compat.js');

// Initialize the Firebase app in the service worker
firebase.initializeApp({
  apiKey: "AIzaSyA0bFi6iX9XP7i7X3D1hULdTX8VQfShJ20",
  authDomain: "freshpunk-48db1.firebaseapp.com",
  projectId: "freshpunk-48db1",
  storageBucket: "freshpunk-48db1.appspot.com",
  messagingSenderId: "1002944195999",
  appId: "1:1002944195999:web:8f9a3b4c5d6e7f8g9h0i1j2k",
});

// Retrieve an instance of Firebase Messaging so that it can handle background messages
const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  
  // Customize notification here
  const notificationTitle = payload.notification?.title || 'FreshPunk';
  const notificationOptions = {
    body: payload.notification?.body || 'You have a new message',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});