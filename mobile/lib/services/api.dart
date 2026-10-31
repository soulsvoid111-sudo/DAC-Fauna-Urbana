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
  static const _timeout = Duration(seconds: 20);

  String urlFoto(String caminho) => caminho.startsWith('http') ? caminho : '$baseUrl$caminho';

  /// [timeout] maior serve para esperar o servidor gratuito "acordar".
  Future<List<Ocorrencia>> listar({Duration timeout = _timeout}) async {
    final resposta = await _client.get(Uri.parse('$baseUrl/ocorrencias')).timeout(timeout);
    _verificar(resposta);
    final lista = jsonDecode(utf8.decode(resposta.bodyBytes)) as List<dynamic>;
    return lista.map((item) => Ocorrencia.fromJson(Map<String, dynamic>.from(item as Map))).toList();
  }

  Future<Ocorrencia> criar(NovaOcorrencia nova) async {
    final resposta = await _client
        .post(
          Uri.parse('$baseUrl/ocorrencias'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(nova.toJson()),
        )
        .timeout(_timeout);
    _verificar(resposta);
    return _ler(resposta);
  }

  Future<Ocorrencia> enviarFoto(int id, Uint8List bytes, String nome) async {
    final requisicao = http.MultipartRequest('POST', Uri.parse('$baseUrl/ocorrencias/$id/foto'))
      ..files.add(http.MultipartFile.fromBytes('foto', bytes, filename: nome, contentType: _tipoImagem(nome)));
    final resposta = await http.Response.fromStream(await _client.send(requisicao).timeout(const Duration(seconds: 60)));
    _verificar(resposta);
    return _ler(resposta);
  }

  // ---------- Painel administrativo ----------

  Map<String, String> _auth(String token) => {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};

  /// Devolve o token de acesso do admin.
  Future<String> login(String usuario, String senha) async {
    final resposta = await _client
        .post(
          Uri.parse('$baseUrl/admin/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'usuario': usuario, 'senha': senha}),
        )
        .timeout(const Duration(seconds: 90));
    _verificar(resposta);
    return (jsonDecode(utf8.decode(resposta.bodyBytes)) as Map)['token'] as String;
  }

  Future<String> quemSou(String token) async {
    final resposta = await _client.get(Uri.parse('$baseUrl/admin/me'), headers: _auth(token)).timeout(const Duration(seconds: 90));
    _verificar(resposta);
    return (jsonDecode(utf8.decode(resposta.bodyBytes)) as Map)['usuario'] as String;
  }

  Future<Estatisticas> estatisticas(String token) async {
    final resposta =
        await _client.get(Uri.parse('$baseUrl/admin/estatisticas'), headers: _auth(token)).timeout(_timeout);
    _verificar(resposta);
    return Estatisticas.fromJson(jsonDecode(utf8.decode(resposta.bodyBytes)) as Map<String, dynamic>);
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
    return _ler(resposta);
  }

  Future<void> apagar(int id, String token) async {
    final resposta = await _client.delete(Uri.parse('$baseUrl/ocorrencias/$id'), headers: _auth(token)).timeout(_timeout);
    _verificar(resposta);
  }

  Ocorrencia _ler(http.Response resposta) =>
      Ocorrencia.fromJson(jsonDecode(utf8.decode(resposta.bodyBytes)) as Map<String, dynamic>);

  void _verificar(http.Response resposta) {
    if (resposta.statusCode >= 200 && resposta.statusCode < 300) return;
    String mensagem = 'A API respondeu com erro ${resposta.statusCode}.';
    try {
      final detalhe = (jsonDecode(utf8.decode(resposta.bodyBytes)) as Map)['detail'];
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
