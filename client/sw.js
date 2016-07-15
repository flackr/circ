console.log('Started', self);
self.addEventListener('install', function(event) {
  self.skipWaiting();
  console.log('Installed', event);
});
self.addEventListener('activate', function(event) {
  console.log('Activated', event);
});
self.addEventListener('push', function(event) {
  console.log('Push message received', event);
  // TODO(flackr): Fetch the unread IRC messages and display them in the notification.
  var title = 'IRC Message Received';
  event.waitUntil(
    self.registration.showNotification(title, {
      body: 'You have unread notifications on CIRC',
      icon: 'images/icon128.png',
      tag: 'circ'
    }));
});