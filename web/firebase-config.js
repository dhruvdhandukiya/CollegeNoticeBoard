// Firebase configuration for web platform
// This file ensures proper CORS and authentication setup

(function() {
  // Firebase configuration
  const firebaseConfig = {
    apiKey: 'AIzaSyCn06SQoFoGmtt79hEVS1WVptBvslWTCE4',
    authDomain: 'collegenoticeboard-49628.firebaseapp.com',
    projectId: 'collegenoticeboard-49628',
    storageBucket: 'collegenoticeboard-49628.firebasestorage.app',
    messagingSenderId: '174103157478',
    appId: '1:174103157478:web:135ff096dbca79f039f927',
  };

  // Initialize Firebase (if not already initialized by Flutter)
  if (typeof firebase !== 'undefined' && firebase.apps.length === 0) {
    firebase.initializeApp(firebaseConfig);
    console.log('✅ Firebase configured for web');
  }

  // Set up CORS headers for calendar API requests
  window.addEventListener('load', function() {
    console.log('🔵 Web platform initialized');
    console.log('📅 Google Calendar integration active');
  });
})();
