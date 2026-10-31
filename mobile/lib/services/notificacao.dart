// Notificação do sistema (a que aparece na barra do celular).
// No navegador usa a API de notificações; nas outras plataformas não faz nada.
export 'notificacao_outros.dart' if (dart.library.js_interop) 'notificacao_web.dart';
