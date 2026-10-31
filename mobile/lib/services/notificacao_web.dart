import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Notificações no celular pelo navegador (Web Push).
/// Android: Chrome. iPhone: só com o SOFUR instalado na Tela de Início (iOS 16.4+).
class Notificacao {
  static bool get suportada =>
      globalContext.has('Notification') &&
      globalContext.has('PushManager') &&
      (web.window.navigator as JSObject).has('serviceWorker');

  static bool get permitida => suportada && web.Notification.permission == 'granted';

  /// A pessoa (ou o navegador) já bloqueou as notificações deste site.
  static bool get bloqueada => suportada && web.Notification.permission == 'denied';

  /// iPhone/iPad no navegador: notificação só funciona com o SOFUR instalado na Tela de Início.
  static bool get precisaInstalar {
    final ua = web.window.navigator.userAgent;
    final ios = ua.contains('iPhone') || ua.contains('iPad');
    final instalado = web.window.matchMedia('(display-mode: standalone)').matches;
    return ios && !instalado;
  }

  /// Precisa ser chamada a partir de um toque do usuário (exigência dos navegadores).
  static Future<bool> pedirPermissao() async {
    if (!suportada) return false;
    try {
      // Se a pessoa ignorar o pedido (ou o Chrome mostrar só o sininho), não fica esperando para sempre.
      final resposta = await web.Notification.requestPermission().toDart.timeout(const Duration(seconds: 45));
      return resposta.toDart == 'granted';
    } catch (_) {
      return false;
    }
  }

  static Future<web.ServiceWorkerRegistration> _registro() async {
    final sw = web.window.navigator.serviceWorker;
    await sw.register('sofur-sw.js'.toJS).toDart.timeout(const Duration(seconds: 20));
    return sw.ready.toDart.timeout(const Duration(seconds: 20));
  }

  /// Inscreve este celular para receber notificações do servidor.
  /// Devolve a inscrição ({endpoint, keys: {p256dh, auth}}) para mandar à API, ou null se não deu.
  static Future<Map<String, dynamic>?> inscrever(String chavePublica) async {
    if (!permitida) return null;
    try {
      final registro = await _registro();
      var inscricao = await registro.pushManager.getSubscription().toDart;
      inscricao ??= await registro.pushManager
          .subscribe(web.PushSubscriptionOptionsInit(
            userVisibleOnly: true,
            applicationServerKey: _base64UrlParaBytes(chavePublica).toJS,
          ))
          .toDart
          .timeout(const Duration(seconds: 30));
      final json = (globalContext['JSON']! as JSObject).callMethod<JSString>('stringify'.toJS, inscricao).toDart;
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Mostra uma notificação agora (usada quando o app está aberto e percebe a mudança).
  static Future<void> mostrar(String titulo, String texto) async {
    if (!permitida) return;
    try {
      final registro = await _registro();
      await registro
          .showNotification(titulo, web.NotificationOptions(body: texto, icon: 'icons/Icon-192.png', tag: titulo))
          .toDart;
    } catch (_) {
      // Sem service worker: o aviso na tela do app continua valendo.
    }
  }

  static Uint8List _base64UrlParaBytes(String texto) {
    final normal = texto.replaceAll('-', '+').replaceAll('_', '/');
    return base64.decode(normal.padRight(normal.length + (4 - normal.length % 4) % 4, '='));
  }
}
