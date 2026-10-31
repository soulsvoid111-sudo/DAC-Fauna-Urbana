import 'package:flutter/material.dart';

import '../config.dart';
import '../models/ocorrencia.dart';
import '../screens/mapa_screen.dart';
import '../services/admin_controller.dart';
import '../theme.dart';
import 'dashboard_view.dart';
import 'login_screen.dart';
import 'ocorrencias_view.dart';

/// Entrada do painel: mostra o login ou o painel, conforme a sessão.
class AdminGate extends StatefulWidget {
  const AdminGate({super.key, this.controller});
  final AdminController? controller;

  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  late final AdminController _controller = widget.controller ?? AdminController();

  @override
  void initState() {
    super.initState();
    _controller.iniciar();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.iniciando) {
            return const Scaffold(body: Center(child: CircularProgressIndicator(color: forest)));
          }
          return _controller.logado
              ? AdminHome(controller: _controller)
              : AdminLoginScreen(controller: _controller);
        },
      );
}

class AdminHome extends StatefulWidget {
  const AdminHome({super.key, required this.controller});
  final AdminController controller;

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _aba = 0;

  static const _destinos = [
    (Icons.space_dashboard_outlined, Icons.space_dashboard, 'Painel'),
    (Icons.list_alt_outlined, Icons.list_alt, 'Ocorrências'),
    (Icons.map_outlined, Icons.map, 'Mapa'),
  ];

  void _irParaOcorrencias(StatusOcorrencia? status) {
    final c = widget.controller;
    c.filtroStatus = status;
    c.ocorrencias.filtro = null;
    c.buscar('');
    setState(() => _aba = 1);
  }

  Future<void> _sair() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Sair do painel?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(contexto, true), child: const Text('Sair')),
        ],
      ),
    );
    if (confirmou == true) widget.controller.sair();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final telas = [
      DashboardView(controller: c, irParaOcorrencias: _irParaOcorrencias),
      OcorrenciasAdminView(controller: c),
      MapaScreen(controller: c.ocorrencias),
    ];
    return LayoutBuilder(builder: (context, box) {
      final largo = box.maxWidth >= 800;
      final corpo = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _aba == 2 ? double.infinity : 1100),
          child: IndexedStack(index: _aba, children: telas),
        ),
      );
      return Scaffold(
        appBar: AppBar(
          titleSpacing: 16,
          title: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.asset('assets/icone_app.png', width: 34, height: 34),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(largo ? '$nomeApp • Administração' : 'Administração',
                  overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ]),
          actions: [
            ListenableBuilder(
              listenable: c,
              builder: (_, _) => IconButton(
                tooltip: 'Atualizar',
                onPressed: c.carregando ? null : c.carregar,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Conta',
              icon: const Icon(Icons.account_circle_outlined),
              onSelected: (v) {
                if (v == 'app') Navigator.of(context).pushReplacementNamed('/');
                if (v == 'sair') _sair();
              },
              itemBuilder: (_) => [
                PopupMenuItem(enabled: false, child: Text('Conectado como ${c.usuario ?? ''}')),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'app',
                  child: ListTile(leading: Icon(Icons.phone_android), title: Text('Ver aplicativo'), dense: true),
                ),
                const PopupMenuItem(
                  value: 'sair',
                  child: ListTile(leading: Icon(Icons.logout), title: Text('Sair'), dense: true),
                ),
              ],
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: largo
            ? Row(children: [
                NavigationRail(
                  selectedIndex: _aba,
                  onDestinationSelected: (i) => setState(() => _aba = i),
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: Colors.white,
                  indicatorColor: pale,
                  destinations: [
                    for (final (icone, iconeSel, rotulo) in _destinos)
                      NavigationRailDestination(icon: Icon(icone), selectedIcon: Icon(iconeSel), label: Text(rotulo)),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: corpo),
              ])
            : corpo,
        bottomNavigationBar: largo
            ? null
            : NavigationBar(
                selectedIndex: _aba,
                onDestinationSelected: (i) => setState(() => _aba = i),
                destinations: [
                  for (final (icone, iconeSel, rotulo) in _destinos)
                    NavigationDestination(icon: Icon(icone), selectedIcon: Icon(iconeSel), label: rotulo),
                ],
              ),
      );
    });
  }
}
