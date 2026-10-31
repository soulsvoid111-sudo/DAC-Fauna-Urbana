import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Notificações do navegador. No iPhone só funcionam com o SOFUR instalado na tela de início (iOS 16.4+).
class Notificacao {
  static bool get suportada => globalContext.has('Notification');

  static bool get permitida => suportada && web.Notification.permission == 'granted';

  /// Precisa ser chamada a partir de um toque do usuário (exigência dos navegadores).
  static Future<bool> pedirPermissao() async {
    if (!suportada) return false;
    try {
      final resposta = await web.Notification.requestPermission().toDart;
      return resposta.toDart == 'granted';
    } catch (_) {
      return false;
    }
  }

  static void mostrar(String titulo, String texto) {
    if (!permitida) return;
    try {
      web.Notification(titulo, web.NotificationOptions(body: texto, icon: 'icons/Icon-192.png'));
    } catch (_) {
      // Alguns navegadores de celular só permitem notificação pelo service worker; o aviso na tela continua valendo.
    }
  }
}
