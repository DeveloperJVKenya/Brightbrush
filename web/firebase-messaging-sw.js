// Background push notifications for the web app (Firebase Cloud Messaging).
// Version must match the Firebase JS SDK used by firebase_core_web.
importScripts('https://www.gstatic.com/firebasejs/12.15.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.15.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAGOWKi9hr_wFTBet4KNdNuBSgU8MJxLRs',
  authDomain: 'bright-brush.firebaseapp.com',
  projectId: 'bright-brush',
  storageBucket: 'bright-brush.firebasestorage.app',
  messagingSenderId: '569026003826',
  appId: '1:569026003826:web:3703c52129f48fe59c53eb',
});

// Notifications with a `notification` payload are shown automatically;
// clicking one opens the link sent in webpush.fcmOptions.link.
firebase.messaging();
