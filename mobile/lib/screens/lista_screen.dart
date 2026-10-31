import 'package:flutter/material.dart';

import '../models/ocorrencia.dart';
import '../services/ocorrencias_controller.dart';
import '../theme.dart';
import '../widgets/comuns.dart';
import '../widgets/detalhe_sheet.dart';

class ListaScreen extends StatelessWidget {
  const ListaScreen({super.key, required this.controller, required this.onRegistrar});
  final OcorrenciasController controller;
  final VoidCallback onRegistrar;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final c = controller;
          final itens = c.visiveis;
          return RefreshIndicator(
            onRefresh: c.carregar,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                  children: [
                    _Hero(onRegistrar: onRegistrar),
                    const SizedBox(height: 16),
                    if (c.modoDemonstracao) ...[AvisoDemo(mensagem: c.aviso), const SizedBox(height: 16)],
                    _Resumo(total: c.todas.length, urgentes: c.urgentesAbertas, conectado: !c.modoDemonstracao),
                    const SizedBox(height: 24),
                    const Text('Registros recentes',
                        style: TextStyle(color: ink, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                    const SizedBox(height: 10),
                    FiltroTipos(controller: c),
                    const SizedBox(height: 14),
                    if (c.carregando && c.todas.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(30),
                        child: Center(child: CircularProgressIndicator(color: forest)),
                      )
                    else if (itens.isEmpty)
                      _Vazio(filtrando: c.filtro != null, onRegistrar: onRegistrar)
                    else
                      ...itens.map((o) => _CartaoOcorrencia(controller: c, ocorrencia: o)),
                  ],
                ),
              ),
            ),
          );
        },
      );
}

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

class _Hero extends StatelessWidget {
  const _Hero({required this.onRegistrar});
  final VoidCallback onRegistrar;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF174B38), Color(0xFF347454)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(children: [
          Positioned(
            right: -10,
            top: -4,
            child: Icon(Icons.nature_people_outlined, size: 100, color: Colors.white.withValues(alpha: 0.12)),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('CIÊNCIA CIDADÃ',
                style: TextStyle(color: Color(0xFFCFE6D7), fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            const Text('Viu um animal silvestre na cidade?',
                style: TextStyle(color: Colors.white, fontSize: 24, height: 1.15, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
            const SizedBox(height: 8),
            const Text('Registre com foto e localização. Cada registro ajuda a proteger a fauna urbana de MS.',
                style: TextStyle(color: Color(0xFFE0EEE4), fontSize: 13, height: 1.45)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRegistrar,
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: forest),
              icon: const Icon(Icons.add_a_photo_outlined, size: 19),
              label: const Text('Fazer um registro', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ]),
        ]),
      );
}

class _Resumo extends StatelessWidget {
  const _Resumo({required this.total, required this.urgentes, required this.conectado});
  final int total;
  final int urgentes;
  final bool conectado;

  Widget _bloco(String rotulo, String valor, IconData icone, Color cor) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(icone, color: cor, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(valor, style: const TextStyle(color: ink, fontSize: 22, height: 1.1, fontWeight: FontWeight.w800)),
                  Text(rotulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Row(children: [
        _bloco('registros', '$total', Icons.pets_outlined, forest),
        const SizedBox(width: 10),
        _bloco('urgentes', '$urgentes', Icons.emergency_outlined, const Color(0xFFC0392B)),
        const SizedBox(width: 10),
        Tooltip(
          message: conectado ? 'Conectado ao servidor' : 'Modo demonstração',
          child: Icon(conectado ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
              color: conectado ? forest : warnInk),
        ),
      ]);
}

class _CartaoOcorrencia extends StatelessWidget {
  const _CartaoOcorrencia({required this.controller, required this.ocorrencia});
  final OcorrenciasController controller;
  final Ocorrencia ocorrencia;

  @override
  Widget build(BuildContext context) {
    final o = ocorrencia;
    final temFoto = o.fotoBytes != null || o.fotoUrl != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => mostrarDetalhe(context, controller, o),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (temFoto)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(width: 64, height: 64, child: FotoOcorrencia(ocorrencia: o, api: controller.api, altura: 64)),
                )
              else
                IconeTipo(tipo: o.tipo, tamanho: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(o.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    Etiqueta(texto: o.tipo.rotulo, cor: o.tipo.cor),
                    Etiqueta(texto: o.status.rotulo, cor: o.status.cor),
                  ]),
                  const SizedBox(height: 8),
                  Text(o.situacao,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ink, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 6),
                  Text('#${o.codigo} • ${formatarData(o.dataRegistro)}',
                      style: const TextStyle(color: muted, fontSize: 11)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio({required this.filtrando, required this.onRegistrar});
  final bool filtrando;
  final VoidCallback onRegistrar;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          child: Column(children: [
            const Icon(Icons.nature_outlined, color: forest, size: 36),
            const SizedBox(height: 12),
            Text(filtrando ? 'Nenhum registro deste tipo' : 'Ainda não há registros',
                style: const TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 6),
            const Text('Compartilhe uma observação de fauna urbana com a comunidade.',
                textAlign: TextAlign.center, style: TextStyle(color: muted, height: 1.45, fontSize: 13)),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRegistrar,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Registrar ocorrência'),
            ),
          ]),
        ),
      );
}
