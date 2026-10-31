import 'ocorrencia.dart';

class Estatisticas {
  Estatisticas({
    required this.total,
    required this.porTipo,
    required this.porStatus,
    required this.urgentesAbertas,
    required this.comFoto,
    required this.porDia,
    required this.topEspecies,
  });

  final int total;
  final Map<TipoOcorrencia, int> porTipo;
  final Map<StatusOcorrencia, int> porStatus;
  final int urgentesAbertas;
  final int comFoto;
  final List<(DateTime, int)> porDia;
  final List<(String, int)> topEspecies;

  int status(StatusOcorrencia s) => porStatus[s] ?? 0;
  int tipo(TipoOcorrencia t) => porTipo[t] ?? 0;

  factory Estatisticas.fromJson(Map<String, dynamic> json) {
    int n(dynamic v) => (v as num?)?.toInt() ?? 0;
    final tipos = (json['por_tipo'] as Map? ?? {});
    final status = (json['por_status'] as Map? ?? {});
    return Estatisticas(
      total: n(json['total']),
      urgentesAbertas: n(json['urgentes_abertas']),
      comFoto: n(json['com_foto']),
      porTipo: {for (final t in TipoOcorrencia.values) t: n(tipos[t.valorApi])},
      porStatus: {for (final s in StatusOcorrencia.values) s: n(status[s.valorApi])},
      porDia: [
        for (final d in (json['por_dia'] as List? ?? []))
          (DateTime.parse((d as Map)['dia'] as String), n(d['total'])),
      ],
      topEspecies: [
        for (final e in (json['top_especies'] as List? ?? [])) ((e as Map)['especie'] as String, n(e['total'])),
      ],
    );
  }
}
