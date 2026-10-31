import 'package:flutter/material.dart';

import '../models/ocorrencia.dart';
import '../services/admin_controller.dart';
import '../theme.dart';
import '../widgets/comuns.dart';
import '../widgets/detalhe_sheet.dart';

class OcorrenciasAdminView extends StatelessWidget {
  const OcorrenciasAdminView({super.key, required this.controller});
  final AdminController controller;

  Future<void> _mudarStatus(BuildContext context, Ocorrencia o, StatusOcorrencia s) async {
    final erro = await controller.mudarStatus(o, s);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(erro ?? 'Ocorrência #${o.codigo} agora está "${s.rotulo}".')),
      );
    }
  }

  Future<void> _apagar(BuildContext context, Ocorrencia o) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text('Apagar ocorrência #${o.codigo}?'),
        content: const Text('O registro e a foto serão apagados de vez. Essa ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(contexto, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB3261E)),
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (confirmou != true || !context.mounted) return;
    final erro = await controller.apagar(o);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(erro ?? 'Ocorrência #${o.codigo} apagada.')));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([controller, controller.ocorrencias]),
        builder: (context, _) {
          final c = controller;
          final itens = c.filtradas;
          return RefreshIndicator(
            onRefresh: c.carregar,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                TextField(
                  onChanged: c.buscar,
                  decoration: const InputDecoration(
                    hintText: 'Buscar por descrição, espécie ou número',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    for (final s in StatusOcorrencia.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(s.rotulo),
                          selected: c.filtroStatus == s,
                          showCheckmark: false,
                          selectedColor: s.cor.withValues(alpha: 0.16),
                          side: BorderSide(color: c.filtroStatus == s ? s.cor : border),
                          onSelected: (_) => c.filtrarStatus(s),
                        ),
                      ),
                    for (final t in TipoOcorrencia.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          avatar: Icon(t.icone, size: 16, color: t.cor),
                          label: Text(t.rotulo),
                          selected: c.ocorrencias.filtro == t,
                          showCheckmark: false,
                          selectedColor: t.cor.withValues(alpha: 0.16),
                          side: BorderSide(color: c.ocorrencias.filtro == t ? t.cor : border),
                          onSelected: (_) => c.ocorrencias.filtrar(t),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 10),
                Text('${itens.length} ocorrência(s)', style: const TextStyle(color: muted, fontSize: 12)),
                const SizedBox(height: 10),
                if (itens.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text('Nenhuma ocorrência encontrada.', style: TextStyle(color: muted))),
                  )
                else
                  for (final o in itens)
                    _LinhaOcorrencia(
                      ocorrencia: o,
                      controller: c,
                      onStatus: (s) => _mudarStatus(context, o, s),
                      onApagar: () => _apagar(context, o),
                    ),
              ],
            ),
          );
        },
      );
}

class _LinhaOcorrencia extends StatelessWidget {
  const _LinhaOcorrencia({
    required this.ocorrencia,
    required this.controller,
    required this.onStatus,
    required this.onApagar,
  });
  final Ocorrencia ocorrencia;
  final AdminController controller;
  final ValueChanged<StatusOcorrencia> onStatus;
  final VoidCallback onApagar;

  @override
  Widget build(BuildContext context) {
    final o = ocorrencia;
    final temFoto = o.fotoUrl != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => mostrarDetalhe(context, o, urlFoto: controller.urlFoto(o)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (temFoto)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: FotoOcorrencia(ocorrencia: o, url: controller.urlFoto(o), altura: 56),
                  ),
                )
              else
                IconeTipo(tipo: o.tipo, tamanho: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('#${o.codigo} • ${o.titulo}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ink, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(o.situacao,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ink, fontSize: 13, height: 1.35)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Etiqueta(texto: o.tipo.rotulo, cor: o.tipo.cor),
                    Text(formatarData(o.dataRegistro), style: const TextStyle(color: muted, fontSize: 11)),
                  ]),
                ]),
              ),
              const SizedBox(width: 4),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                PopupMenuButton<StatusOcorrencia>(
                  tooltip: 'Mudar status',
                  onSelected: onStatus,
                  itemBuilder: (_) => [
                    for (final s in StatusOcorrencia.values)
                      PopupMenuItem(
                        value: s,
                        enabled: s != o.status,
                        child: Row(children: [
                          Icon(Icons.circle, size: 10, color: s.cor),
                          const SizedBox(width: 8),
                          Text(s.rotulo),
                        ]),
                      ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: o.status.cor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(o.status.rotulo,
                          style: TextStyle(color: o.status.cor, fontSize: 11, fontWeight: FontWeight.w700)),
                      Icon(Icons.arrow_drop_down, size: 16, color: o.status.cor),
                    ]),
                  ),
                ),
                IconButton(
                  tooltip: 'Apagar ocorrência',
                  onPressed: onApagar,
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFB3261E), size: 20),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
