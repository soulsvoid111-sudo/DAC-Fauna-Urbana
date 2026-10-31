import 'package:flutter/material.dart';

import 'admin/admin_app.dart';
import 'config.dart';
import 'screens/inicio_screen.dart';
import 'screens/registro_screen.dart';
import 'services/meus_registros_controller.dart';
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
  @override
  void initState() {
    super.initState();
    widget.controller.carregar();
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
