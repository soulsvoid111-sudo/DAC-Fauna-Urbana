import 'package:flutter/material.dart';

import '../models/ocorrencia.dart';
import '../services/ocorrencias_controller.dart';
import '../theme.dart';

class Etiqueta extends StatelessWidget {
  const Etiqueta({super.key, required this.texto, required this.cor, this.icone});
  final String texto;
  final Color cor;
  final IconData? icone;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: cor.withValues(alpha: 0.11), borderRadius: BorderRadius.circular(30)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icone != null) ...[Icon(icone, size: 13, color: cor), const SizedBox(width: 4)],
          Text(texto, style: TextStyle(color: cor, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      );
}

class IconeTipo extends StatelessWidget {
  const IconeTipo({super.key, required this.tipo, this.tamanho = 44});
  final TipoOcorrencia tipo;
  final double tamanho;

  @override
  Widget build(BuildContext context) => Container(
        width: tamanho,
        height: tamanho,
        decoration: BoxDecoration(
          color: tipo.cor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(tamanho * 0.32),
        ),
        child: Icon(tipo.icone, color: tipo.cor, size: tamanho * 0.5),
      );
}

/// Mostra a foto da ocorrência (endereço já com permissão) ou o ícone do tipo.
class FotoOcorrencia extends StatelessWidget {
  const FotoOcorrencia({super.key, required this.ocorrencia, required this.url, this.altura = 180});
  final Ocorrencia ocorrencia;
  final String? url;
  final double altura;

  @override
  Widget build(BuildContext context) {
    final semFoto = Container(
      height: altura,
      color: ocorrencia.tipo.cor.withValues(alpha: 0.08),
      child: Center(child: Icon(ocorrencia.tipo.icone, color: ocorrencia.tipo.cor.withValues(alpha: 0.5), size: 44)),
    );
    if (url == null) return semFoto;
    return Image.network(url!, height: altura, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, _, _) => semFoto);
  }
}

/// Filtro por tipo de ocorrência (painel da equipe).
class FiltroTipos extends StatelessWidget {
  const FiltroTipos({super.key, required this.controller, this.fundoBranco = false});
  final OcorrenciasController controller;
  final bool fundoBranco;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final tipo in TipoOcorrencia.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  avatar: Icon(tipo.icone, size: 16, color: tipo.cor),
                  label: Text('${tipo.rotulo} (${controller.contar(tipo)})'),
                  selected: controller.filtro == tipo,
                  showCheckmark: false,
                  backgroundColor: fundoBranco ? Colors.white : null,
                  selectedColor: tipo.cor.withValues(alpha: 0.16),
                  side: BorderSide(color: controller.filtro == tipo ? tipo.cor : border),
                  onSelected: (_) => controller.filtrar(tipo),
                ),
              ),
          ],
        ),
      );
}
