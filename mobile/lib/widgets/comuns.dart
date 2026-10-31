import 'package:flutter/material.dart';

import '../models/ocorrencia.dart';
import '../services/api.dart';
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

/// Mostra a foto da ocorrência (da API ou da memória) ou o ícone do tipo.
class FotoOcorrencia extends StatelessWidget {
  const FotoOcorrencia({super.key, required this.ocorrencia, required this.api, this.altura = 180});
  final Ocorrencia ocorrencia;
  final FaunaApi api;
  final double altura;

  @override
  Widget build(BuildContext context) {
    final semFoto = Container(
      height: altura,
      color: ocorrencia.tipo.cor.withValues(alpha: 0.08),
      child: Center(child: Icon(ocorrencia.tipo.icone, color: ocorrencia.tipo.cor.withValues(alpha: 0.5), size: 44)),
    );
    if (ocorrencia.fotoBytes != null) {
      return Image.memory(ocorrencia.fotoBytes!, height: altura, width: double.infinity, fit: BoxFit.cover);
    }
    if (ocorrencia.fotoUrl != null) {
      return Image.network(
        api.urlFoto(ocorrencia.fotoUrl!),
        height: altura,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => semFoto,
      );
    }
    return semFoto;
  }
}

class AvisoDemo extends StatelessWidget {
  const AvisoDemo({super.key, required this.mensagem});
  final String? mensagem;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: warnBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: warnBorder),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.science_outlined, color: warnInk),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Modo demonstração', style: TextStyle(color: warnInk, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                '${mensagem ?? 'Os dados exibidos são fictícios.'} Nada do que for registrado agora vai para o banco.',
                style: const TextStyle(color: warnInk, fontSize: 12, height: 1.4),
              ),
            ]),
          ),
        ]),
      );
}
