import 'package:flutter/material.dart';

import 'admin/admin_app.dart';
import 'config.dart';

import 'screens/lista_screen.dart';
import 'screens/mapa_screen.dart';
import 'screens/registro_screen.dart';
import 'services/ocorrencias_controller.dart';
import 'theme.dart';

void main() => runApp(FaunaUrbanaApp(controller: OcorrenciasController()));

class FaunaUrbanaApp extends StatelessWidget {
  const FaunaUrbanaApp({super.key, required this.controller});
  final OcorrenciasController controller;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: '$nomeApp • $nomeCompleto',
        theme: buildTheme(),
        // Painel administrativo: https://<site>/#/admin
        initialRoute: '/',
        routes: {
          '/': (_) => HomeShell(controller: controller),
          '/admin': (_) => const AdminGate(),
        },
      );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});
  final OcorrenciasController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _aba = 0;

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
                tooltip: 'Atualizar',
                onPressed: widget.controller.carregando ? null : widget.controller.carregar,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: IndexedStack(index: _aba, children: [
          ListaScreen(controller: widget.controller, onRegistrar: _registrar),
          MapaScreen(controller: widget.controller),
        ]),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _registrar,
          backgroundColor: forest,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: const Text('Registrar'),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _aba,
          onDestinationSelected: (i) => setState(() => _aba = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt), label: 'Registros'),
            NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Mapa'),
          ],
        ),
      );
}
