import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile/main.dart';
import 'package:mobile/models/ocorrencia.dart';
import 'package:mobile/services/api.dart';
import 'package:mobile/services/ocorrencias_controller.dart';

void main() {
  test('converte o JSON da API em ocorrência', () {
    final o = Ocorrencia.fromJson({
      'id': 7,
      'latitude': -20.47,
      'longitude': -54.62,
      'situacao': 'Quati ferido',
      'tipo': 'em_risco',
      'status': 'em_analise',
      'especie': 'Quati',
      'foto_url': null,
      'data_registro': '2026-10-22T09:15:00Z',
    });
    expect(o.tipo, TipoOcorrencia.emRisco);
    expect(o.status, StatusOcorrencia.emAnalise);
    expect(o.titulo, 'Quati');
  });

  test('sem API, entra no modo demonstração e registra só na memória', () async {
    final api = FaunaApi(client: MockClient((_) async => throw http.ClientException('offline')));
    final controller = OcorrenciasController(api: api);

    await controller.carregar();
    expect(controller.modoDemonstracao, isTrue);
    final antes = controller.todas.length;

    final resultado = await controller.registrar(NovaOcorrencia(
      ponto: const LatLng(-20.47, -54.62),
      situacao: 'Capivara no parque',
      tipo: TipoOcorrencia.avistamento,
    ));
    expect(resultado, ResultadoRegistro.salvoNaDemo);
    expect(controller.todas.length, antes + 1);
  });

  test('erro de validação da API é repassado, sem cair na demonstração', () async {
    final api = FaunaApi(
      client: MockClient((req) async => req.method == 'GET'
          ? http.Response('[]', 200)
          : http.Response('{"detail":"Latitude inválida"}', 422)),
    );
    final controller = OcorrenciasController(api: api);
    await controller.carregar();

    await expectLater(
      controller.registrar(NovaOcorrencia(
        ponto: const LatLng(85, 0),
        situacao: 'teste',
        tipo: TipoOcorrencia.ferido,
      )),
      throwsA(isA<ApiException>()),
    );
    expect(controller.modoDemonstracao, isFalse);
  });

  test('se só a foto falhar, o registro fica salvo uma vez, sem cair na demonstração', () async {
    final api = FaunaApi(
      client: MockClient((req) async {
        if (req.method == 'GET') return http.Response('[]', 200);
        if (req.url.path.endsWith('/foto')) throw http.ClientException('caiu no meio');
        return http.Response(
          '{"id":5,"latitude":-20.47,"longitude":-54.62,"situacao":"Arara","tipo":"avistamento",'
          '"status":"aberta","especie":null,"foto_url":null,"data_registro":"2026-10-30T10:00:00Z"}',
          201,
        );
      }),
    );
    final controller = OcorrenciasController(api: api);
    await controller.carregar();

    final resultado = await controller.registrar(NovaOcorrencia(
      ponto: const LatLng(-20.47, -54.62),
      situacao: 'Arara',
      tipo: TipoOcorrencia.avistamento,
      foto: Uint8List.fromList([1, 2, 3]),
      nomeFoto: 'a.jpg',
    ));
    expect(resultado, ResultadoRegistro.salvoSemFoto);
    expect(controller.modoDemonstracao, isFalse);
    expect(controller.todas.map((o) => o.id), [5]);
  });

  testWidgets('tela inicial mostra registros e as abas', (tester) async {
    final api = FaunaApi(
      client: MockClient((_) async => http.Response(
            '[{"id":1,"latitude":-20.47,"longitude":-54.62,"situacao":"Arara na praça","tipo":"avistamento",'
            '"status":"aberta","especie":"Arara-canindé","foto_url":null,"data_registro":"2026-10-22T09:15:00Z"}]',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          )),
    );
    await tester.pumpWidget(FaunaUrbanaApp(controller: OcorrenciasController(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Arara-canindé'), findsOneWidget);
    expect(find.text('Registros'), findsOneWidget);
    expect(find.text('Mapa'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
  });
}
