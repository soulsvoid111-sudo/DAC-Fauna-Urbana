/// Versão para Android/iOS nativos e testes: sem notificação do sistema por enquanto.
class Notificacao {
  static bool get suportada => false;
  static bool get permitida => false;
  static Future<bool> pedirPermissao() async => false;
  static void mostrar(String titulo, String texto) {}
}
