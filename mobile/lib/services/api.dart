import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config.dart';
import '../models/estatisticas.dart';
import '../models/ocorrencia.dart';

class ApiException implements Exception {
  ApiException(this.mensagem, {this.statusCode});
  final String mensagem;
  final int? statusCode;
  bool get naoAutorizado => statusCode == 401;
  @override
  String toString() => mensagem;
}

class FaunaApi {
  FaunaApi({http.Client? client, this.baseUrl = apiBaseUrl}) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  /// Tempo maior porque o servidor gratuito pode levar até 1 minuto para "acordar".
  static const _timeout = Duration(seconds: 90);

  /// Endereço da foto já com a permissão: a chave (de quem registrou) ou o token (da equipe).
  String? urlFoto(Ocorrencia o, {String? chave, String? token}) {
    final caminho = o.fotoUrl;
    if (caminho == null) return null;
    final uri = Uri.parse(caminho.startsWith('http') ? caminho : '$baseUrl$caminho');
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      'chave': ?chave,
      'token': ?token,
    }).toString();
  }

  // ---------- Quem registra ----------

  /// Envia a ocorrência e devolve o registro + a chave para acompanhar depois.
  Future<MeuRegistro> registrar(NovaOcorrencia nova) async {
    final resposta = await _client
        .post(
          Uri.parse('$baseUrl/ocorrencias'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(nova.toJson()),
        )
        .timeout(_timeout);
    _verificar(resposta);
    final json = _json(resposta) as Map<String, dynamic>;
    return MeuRegistro(ocorrencia: Ocorrencia.fromJson(json), chave: json['chave'] as String);
  }

  Future<Ocorrencia> enviarFoto(int id, String chave, Uint8List bytes, String nome) async {
    final requisicao = http.MultipartRequest('POST', Uri.parse('$baseUrl/ocorrencias/$id/foto'))
      ..fields['chave'] = chave
      ..files.add(http.MultipartFile.fromBytes('foto', bytes, filename: nome, contentType: _tipoImagem(nome)));
    final resposta = await http.Response.fromStream(await _client.send(requisicao).timeout(_timeout));
    _verificar(resposta);
    return Ocorrencia.fromJson(_json(resposta) as Map<String, dynamic>);
  }

  /// Situação atual dos registros feitos neste aparelho.
  Future<List<Ocorrencia>> acompanhar(List<MeuRegistro> meus) async {
    if (meus.isEmpty) return [];
    final resposta = await _client
        .post(
          Uri.parse('$baseUrl/ocorrencias/acompanhar'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'itens': [for (final m in meus) {'id': m.ocorrencia.id, 'chave': m.chave}],
          }),
        )
        .timeout(_timeout);
    _verificar(resposta);
    return [for (final item in _json(resposta) as List) Ocorrencia.fromJson(Map<String, dynamic>.from(item as Map))];
  }

  // ---------- Painel administrativo ----------

  Map<String, String> _auth(String token) => {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};

  Future<String> login(String usuario, String senha) async {
    final resposta = await _client
        .post(
          Uri.parse('$baseUrl/admin/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'usuario': usuario, 'senha': senha}),
        )
        .timeout(_timeout);
    _verificar(resposta);
    return (_json(resposta) as Map)['token'] as String;
  }

  Future<String> quemSou(String token) async {
    final resposta = await _client.get(Uri.parse('$baseUrl/admin/me'), headers: _auth(token)).timeout(_timeout);
    _verificar(resposta);
    return (_json(resposta) as Map)['usuario'] as String;
  }

  Future<List<Ocorrencia>> listar(String token) async {
    final resposta = await _client.get(Uri.parse('$baseUrl/ocorrencias'), headers: _auth(token)).timeout(_timeout);
    _verificar(resposta);
    return [for (final item in _json(resposta) as List) Ocorrencia.fromJson(Map<String, dynamic>.from(item as Map))];
  }

  Future<Estatisticas> estatisticas(String token) async {
    final resposta =
        await _client.get(Uri.parse('$baseUrl/admin/estatisticas'), headers: _auth(token)).timeout(_timeout);
    _verificar(resposta);
    return Estatisticas.fromJson(_json(resposta) as Map<String, dynamic>);
  }

  Future<Ocorrencia> atualizarStatus(int id, StatusOcorrencia status, String token) async {
    final resposta = await _client
        .patch(
          Uri.parse('$baseUrl/ocorrencias/$id/status'),
          headers: _auth(token),
          body: jsonEncode({'status': status.valorApi}),
        )
        .timeout(_timeout);
    _verificar(resposta);
    return Ocorrencia.fromJson(_json(resposta) as Map<String, dynamic>);
  }

  Future<void> apagar(int id, String token) async {
    final resposta = await _client.delete(Uri.parse('$baseUrl/ocorrencias/$id'), headers: _auth(token)).timeout(_timeout);
    _verificar(resposta);
  }

  // ---------- Utilitários ----------

  dynamic _json(http.Response resposta) => jsonDecode(utf8.decode(resposta.bodyBytes));

  void _verificar(http.Response resposta) {
    if (resposta.statusCode >= 200 && resposta.statusCode < 300) return;
    String mensagem = 'O servidor respondeu com erro ${resposta.statusCode}.';
    try {
      final detalhe = (_json(resposta) as Map)['detail'];
      if (detalhe is String) mensagem = detalhe;
      if (detalhe is List && detalhe.isNotEmpty) mensagem = 'Dados inválidos: ${(detalhe.first as Map)['msg']}';
    } catch (_) {}
    throw ApiException(mensagem, statusCode: resposta.statusCode);
  }

  static MediaType _tipoImagem(String nome) {
    final n = nome.toLowerCase();
    if (n.endsWith('.png')) return MediaType('image', 'png');
    if (n.endsWith('.webp')) return MediaType('image', 'webp');
    return MediaType('image', 'jpeg');
  }
}
