import 'package:flutter/material.dart';

import '../models/ocorrencia.dart';
import '../services/notificacao.dart';
import '../theme.dart';
import 'registro_screen.dart';

/// Aparece depois do envio: confirma que a equipe recebeu e mostra o protocolo.
class ConfirmacaoScreen extends StatelessWidget {
  const ConfirmacaoScreen({super.key, required this.registro, this.fotoNaoEnviada = false});
  final MeuRegistro registro;
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
                const _BotaoAvisar(),
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
  const _BotaoAvisar();

  @override
  State<_BotaoAvisar> createState() => _BotaoAvisarState();
}

class _BotaoAvisarState extends State<_BotaoAvisar> {
  late bool _ativado = Notificacao.permitida;

  Future<void> _ativar() async {
    final ok = await Notificacao.pedirPermissao();
    if (!mounted) return;
    setState(() => _ativado = ok);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sem permissão de notificação. Você ainda verá o aviso ao abrir o SOFUR.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Notificacao.suportada) {
      return const Text('Quando a equipe resolver, você verá um aviso ao abrir o SOFUR.',
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
      onPressed: _ativar,
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      icon: const Icon(Icons.notifications_none),
      label: const Text('Me avise quando for resolvida'),
    );
  }
}
