import 'package:flutter/material.dart';

import '../models/ocorrencia.dart';
import '../services/meus_registros_controller.dart';
import '../services/notificacao.dart';
import '../theme.dart';
import 'instalar_screen.dart';
import 'registro_screen.dart';

/// Aparece depois do envio: confirma que a equipe recebeu e mostra o protocolo.
class ConfirmacaoScreen extends StatelessWidget {
  const ConfirmacaoScreen({super.key, required this.registro, required this.controller, this.fotoNaoEnviada = false});
  final MeuRegistro registro;
  final MeusRegistrosController controller;
  final bool fotoNaoEnviada;

  @override
  Widget build(BuildContext context) {
    final o = registro.ocorrencia;
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Registro enviado')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                const SizedBox(height: 12),
                const Center(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: pale,
                    child: Icon(Icons.check_circle_rounded, color: forest, size: 52),
                  ),
                ),
                const SizedBox(height: 18),
                const Text('A equipe SOFUR recebeu seu aviso',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ink, fontSize: 22, fontWeight: FontWeight.w800, height: 1.2)),
                const SizedBox(height: 8),
                const Text('Vamos analisar e acionar os responsáveis. Acompanhe a situação em "Meus registros".',
                    textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 14, height: 1.45)),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Icon(o.tipo.icone, color: o.tipo.cor, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(o.titulo, style: const TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(o.tipo.rotulo, style: const TextStyle(color: muted, fontSize: 12)),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        const Text('Protocolo', style: TextStyle(color: muted, fontSize: 11)),
                        Text('#${o.codigo}',
                            style: const TextStyle(color: forest, fontSize: 22, fontWeight: FontWeight.w800)),
                      ]),
                    ]),
                  ),
                ),
                if (fotoNaoEnviada) ...[
                  const SizedBox(height: 12),
                  const Text('O registro foi recebido, mas a foto não chegou. Isso não impede o atendimento.',
                      style: TextStyle(color: warnInk, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
                if (o.tipo.urgente) ...[
                  const SizedBox(height: 16),
                  const AvisoUrgente(depoisDoEnvio: true),
                ],
                const SizedBox(height: 16),
                _BotaoAvisar(registro: registro, controller: controller),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  child: const Text('Voltar ao início', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pede permissão para avisar (notificação do celular) quando a equipe resolver a ocorrência.
class _BotaoAvisar extends StatefulWidget {
  const _BotaoAvisar({required this.registro, required this.controller});
  final MeuRegistro registro;
  final MeusRegistrosController controller;

  @override
  State<_BotaoAvisar> createState() => _BotaoAvisarState();
}

class _BotaoAvisarState extends State<_BotaoAvisar> {
  // Com permissão já dada, o celular é inscrito automaticamente após o envio.
  late bool _ativado = Notificacao.permitida;
  bool _ativando = false;

  @override
  void initState() {
    super.initState();
    // Logo depois do envio, convida a pessoa a ativar as notificações.
    if (!_ativado) WidgetsBinding.instance.addPostFrameCallback((_) => _convidar());
  }

  Future<void> _convidar() async {
    if (!mounted) return;
    final instalar = Notificacao.precisaInstalar;
    final bloqueada = Notificacao.bloqueada;
    if (!Notificacao.suportada && !instalar) return; // navegador sem suporte: fica só o aviso dentro do app
    final resposta = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        icon: const Icon(Icons.notifications_active_outlined, color: forest, size: 40),
        title: const Text('Quer ser avisado quando sua ocorrência for resolvida?', textAlign: TextAlign.center),
        content: Text(
          instalar
              ? 'No iPhone, as notificações funcionam com o SOFUR instalado na Tela de Início. Veja como instalar em 4 passos.'
              : bloqueada
                  ? 'As notificações do SOFUR estão bloqueadas neste navegador. Toque no cadeado ao lado do endereço, '
                      'em Notificações escolha "Permitir" e depois toque em "Ativar" aqui de novo.'
                  : 'Mandamos uma notificação para o seu celular assim que a equipe resolver, mesmo com o SOFUR fechado.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('Agora não')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(contexto, true),
            icon: Icon(instalar ? Icons.install_mobile : Icons.notifications_active),
            label: Text(instalar ? 'Ver como instalar' : 'Ativar notificações'),
          ),
        ],
      ),
    );
    if (resposta != true || !mounted) return;
    if (instalar) {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const InstalarScreen()));
    } else {
      await _ativar();
    }
  }

  Future<void> _ativar() async {
    setState(() => _ativando = true);
    final ok = await widget.controller.ativarAvisos(widget.registro);
    if (!mounted) return;
    setState(() {
      _ativado = ok;
      _ativando = false;
    });
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(Notificacao.permitida
            ? 'Não foi possível ativar as notificações agora. Você ainda verá o aviso ao abrir o SOFUR.'
            : 'Notificações bloqueadas. Libere nas configurações do navegador para ser avisado.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Notificacao.suportada) {
      return const Text('Quando a equipe resolver, você verá um aviso ao abrir o SOFUR. '
          'No iPhone, instale o SOFUR na Tela de Início para receber notificações.',
          textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 12));
    }
    if (_ativado) {
      return const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.notifications_active_outlined, color: forest, size: 18),
        SizedBox(width: 6),
        Flexible(
          child: Text('Você será avisado quando a equipe resolver.',
              style: TextStyle(color: forest, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ]);
    }
    return OutlinedButton.icon(
      onPressed: _ativando ? null : _ativar,
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      icon: const Icon(Icons.notifications_none),
      label: const Text('Me avise quando for resolvida'),
    );
  }
}
