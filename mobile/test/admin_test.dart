import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/models/ocorrencia.dart';
import 'package:mobile/services/admin_controller.dart';
import 'package:mobile/services/api.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _ocorrencia =
    '{"id":1,"latitude":-20.47,"longitude":-54.62,"situacao":"Quati ferido","tipo":"ferido",'
    '"status":"aberta","especie":"Quati","foto_url":null,"data_registro":"2026-10-30T10:00:00Z"}';
const _estatisticas =
    '{"total":1,"por_tipo":{"ferido":1},"por_status":{"aberta":1},"urgentes_abertas":1,"com_foto":0,'
    '"por_dia":[{"dia":"2026-10-30","total":1}],"top_especies":[{"especie":"Quati","total":1}]}';

http.Response _json(String corpo, int status) =>
    http.Response.bytes(utf8.encode(corpo), status, headers: {'content-type': 'application/json; charset=utf-8'});

/// API falsa: aceita só a senha "certa". Com [tokenExpira], o token deixa de valer depois do login.
MockClient _api({bool tokenExpira = false}) => MockClient((req) async {
      final auth = req.headers['Authorization'];
      final path = req.url.path;
      if (path == '/admin/login') {
        return req.body.contains('"certa"')
            ? _json('{"token":"tok","usuario":"DAC@FAUNA"}', 200)
            : _json('{"detail":"Usuário ou senha incorretos."}', 401);
      }
      if (auth != 'Bearer tok') return _json('{"detail":"Faça login"}', 401);
      if (path == '/admin/me') return _json('{"usuario":"DAC@FAUNA"}', 200);
      if (tokenExpira) return _json('{"detail":"Faça login"}', 401);
      if (path == '/admin/estatisticas') return _json(_estatisticas, 200);
      if (path == '/ocorrencias' && req.method == 'GET') return _json('[$_ocorrencia]', 200);
      if (path.endsWith('/status')) return _json(_ocorrencia.replaceFirst('"aberta"', '"resolvida"'), 200);
      if (req.method == 'DELETE') return http.Response('', 204);
      return _json('{}', 404);
    });

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('login certo carrega painel e lembra a sessão', () async {
    final c = AdminController(api: FaunaApi(client: _api()), intervaloAtualizacao: const Duration(hours: 1));
    await c.iniciar();
    expect(c.logado, isFalse);

    await c.entrar('dac@fauna', 'certa');
    expect(c.logado, isTrue);
    expect(c.usuario, 'DAC@FAUNA');
    expect(c.estatisticas!.urgentesAbertas, 1);
    expect(c.estatisticas!.topEspecies.first.$1, 'Quati');
    expect(c.urgentesAbertas.map((o) => o.id), [1]);
    expect(c.urlFoto(c.filtradas.single), isNull, reason: 'sem foto, sem endereço');
    c.dispose();

    final outro = AdminController(api: FaunaApi(client: _api()), intervaloAtualizacao: const Duration(hours: 1));
    await outro.iniciar();
    expect(outro.logado, isTrue, reason: 'o token salvo deve ser reaproveitado');
  });

  test('senha errada mostra a mensagem da API', () async {
    final c = AdminController(api: FaunaApi(client: _api()), intervaloAtualizacao: const Duration(hours: 1));
    await c.entrar('DAC@FAUNA', 'errada');
    expect(c.logado, isFalse);
    expect(c.erro, 'Usuário ou senha incorretos.');
  });

  test('muda status e apaga, atualizando a lista', () async {
    final c = AdminController(api: FaunaApi(client: _api()), intervaloAtualizacao: const Duration(hours: 1));
    await c.entrar('DAC@FAUNA', 'certa');
    final o = c.filtradas.single;

    expect(await c.mudarStatus(o, StatusOcorrencia.resolvida), isNull);
    expect(c.filtradas.single.status, StatusOcorrencia.resolvida);

    expect(await c.apagar(c.filtradas.single), isNull);
    expect(c.filtradas, isEmpty);
  });

  test('sessão expirada volta para o login', () async {
    final c = AdminController(api: FaunaApi(client: _api(tokenExpira: true)), intervaloAtualizacao: const Duration(hours: 1));
    await c.entrar('DAC@FAUNA', 'certa');
    expect(c.logado, isFalse);
    expect(c.erro, contains('expirou'));
  });
}
