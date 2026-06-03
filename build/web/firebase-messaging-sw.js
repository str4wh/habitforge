// Firebase Messaging Service Worker
// Handles push notifications when the app tab is closed or in the background.

importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey:            'AIzaSyAVXuBFerfqrX3UVhWqhA06CQW0iWSqaEY',
  authDomain:        'habitforge-60e2e.firebaseapp.com',
  projectId:         'habitforge-60e2e',
  storageBucket:     'habitforge-60e2e.firebasestorage.app',
  messagingSenderId: '1066005121147',
  appId:             '1:1066005121147:web:d8d7012f1ce24354c03ade',
});

const messaging = firebase.messaging();

// Show notification when app is in the background / closed
messaging.onBackgroundMessage((payload) => {
  const title   = payload.notification?.title ?? 'HabitForge';
  const options = {
    body:             payload.notification?.body ?? '',
    icon:             '/icons/Icon-192.png',
    badge:            '/icons/Icon-192.png',
    tag:              'habitforge-daily',
    renotify:         true,
    requireInteraction: false,
    data:             { url: '/' },
  };
  return self.registration.showNotification(title, options);
});

// Open / focus the app when the notification is clicked
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = event.notification.data?.url ?? '/';
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        for (const client of clientList) {
          if (client.url.includes(self.location.origin) && 'focus' in client) {
            return client.focus();
          }
        }
        return clients.openWindow(url);
      }),
  );
});
