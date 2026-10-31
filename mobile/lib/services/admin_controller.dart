import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/estatisticas.dart';
import '../models/ocorrencia.dart';
import 'api.dart';
import 'ocorrencias_controller.dart';

/// Estado do painel administrativo: login, estatísticas e ações sobre as ocorrências.
class AdminController extends ChangeNotifier {
  AdminController({FaunaApi? api, OcorrenciasController? ocorrencias})
      : api = api ?? FaunaApi(),
        ocorrencias = ocorrencias ?? OcorrenciasController(api: api);

  static const _chaveToken = 'fauna_admin_token';

  final FaunaApi api;
  final OcorrenciasController ocorrencias;

  String? _token;
  String? usuario;
  Estatisticas? estatisticas;
  bool iniciando = true;
  bool carregando = false;
  String? erro;

  /// Filtros da lista do painel.
  String busca = '';
  StatusOcorrencia? filtroStatus;

  bool get logado => _token != null;

  List<Ocorrencia> get filtradas {
    final termo = busca.trim().toLowerCase();
    return ocorrencias.visiveis.where((o) {
      if (o.demo) return false;
      if (filtroStatus != null && o.status != filtroStatus) return false;
      if (termo.isEmpty) return true;
      return o.situacao.toLowerCase().contains(termo) ||
          (o.especie ?? '').toLowerCase().contains(termo) ||
          o.codigo == termo.replaceAll('#', '');
    }).toList();
  }

  /// Recupera o login salvo no aparelho, se ainda for válido.
  Future<void> iniciar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final salvo = prefs.getString(_chaveToken);
      if (salvo != null) {
        usuario = await api.quemSou(salvo);
        _token = salvo;
        await carregar();
      }
    } on ApiException catch (e) {
      if (e.naoAutorizado) await _esquecerToken();
    } catch (_) {
      // Sem conexão: mostra a tela de login, que explica o erro ao tentar entrar.
    }
    iniciando = false;
    notifyListeners();
  }

  Future<void> entrar(String usuarioDigitado, String senha) async {
    erro = null;
    carregando = true;
    notifyListeners();
    try {
      final token = await api.login(usuarioDigitado.trim(), senha);
      // Só considera logado depois que o servidor confirmar o token.
      usuario = await api.quemSou(token);
      _token = token;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_chaveToken, token);
      } catch (_) {}
      await carregar();
    } on ApiException catch (e) {
      erro = e.mensagem;
    } catch (_) {
      erro = 'Não foi possível conectar ao servidor. Verifique a internet e tente de novo.';
    }
    carregando = false;
    notifyListeners();
  }

  Future<void> sair() async {
    await _esquecerToken();
    usuario = null;
    estatisticas = null;
    notifyListeners();
  }

  Future<void> carregar() async {
    final token = _token;
    if (token == null) return;
    carregando = true;
    erro = null;
    notifyListeners();
    try {
      final resultados = await Future.wait([api.estatisticas(token), ocorrencias.carregar()]);
      estatisticas = resultados.first as Estatisticas;
    } on ApiException catch (e) {
      if (e.naoAutorizado) return _sessaoExpirada();
      erro = e.mensagem;
    } catch (_) {
      erro = 'Não foi possível atualizar os dados agora.';
    }
    carregando = false;
    notifyListeners();
  }

  void filtrarStatus(StatusOcorrencia? status) {
    filtroStatus = filtroStatus == status ? null : status;
    notifyListeners();
  }

  void buscar(String texto) {
    busca = texto;
    notifyListeners();
  }

  /// Devolve uma mensagem de erro, ou null se deu certo.
  Future<String?> mudarStatus(Ocorrencia o, StatusOcorrencia status) =>
      _executar(() async => ocorrencias.substituir(await api.atualizarStatus(o.id, status, _token!)));

  Future<String?> apagar(Ocorrencia o) => _executar(() async {
        await api.apagar(o.id, _token!);
        ocorrencias.remover(o);
      });

  Future<String?> _executar(Future<void> Function() acao) async {
    if (_token == null) return 'Faça login novamente.';
    try {
      await acao();
      _atualizarEstatisticasEmSegundoPlano();
      return null;
    } on ApiException catch (e) {
      if (e.naoAutorizado) {
        await _sessaoExpirada();
        return 'Sua sessão expirou. Entre novamente.';
      }
      return e.mensagem;
    } catch (_) {
      return 'Sem conexão com o servidor. Tente de novo.';
    }
  }

  Future<void> _atualizarEstatisticasEmSegundoPlano() async {
    try {
      estatisticas = await api.estatisticas(_token!);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _sessaoExpirada() async {
    await _esquecerToken();
    erro = 'Sua sessão expirou. Entre novamente.';
    carregando = false;
    notifyListeners();
  }

  Future<void> _esquecerToken() async {
    _token = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_chaveToken);
    } catch (_) {}
  }
}
