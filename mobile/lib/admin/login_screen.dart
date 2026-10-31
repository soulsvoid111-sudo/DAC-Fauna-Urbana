import 'package:flutter/material.dart';

import '../services/admin_controller.dart';
import '../theme.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key, required this.controller});
  final AdminController controller;

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _form = GlobalKey<FormState>();
  final _usuario = TextEditingController();
  final _senha = TextEditingController();
  bool _mostrarSenha = false;

  @override
  void dispose() {
    _usuario.dispose();
    _senha.dispose();
    super.dispose();
  }

  void _entrar() {
    if (!_form.currentState!.validate()) return;
    widget.controller.entrar(_usuario.text, _senha.text);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: ListenableBuilder(
                  listenable: widget.controller,
                  builder: (context, _) {
                    final c = widget.controller;
                    return Form(
                      key: _form,
                      child: AutofillGroup(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          const CircleAvatar(
                            radius: 30,
                            backgroundColor: pale,
                            child: Icon(Icons.admin_panel_settings_outlined, color: forest, size: 30),
                          ),
                          const SizedBox(height: 16),
                          const Text('Painel administrativo',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: ink, fontSize: 24, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          const Text('Fauna Urbana • acesso restrito à equipe',
                              textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 13)),
                          const SizedBox(height: 28),
                          TextFormField(
                            controller: _usuario,
                            enabled: !c.carregando,
                            autofillHints: const [AutofillHints.username],
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(labelText: 'Usuário', prefixIcon: Icon(Icons.person_outline)),
                            validator: (v) => (v ?? '').trim().isEmpty ? 'Informe o usuário.' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _senha,
                            enabled: !c.carregando,
                            obscureText: !_mostrarSenha,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _entrar(),
                            decoration: InputDecoration(
                              labelText: 'Senha',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _mostrarSenha ? 'Esconder senha' : 'Mostrar senha',
                                onPressed: () => setState(() => _mostrarSenha = !_mostrarSenha),
                                icon: Icon(_mostrarSenha ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                              ),
                            ),
                            validator: (v) => (v ?? '').isEmpty ? 'Informe a senha.' : null,
                          ),
                          if (c.erro != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDECEA),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(children: [
                                const Icon(Icons.error_outline, color: Color(0xFF8C1D18), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(c.erro!, style: const TextStyle(color: Color(0xFF8C1D18), fontSize: 13)),
                                ),
                              ]),
                            ),
                          ],
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: c.carregando ? null : _entrar,
                            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                            child: c.carregando
                                ? const SizedBox(
                                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Entrar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
                            icon: const Icon(Icons.arrow_back, size: 18),
                            label: const Text('Voltar para o aplicativo'),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
}
