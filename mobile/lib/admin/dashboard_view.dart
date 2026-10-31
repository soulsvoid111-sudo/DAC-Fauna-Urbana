import 'package:flutter/material.dart';

import '../models/estatisticas.dart';
import '../models/ocorrencia.dart';
import '../services/admin_controller.dart';
import '../theme.dart';
import '../widgets/comuns.dart';
import '../widgets/detalhe_sheet.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key, required this.controller, required this.irParaOcorrencias});
  final AdminController controller;

  /// Abre a aba de ocorrências já filtrada por um status.
  final void Function(StatusOcorrencia? status) irParaOcorrencias;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final e = controller.estatisticas;
          if (e == null) {
            return Center(
              child: controller.carregando
                  ? const CircularProgressIndicator(color: forest)
                  : Text(controller.erro ?? 'Sem dados.', style: const TextStyle(color: muted)),
            );
          }
          return RefreshIndicator(
            onRefresh: controller.carregar,
            child: LayoutBuilder(builder: (context, box) {
              final largo = box.maxWidth >= 900;
              final graficos = [
                _Painel(titulo: 'Ocorrências por tipo', child: _BarrasTipo(e)),
                _Painel(titulo: 'Situação das ocorrências', child: _BarrasStatus(e, irParaOcorrencias)),
              ];
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _Indicadores(e: e, irParaOcorrencias: irParaOcorrencias),
                  const SizedBox(height: 16),
                  _Painel(
                    titulo: 'Urgentes em aberto (${controller.urgentesAbertas.length})',
                    child: _ListaUrgentes(controller: controller, verTodas: () => irParaOcorrencias(StatusOcorrencia.aberta)),
                  ),
                  const SizedBox(height: 16),
                  _Painel(titulo: 'Registros nos últimos 30 dias', child: _GraficoDias(e.porDia)),
                  const SizedBox(height: 16),
                  if (largo)
                    IntrinsicHeight(
                      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Expanded(child: graficos[0]),
                        const SizedBox(width: 16),
                        Expanded(child: graficos[1]),
                      ]),
                    )
                  else ...[graficos[0], const SizedBox(height: 16), graficos[1]],
                  const SizedBox(height: 16),
                  _Painel(titulo: 'Espécies mais registradas', child: _TopEspecies(e.topEspecies)),
                ],
              );
            }),
          );
        },
      );
}

class _Indicadores extends StatelessWidget {
  const _Indicadores({required this.e, required this.irParaOcorrencias});
  final Estatisticas e;
  final void Function(StatusOcorrencia?) irParaOcorrencias;

  @override
  Widget build(BuildContext context) {
    final itens = [
      ('Total de registros', '${e.total}', Icons.pets_outlined, forest, null),
      ('Urgentes em aberto', '${e.urgentesAbertas}', Icons.emergency_outlined, const Color(0xFFC0392B), StatusOcorrencia.aberta),
      ('Em análise', '${e.status(StatusOcorrencia.emAnalise)}', Icons.manage_search, StatusOcorrencia.emAnalise.cor,
          StatusOcorrencia.emAnalise),
      ('Resolvidas', '${e.status(StatusOcorrencia.resolvida)}', Icons.task_alt, StatusOcorrencia.resolvida.cor,
          StatusOcorrencia.resolvida),
    ];
    return LayoutBuilder(builder: (context, box) {
      final colunas = box.maxWidth >= 700 ? 4 : 2;
      final largura = (box.maxWidth - 12 * (colunas - 1)) / colunas;
      return Wrap(spacing: 12, runSpacing: 12, children: [
        for (final (rotulo, valor, icone, cor, status) in itens)
          SizedBox(
            width: largura,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => irParaOcorrencias(status),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(icone, color: cor, size: 24),
                    const SizedBox(height: 10),
                    Text(valor, style: const TextStyle(color: ink, fontSize: 26, fontWeight: FontWeight.w800, height: 1)),
                    const SizedBox(height: 4),
                    Text(rotulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          ),
      ]);
    });
  }
}

class _Painel extends StatelessWidget {
  const _Painel({required this.titulo, required this.child});
  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: const TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 14),
            child,
          ]),
        ),
      );
}

/// Barra horizontal com rótulo à esquerda e valor à direita.
class _Barra extends StatelessWidget {
  const _Barra({required this.rotulo, required this.valor, required this.maximo, required this.cor, this.icone, this.onTap});
  final String rotulo;
  final int valor;
  final int maximo;
  final Color cor;
  final IconData? icone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            if (icone != null) ...[Icon(icone, size: 18, color: cor), const SizedBox(width: 8)],
            SizedBox(
              width: 112,
              child: Text(rotulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ink, fontSize: 13)),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: maximo == 0 ? 0 : valor / maximo,
                  minHeight: 12,
                  color: cor,
                  backgroundColor: cor.withValues(alpha: 0.1),
                ),
              ),
            ),
            SizedBox(
              width: 36,
              child: Text('$valor',
                  textAlign: TextAlign.right, style: const TextStyle(color: ink, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      );
}

class _BarrasTipo extends StatelessWidget {
  const _BarrasTipo(this.e);
  final Estatisticas e;

  @override
  Widget build(BuildContext context) {
    final maximo = e.porTipo.values.fold(0, (a, b) => a > b ? a : b);
    return Column(children: [
      for (final t in TipoOcorrencia.values)
        _Barra(rotulo: t.rotulo, valor: e.tipo(t), maximo: maximo, cor: t.cor, icone: t.icone),
    ]);
  }
}

class _BarrasStatus extends StatelessWidget {
  const _BarrasStatus(this.e, this.irPara);
  final Estatisticas e;
  final void Function(StatusOcorrencia?) irPara;

  @override
  Widget build(BuildContext context) {
    final maximo = e.porStatus.values.fold(0, (a, b) => a > b ? a : b);
    return Column(children: [
      for (final s in StatusOcorrencia.values)
        _Barra(rotulo: s.rotulo, valor: e.status(s), maximo: maximo, cor: s.cor, onTap: () => irPara(s)),
      const SizedBox(height: 6),
      Align(
        alignment: Alignment.centerLeft,
        child: Text('${e.comFoto} de ${e.total} registros têm foto',
            style: const TextStyle(color: muted, fontSize: 12)),
      ),
    ]);
  }
}

class _GraficoDias extends StatelessWidget {
  const _GraficoDias(this.porDia);
  final List<(DateTime, int)> porDia;

  @override
  Widget build(BuildContext context) {
    final hoje = DateTime.now();
    final inicio = DateTime(hoje.year, hoje.month, hoje.day).subtract(const Duration(days: 29));
    final contagem = {for (final (dia, total) in porDia) DateTime(dia.year, dia.month, dia.day): total};
    final dias = [for (var i = 0; i < 30; i++) inicio.add(Duration(days: i))];
    final maximo = contagem.values.fold(0, (a, b) => a > b ? a : b);
    final totalPeriodo = contagem.values.fold(0, (a, b) => a + b);
    String dm(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

    if (totalPeriodo == 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('Nenhum registro nos últimos 30 dias.', style: TextStyle(color: muted))),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$totalPeriodo registros no período', style: const TextStyle(color: muted, fontSize: 12)),
      const SizedBox(height: 12),
      SizedBox(
        height: 120,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (final d in dias)
            Expanded(
              child: Tooltip(
                message: '${dm(d)}: ${contagem[d] ?? 0}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Container(
                    height: maximo == 0 ? 2 : 2 + 118 * (contagem[d] ?? 0) / maximo,
                    decoration: BoxDecoration(
                      color: (contagem[d] ?? 0) > 0 ? leaf : border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(dm(dias.first), style: const TextStyle(color: muted, fontSize: 11)),
        Text(dm(dias.last), style: const TextStyle(color: muted, fontSize: 11)),
      ]),
    ]);
  }
}

class _TopEspecies extends StatelessWidget {
  const _TopEspecies(this.especies);
  final List<(String, int)> especies;

  @override
  Widget build(BuildContext context) {
    if (especies.isEmpty) {
      return const Text('Nenhuma espécie informada ainda.', style: TextStyle(color: muted));
    }
    final maximo = especies.first.$2;
    return Column(children: [
      for (final (nome, total) in especies) _Barra(rotulo: nome, valor: total, maximo: maximo, cor: forest),
    ]);
  }
}


/// Casos de animal ferido, em risco ou dentro de imóvel que ainda ninguém tratou.
class _ListaUrgentes extends StatelessWidget {
  const _ListaUrgentes({required this.controller, required this.verTodas});
  final AdminController controller;
  final VoidCallback verTodas;

  @override
  Widget build(BuildContext context) {
    final urgentes = controller.urgentesAbertas;
    if (urgentes.isEmpty) {
      return const Row(children: [
        Icon(Icons.task_alt, color: forest, size: 20),
        SizedBox(width: 8),
        Expanded(child: Text('Nenhum caso urgente esperando atendimento.', style: TextStyle(color: muted))),
      ]);
    }
    return Column(children: [
      for (final o in urgentes.take(5))
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: IconeTipo(tipo: o.tipo, tamanho: 40),
          title: Text('#${o.codigo} • ${o.titulo}',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          subtitle: Text('${o.tipo.rotulo} • ${formatarData(o.dataRegistro)}',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => mostrarDetalhe(context, o, urlFoto: controller.urlFoto(o)),
        ),
      if (urgentes.length > 5)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: verTodas, child: Text('Ver todas (${urgentes.length})')),
        ),
    ]);
  }
}
