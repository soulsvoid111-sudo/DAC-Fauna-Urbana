import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ocorrencia.dart';
import 'api.dart';

enum ResultadoEnvio { enviado, enviadoSemFoto }

/// Registros feitos NESTE aparelho. Ficam guardados só no celular de quem registrou;
/// a situação (status) é atualizada pela equipe e consultada com a chave de cada registro.
class MeusRegistrosController extends ChangeNotifier {
  MeusRegistrosController({FaunaApi? api}) : api = api ?? FaunaApi();

  static const _chave = 'sofur_meus_registros';

  final FaunaApi api;
  List<MeuRegistro> registros = [];
  bool carregando = false;
  bool semConexao = false;

  int get emAberto => registros.where((r) => r.ocorrencia.status == StatusOcorrencia.aberta).length;

  Future<void> carregar() async {
    carregando = true;
    notifyListeners();
    registros = await _lerDoAparelho();
    notifyListeners();
    await atualizarSituacao();
    carregando = false;
    notifyListeners();
  }

  /// Busca na API o status atual de cada registro deste aparelho.
  Future<void> atualizarSituacao() async {
    if (registros.isEmpty) {
      semConexao = false;
      return;
    }
    try {
      final atuais = {for (final o in await api.acompanhar(registros)) o.id: o};
      registros = [
        for (final r in registros) MeuRegistro(ocorrencia: atuais[r.ocorrencia.id] ?? r.ocorrencia, chave: r.chave),
      ];
      semConexao = false;
      await _gravarNoAparelho();
    } catch (_) {
      semConexao = true; // mostra a última situação conhecida
    }
    notifyListeners();
  }

  /// Envia a ocorrência à equipe. Se a conexão falhar, lança o erro e o formulário continua preenchido.
  Future<(MeuRegistro, ResultadoEnvio)> enviar(NovaOcorrencia nova) async {
    var registro = await api.registrar(nova);
    var resultado = ResultadoEnvio.enviado;
    if (nova.foto != null) {
      try {
        final comFoto = await api.enviarFoto(
          registro.ocorrencia.id,
          registro.chave,
          nova.foto!,
          nova.nomeFoto ?? 'foto.jpg',
        );
        registro = MeuRegistro(ocorrencia: comFoto, chave: registro.chave);
      } catch (_) {
        resultado = ResultadoEnvio.enviadoSemFoto; // o registro já foi recebido; só a foto não foi
      }
    }
    registros = [registro, ...registros];
    await _gravarNoAparelho();
    notifyListeners();
    return (registro, resultado);
  }

  /// Tira o registro da lista deste aparelho (não apaga da equipe).
  Future<void> esquecer(MeuRegistro registro) async {
    registros = registros.where((r) => r.ocorrencia.id != registro.ocorrencia.id).toList();
    await _gravarNoAparelho();
    notifyListeners();
  }

  String? urlFoto(MeuRegistro r) => api.urlFoto(r.ocorrencia, chave: r.chave);

  Future<List<MeuRegistro>> _lerDoAparelho() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final texto = prefs.getString(_chave);
      if (texto == null) return [];
      return [
        for (final item in jsonDecode(texto) as List) MeuRegistro.fromJson(Map<String, dynamic>.from(item as Map)),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> _gravarNoAparelho() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chave, jsonEncode([for (final r in registros) r.toJson()]));
    } catch (_) {}
  }
}
