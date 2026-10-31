import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/estatisticas.dart';
import '../models/ocorrencia.dart';
import 'api.dart';
import 'ocorrencias_controller.dart';

/// Estado do painel administrativo: login, ocorrências recebidas, estatísticas e ações.
class AdminController extends ChangeNotifier {
  AdminController({FaunaApi? api, this.intervaloAtualizacao = const Duration(seconds: 60)})
      : api = api ?? FaunaApi() {
    ocorrencias.urlFoto = (o) => this.api.urlFoto(o, token: _token);
  }

  static const _chaveToken = 'fauna_admin_token';

  final FaunaApi api;
  final OcorrenciasController ocorrencias = OcorrenciasController();
  final Duration intervaloAtualizacao;

  String? _token;
  String? usuario;
  Estatisticas? estatisticas;
  bool iniciando = true;
  bool carregando = false;
  String? erro;
  DateTime? ultimaAtualizacao;

  /// Ocorrências que chegaram desde a última atualização (para avisar a equipe).
  List<Ocorrencia> novas = [];
  final Set<int> _conhecidas = {};
  Timer? _timer;

  /// Filtros da lista do painel.
  String busca = '';
  StatusOcorrencia? filtroStatus;

  bool get logado => _token != null;

  /// Casos que pedem ação rápida e ainda não foram atendidos, mais recentes primeiro.
  List<Ocorrencia> get urgentesAbertas => ocorrencias.todas
      .where((o) => o.tipo.urgente && o.status == StatusOcorrencia.aberta)
      .toList();

  List<Ocorrencia> get filtradas {
    final termo = busca.trim().toLowerCase();
    return ocorrencias.visiveis.where((o) {
      if (filtroStatus != null && o.status != filtroStatus) return false;
      if (termo.isEmpty) return true;
      return o.situacao.toLowerCase().contains(termo) ||
          (o.especie ?? '').toLowerCase().contains(termo) ||
          o.codigo == termo.replaceAll('#', '');
    }).toList();
  }

  String? urlFoto(Ocorrencia o) => api.urlFoto(o, token: _token);

  /// Recupera o login salvo no aparelho, se ainda for válido.
  Future<void> iniciar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final salvo = prefs.getString(_chaveToken);
      if (salvo != null) {
        usuario = await api.quemSou(salvo);
        _token = salvo;
        await carregar();
        _iniciarAtualizacaoAutomatica();
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
      _iniciarAtualizacaoAutomatica();
    } on ApiException catch (e) {
      erro = e.mensagem;
    } catch (_) {
      erro = 'Não foi possível conectar ao servidor. Verifique a internet e tente de novo.';
    }
    carregando = false;
    notifyListeners();
  }

  Future<void> sair() async {
    _timer?.cancel();
    await _esquecerToken();
    usuario = null;
    estatisticas = null;
    ocorrencias.definir([]);
    _conhecidas.clear();
    notifyListeners();
  }

  /// Busca ocorrências e estatísticas. Em [silencioso], não mostra carregamento (atualização automática).
  Future<void> carregar({bool silencioso = false}) async {
    final token = _token;
    if (token == null) return;
    if (!silencioso) {
      carregando = true;
      erro = null;
      notifyListeners();
    }
    try {
      final (lista, est) = await (api.listar(token), api.estatisticas(token)).wait;
      final primeiraVez = _conhecidas.isEmpty && ultimaAtualizacao == null;
      novas = primeiraVez ? [] : lista.where((o) => !_conhecidas.contains(o.id)).toList();
      _conhecidas
        ..clear()
        ..addAll(lista.map((o) => o.id));
      ocorrencias.definir(lista);
      estatisticas = est;
      ultimaAtualizacao = DateTime.now();
      erro = null;
    } on ParallelWaitError catch (e) {
      final primeiro = (e.errors as (AsyncError?, AsyncError?)).$1?.error ?? e.errors.$2?.error;
      if (primeiro is ApiException && primeiro.naoAutorizado) return _sessaoExpirada();
      if (!silencioso) erro = primeiro is ApiException ? primeiro.mensagem : 'Não foi possível atualizar os dados agora.';
    } catch (_) {
      if (!silencioso) erro = 'Não foi possível atualizar os dados agora.';
    }
    carregando = false;
    notifyListeners();
  }

  /// A tela chama depois de mostrar o aviso das novas ocorrências.
  void avisoDeNovasMostrado() => novas = [];

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
        _conhecidas.remove(o.id);
      });

  Future<String?> _executar(Future<void> Function() acao) async {
    if (_token == null) return 'Faça login novamente.';
    try {
      await acao();
      _atualizarEstatisticasEmSegundoPlano();
      notifyListeners();
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

  void _iniciarAtualizacaoAutomatica() {
    _timer?.cancel();
    _timer = Timer.periodic(intervaloAtualizacao, (_) => carregar(silencioso: true));
  }

  Future<void> _atualizarEstatisticasEmSegundoPlano() async {
    try {
      estatisticas = await api.estatisticas(_token!);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _sessaoExpirada() async {
    _timer?.cancel();
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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
