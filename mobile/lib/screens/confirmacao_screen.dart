import 'package:flutter/material.dart';

import '../models/ocorrencia.dart';
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
                const SizedBox(height: 24),
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
