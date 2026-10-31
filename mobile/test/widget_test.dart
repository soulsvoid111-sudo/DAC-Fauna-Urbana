import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile/main.dart';
import 'package:mobile/models/ocorrencia.dart';
import 'package:mobile/services/api.dart';
import 'package:mobile/services/meus_registros_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object corpo, int status) => http.Response.bytes(
      utf8.encode(jsonEncode(corpo)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> _ocorrencia(int id, {String status = 'aberta', String? foto}) => {
      'id': id,
      'latitude': -20.47,
      'longitude': -54.62,
      'situacao': 'Quati ferido no estacionamento',
      'tipo': 'ferido',
      'status': status,
      'especie': 'Quati',
      'foto_url': foto,
      'data_registro': '2026-10-30T10:00:00Z',
    };

/// API falsa de quem registra: cria com chave, aceita foto e responde o acompanhamento.
MockClient _apiCidadao({bool fotoFalha = false, String statusAtual = 'aberta'}) => MockClient((req) async {
      final caminho = req.url.path;
      if (caminho == '/ocorrencias' && req.method == 'POST') {
        return _json({..._ocorrencia(7), 'chave': 'chave-secreta-do-celular'}, 201);
      }
      if (caminho.endsWith('/foto')) {
        if (fotoFalha) throw http.ClientException('caiu no meio');
        return _json(_ocorrencia(7, foto: '/ocorrencias/7/foto?v=1'), 200);
      }
      if (caminho == '/ocorrencias/acompanhar') {
        final pedidos = (jsonDecode(req.body) as Map)['itens'] as List;
        final certos = pedidos.where((p) => p['chave'] == 'chave-secreta-do-celular');
        return _json([for (final p in certos) _ocorrencia(p['id'] as int, status: statusAtual)], 200);
      }
      return _json({'detail': 'não esperado'}, 404);
    });

NovaOcorrencia _nova({Uint8List? foto}) => NovaOcorrencia(
      ponto: const LatLng(-20.47, -54.62),
      situacao: 'Quati ferido no estacionamento',
      tipo: TipoOcorrencia.ferido,
      foto: foto,
      nomeFoto: foto == null ? null : 'a.jpg',
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('converte o JSON da API e volta para JSON sem perder nada', () {
    final o = Ocorrencia.fromJson(_ocorrencia(3, status: 'em_analise'));
    expect(o.tipo, TipoOcorrencia.ferido);
    expect(o.status, StatusOcorrencia.emAnalise);
    expect(Ocorrencia.fromJson(o.toJson()).situacao, o.situacao);
  });

  test('envia, guarda no aparelho com a chave e mostra só os meus registros', () async {
    final c = MeusRegistrosController(api: FaunaApi(client: _apiCidadao()));
    await c.carregar();
    expect(c.registros, isEmpty);

    final (registro, resultado) = await c.enviar(_nova(foto: Uint8List.fromList([1, 2, 3])));
    expect(resultado, ResultadoEnvio.enviado);
    expect(registro.chave, 'chave-secreta-do-celular');
    expect(c.urlFoto(registro), contains('chave=chave-secreta-do-celular'));

    // Abrindo o app de novo, o registro continua lá (guardado no aparelho).
    final reaberto = MeusRegistrosController(api: FaunaApi(client: _apiCidadao(statusAtual: 'resolvida')));
    await reaberto.carregar();
    expect(reaberto.registros.map((r) => r.ocorrencia.id), [7]);
    expect(reaberto.registros.single.ocorrencia.status, StatusOcorrencia.resolvida,
        reason: 'a situação atualizada pela equipe aparece para quem registrou');
  });

  test('se só a foto falhar, o registro é enviado uma vez e avisa', () async {
    final c = MeusRegistrosController(api: FaunaApi(client: _apiCidadao(fotoFalha: true)));
    final (_, resultado) = await c.enviar(_nova(foto: Uint8List.fromList([1])));
    expect(resultado, ResultadoEnvio.enviadoSemFoto);
    expect(c.registros, hasLength(1));
  });

  test('sem internet, o envio falha e nada é salvo como enviado', () async {
    final c = MeusRegistrosController(
      api: FaunaApi(client: MockClient((_) async => throw http.ClientException('offline'))),
    );
    await expectLater(c.enviar(_nova()), throwsA(isA<http.ClientException>()));
    expect(c.registros, isEmpty);
  });

  test('erro de validação da API chega com a mensagem', () async {
    final c = MeusRegistrosController(
      api: FaunaApi(client: MockClient((_) async => _json({'detail': 'Latitude inválida'}, 422))),
    );
    await expectLater(
      c.enviar(_nova()),
      throwsA(isA<ApiException>().having((e) => e.mensagem, 'mensagem', 'Latitude inválida')),
    );
  });

  testWidgets('tela inicial pública: botão de registrar e "Meus registros", sem lista de outras pessoas',
      (tester) async {
    await tester.pumpWidget(SofurApp(controller: MeusRegistrosController(api: FaunaApi(client: _apiCidadao()))));
    await tester.pumpAndSettle();

    expect(find.text('Registrar ocorrência'), findsWidgets);
    expect(find.text('Meus registros'), findsOneWidget);
    expect(find.text('Você ainda não fez registros'), findsOneWidget);
    expect(find.text('Mapa'), findsNothing);
    expect(find.byIcon(Icons.add_a_photo_outlined), findsWidgets);
  });
}
