// Service worker do SOFUR: recebe as notificações do servidor e mostra no celular,
// mesmo com o app fechado.

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (evento) => evento.waitUntil(self.clients.claim()));

self.addEventListener('push', (evento) => {
  let dados = {};
  try {
    dados = evento.data ? evento.data.json() : {};
  } catch (_) {
    dados = { titulo: 'SOFUR', mensagem: evento.data ? evento.data.text() : '' };
  }
  const titulo = dados.titulo || 'SOFUR';
  evento.waitUntil(
    self.registration.showNotification(titulo, {
      body: dados.mensagem || 'Há uma novidade sobre a sua ocorrência.',
      icon: 'icons/Icon-192.png',
      badge: 'icons/Icon-192.png',
      tag: dados.tag || 'sofur',
      data: { url: dados.url || '/' },
    }),
  );
});

// Tocar na notificação abre o SOFUR (ou traz a janela que já estava aberta).
self.addEventListener('notificationclick', (evento) => {
  evento.notification.close();
  const destino = new URL(evento.notification.data && evento.notification.data.url ? evento.notification.data.url : '/', self.location.origin).href;
  evento.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((janelas) => {
      for (const janela of janelas) {
        if (janela.url.startsWith(self.location.origin) && 'focus' in janela) return janela.focus();
      }
      return self.clients.openWindow(destino);
    }),
  );
});
