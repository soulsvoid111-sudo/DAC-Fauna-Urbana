/// Versão para Android/iOS nativos e testes: sem notificação do sistema por enquanto.
class Notificacao {
  static bool get suportada => false;
  static bool get permitida => false;
  static bool get bloqueada => false;
  static bool get precisaInstalar => false;
  static Future<bool> pedirPermissao() async => false;
  static Future<Map<String, dynamic>?> inscrever(String chavePublica) async => null;
  static Future<void> mostrar(String titulo, String texto) async {}
}
