import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/ocorrencia.dart';
import '../services/api.dart';
import '../services/ocorrencias_controller.dart';
import '../theme.dart';
import 'comuns.dart';

Future<void> mostrarDetalhe(BuildContext context, OcorrenciasController controller, Ocorrencia ocorrencia) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        // Busca a versão mais recente (o status pode ter mudado).
        final atual = controller.todas.firstWhere(
          (o) => o.id == ocorrencia.id && o.demo == ocorrencia.demo,
          orElse: () => ocorrencia,
        );
        return _Detalhe(controller: controller, ocorrencia: atual);
      },
    ),
  );
}

class _Detalhe extends StatelessWidget {
  const _Detalhe({required this.controller, required this.ocorrencia});
  final OcorrenciasController controller;
  final Ocorrencia ocorrencia;

  Future<void> _abrirNoMapa() => launchUrl(
        Uri.parse('https://www.google.com/maps/search/?api=1&query=${ocorrencia.latitude},${ocorrencia.longitude}'),
        mode: LaunchMode.externalApplication,
      );

  Future<void> _mudarStatus(BuildContext context, StatusOcorrencia status) async {
    try {
      await controller.atualizarStatus(ocorrencia, status);
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Não foi possível alterar o status agora.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = ocorrencia;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: FotoOcorrencia(ocorrencia: o, api: controller.api, altura: 200),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            Etiqueta(texto: o.tipo.rotulo, cor: o.tipo.cor, icone: o.tipo.icone),
            Etiqueta(texto: o.status.rotulo, cor: o.status.cor),
            if (o.demo) const Etiqueta(texto: 'Demonstração', cor: warnInk),
          ]),
          const SizedBox(height: 12),
          Text(o.titulo,
              style: const TextStyle(color: ink, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
          const SizedBox(height: 4),
          Text('Ocorrência #${o.codigo} • ${formatarData(o.dataRegistro)}',
              style: const TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 14),
          Text(o.situacao, style: const TextStyle(color: ink, fontSize: 15, height: 1.45)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _abrirNoMapa,
            icon: const Icon(Icons.map_outlined),
            label: Text('${o.latitude.toStringAsFixed(5)}, ${o.longitude.toStringAsFixed(5)}'),
          ),
          const SizedBox(height: 22),
          const Text('Acompanhamento', style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 4),
          const Text('Atualize conforme a ocorrência for tratada.', style: TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in StatusOcorrencia.values)
                ChoiceChip(
                  label: Text(s.rotulo),
                  selected: o.status == s,
                  selectedColor: s.cor.withValues(alpha: 0.16),
                  side: BorderSide(color: o.status == s ? s.cor : border),
                  onSelected: (_) {
                    if (o.status != s) _mudarStatus(context, s);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
