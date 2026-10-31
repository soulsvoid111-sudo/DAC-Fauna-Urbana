import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

enum TipoOcorrencia {
  avistamento('Avistamento', Icons.visibility_outlined, Color(0xFF2E7D57)),
  ferido('Animal ferido', Icons.healing_outlined, Color(0xFFC0392B)),
  atropelado('Atropelamento', Icons.car_crash_outlined, Color(0xFF8E3B2F)),
  emRisco('Em risco', Icons.warning_amber_rounded, Color(0xFFD0791E)),
  emImovel('Dentro de imóvel', Icons.home_outlined, Color(0xFF2D6CA8));

  const TipoOcorrencia(this.rotulo, this.icone, this.cor);
  final String rotulo;
  final IconData icone;
  final Color cor;

  /// Situações em que o animal precisa de ajuda rápida.
  bool get urgente => this == ferido || this == emRisco || this == emImovel;

  String get valorApi => switch (this) {
        emRisco => 'em_risco',
        emImovel => 'em_imovel',
        _ => name,
      };

  static TipoOcorrencia daApi(String? valor) =>
      values.firstWhere((t) => t.valorApi == valor, orElse: () => avistamento);
}

enum StatusOcorrencia {
  aberta('Aberta', Color(0xFF2D6CA8)),
  emAnalise('Em análise', Color(0xFFB7791F)),
  resolvida('Resolvida', Color(0xFF2E7D57)),
  descartada('Descartada', Color(0xFF7A8580));

  const StatusOcorrencia(this.rotulo, this.cor);
  final String rotulo;
  final Color cor;

  String get valorApi => this == emAnalise ? 'em_analise' : name;

  static StatusOcorrencia daApi(String? valor) =>
      values.firstWhere((s) => s.valorApi == valor, orElse: () => aberta);
}

class Ocorrencia {
  Ocorrencia({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.situacao,
    required this.tipo,
    required this.status,
    required this.dataRegistro,
    this.especie,
    this.fotoUrl,
    this.fotoBytes,
    this.demo = false,
  });

  final int id;
  final double latitude;
  final double longitude;
  final String situacao;
  final TipoOcorrencia tipo;
  final StatusOcorrencia status;
  final DateTime? dataRegistro;
  final String? especie;

  /// Caminho devolvido pela API (ex.: /uploads/1_abc.jpg).
  final String? fotoUrl;

  /// Foto guardada só na memória (modo demonstração).
  final Uint8List? fotoBytes;
  final bool demo;

  LatLng get ponto => LatLng(latitude, longitude);
  String get codigo => demo ? 'D$id' : '$id';
  String get titulo => especie ?? tipo.rotulo;

  factory Ocorrencia.fromJson(Map<String, dynamic> json) => Ocorrencia(
        id: (json['id'] as num).toInt(),
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        situacao: json['situacao']?.toString() ?? '',
        tipo: TipoOcorrencia.daApi(json['tipo'] as String?),
        status: StatusOcorrencia.daApi(json['status'] as String?),
        especie: json['especie'] as String?,
        fotoUrl: json['foto_url'] as String?,
        dataRegistro: DateTime.tryParse(json['data_registro']?.toString() ?? ''),
      );

  Ocorrencia copyWith({StatusOcorrencia? status, String? fotoUrl, Uint8List? fotoBytes}) => Ocorrencia(
        id: id,
        latitude: latitude,
        longitude: longitude,
        situacao: situacao,
        tipo: tipo,
        especie: especie,
        dataRegistro: dataRegistro,
        demo: demo,
        status: status ?? this.status,
        fotoUrl: fotoUrl ?? this.fotoUrl,
        fotoBytes: fotoBytes ?? this.fotoBytes,
      );
}

/// Dados preenchidos no formulário, antes de virarem uma ocorrência.
class NovaOcorrencia {
  NovaOcorrencia({
    required this.ponto,
    required this.situacao,
    required this.tipo,
    this.especie,
    this.foto,
    this.nomeFoto,
  });

  final LatLng ponto;
  final String situacao;
  final TipoOcorrencia tipo;
  final String? especie;
  final Uint8List? foto;
  final String? nomeFoto;

  Map<String, dynamic> toJson() => {
        'latitude': ponto.latitude,
        'longitude': ponto.longitude,
        'situacao': situacao,
        'tipo': tipo.valorApi,
        'especie': especie,
      };
}

String formatarData(DateTime? data) {
  if (data == null) return 'Data não informada';
  final d = data.toLocal();
  String dois(int n) => n.toString().padLeft(2, '0');
  return '${dois(d.day)}/${dois(d.month)}/${d.year} • ${dois(d.hour)}:${dois(d.minute)}';
}
