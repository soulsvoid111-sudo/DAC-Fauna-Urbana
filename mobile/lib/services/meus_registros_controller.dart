import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ocorrencia.dart';
import 'api.dart';
import 'notificacao.dart';

enum ResultadoEnvio { enviado, enviadoSemFoto }

/// Um registro cuja situação mudou desde a última vez que o app olhou.
class MudancaStatus {
  MudancaStatus(this.registro, this.anterior);
  final MeuRegistro registro;
  final StatusOcorrencia anterior;
  StatusOcorrencia get atual => registro.ocorrencia.status;

  String get titulo => switch (atual) {
        StatusOcorrencia.resolvida => 'Sua ocorrência foi resolvida!',
        StatusOcorrencia.emAnalise => 'A equipe está cuidando da sua ocorrência',
        StatusOcorrencia.descartada => 'Sua ocorrência foi analisada',
        StatusOcorrencia.aberta => 'Sua ocorrência foi reaberta',
      };

  String get mensagem {
    final n = '#${registro.ocorrencia.codigo}';
    return switch (atual) {
      StatusOcorrencia.resolvida =>
        'A ocorrência $n (${registro.ocorrencia.titulo}) foi resolvida pela equipe SOFUR. '
            'Obrigado por contribuir com a proteção da fauna urbana! 💚',
      StatusOcorrencia.emAnalise => 'A ocorrência $n está em análise e os responsáveis estão sendo acionados.',
      StatusOcorrencia.descartada => 'A equipe analisou a ocorrência $n e não foi necessária uma ação. Obrigado por avisar!',
      StatusOcorrencia.aberta => 'A ocorrência $n voltou para a fila de atendimento.',
    };
  }
}

/// Registros feitos NESTE aparelho. Ficam guardados só no celular de quem registrou;
/// a situação (status) é atualizada pela equipe e consultada com a chave de cada registro.
class MeusRegistrosController extends ChangeNotifier {
  MeusRegistrosController({FaunaApi? api}) : api = api ?? FaunaApi();

  static const _chave = 'sofur_meus_registros';

  final FaunaApi api;
  List<MeuRegistro> registros = [];
  bool carregando = false;

  /// Mudanças de situação ainda não mostradas na tela.
  List<MudancaStatus> mudancas = [];
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
      final novasMudancas = [
        for (final r in registros)
          if (atuais[r.ocorrencia.id] != null && atuais[r.ocorrencia.id]!.status != r.ocorrencia.status)
            MudancaStatus(MeuRegistro(ocorrencia: atuais[r.ocorrencia.id]!, chave: r.chave), r.ocorrencia.status),
      ];
      mudancas = [...mudancas, ...novasMudancas];
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
    if (Notificacao.permitida) unawaited(ativarAvisos(registro, pedirPermissao: false));
    return (registro, resultado);
  }

  /// Inscreve este celular para receber a notificação do servidor sobre [registro].
  /// Devolve true se ficou tudo certo (permissão + inscrição + servidor).
  Future<bool> ativarAvisos(MeuRegistro registro, {bool pedirPermissao = true}) async {
    if (pedirPermissao && !Notificacao.permitida && !await Notificacao.pedirPermissao()) return false;
    if (!Notificacao.permitida) return false;
    try {
      final inscricao = await Notificacao.inscrever(await api.chavePublicaPush());
      if (inscricao == null) return false;
      await api.pedirAviso(registro, inscricao);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// A tela chama depois de mostrar os avisos.
  List<MudancaStatus> consumirMudancas() {
    final lista = mudancas;
    mudancas = [];
    return lista;
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
