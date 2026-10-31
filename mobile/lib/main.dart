import 'dart:async';

import 'package:flutter/material.dart';

import 'admin/admin_app.dart';
import 'config.dart';
import 'models/ocorrencia.dart';
import 'screens/inicio_screen.dart';
import 'screens/registro_screen.dart';
import 'services/meus_registros_controller.dart';
import 'services/notificacao.dart';
import 'theme.dart';

void main() => runApp(SofurApp(controller: MeusRegistrosController()));

class SofurApp extends StatelessWidget {
  const SofurApp({super.key, required this.controller});
  final MeusRegistrosController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: '$nomeApp • $nomeCompleto',
        theme: buildTheme(),
        // Quem registra usa "/". O painel da equipe fica em https://<site>/#/admin
        initialRoute: '/',
        routes: {
          '/': (_) => HomeShell(controller: controller),
          '/admin': (_) => const AdminGate(),
        },
      );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});
  final MeusRegistrosController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  Timer? _verificacao;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_avisarMudancas);
    widget.controller.carregar();
    // Enquanto o app está aberto, confere a cada minuto se a equipe atualizou algum registro.
    _verificacao = Timer.periodic(const Duration(seconds: 60), (_) => widget.controller.atualizarSituacao());
  }

  @override
  void dispose() {
    _verificacao?.cancel();
    widget.controller.removeListener(_avisarMudancas);
    super.dispose();
  }

  void _avisarMudancas() {
    if (!mounted || widget.controller.mudancas.isEmpty) return;
    for (final m in widget.controller.consumirMudancas()) {
      Notificacao.mostrar(m.titulo, m.mensagem);
      if (m.atual == StatusOcorrencia.resolvida) {
        showDialog<void>(
          context: context,
          builder: (contexto) => AlertDialog(
            icon: const Icon(Icons.volunteer_activism, color: forest, size: 40),
            title: Text(m.titulo, textAlign: TextAlign.center),
            content: Text(m.mensagem, textAlign: TextAlign.center),
            actions: [
              FilledButton(onPressed: () => Navigator.pop(contexto), child: const Text('Que bom!')),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(m.mensagem), duration: const Duration(seconds: 6)),
        );
      }
    }
  }

  void _registrar() => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => RegistroScreen(controller: widget.controller)),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          titleSpacing: 16,
          title: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.asset('assets/icone_app.png', width: 34, height: 34),
            ),
            const SizedBox(width: 10),
            const Text(nomeApp, style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ]),
          actions: [
            ListenableBuilder(
              listenable: widget.controller,
              builder: (_, _) => IconButton(
                tooltip: 'Atualizar meus registros',
                onPressed: widget.controller.carregando ? null : widget.controller.atualizarSituacao,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: InicioScreen(controller: widget.controller, onRegistrar: _registrar),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _registrar,
          backgroundColor: forest,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: const Text('Registrar'),
        ),
      );
}
