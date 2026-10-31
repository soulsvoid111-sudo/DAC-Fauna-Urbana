import 'package:flutter/foundation.dart';

import '../data/demo.dart';
import '../models/ocorrencia.dart';
import 'api.dart';

enum ResultadoRegistro { salvoNoBanco, salvoSemFoto, salvoNaDemo }

/// Guarda as ocorrências carregadas e decide quando usar o modo demonstração.
class OcorrenciasController extends ChangeNotifier {
  OcorrenciasController({FaunaApi? api}) : api = api ?? FaunaApi();

  final FaunaApi api;
  List<Ocorrencia> _todas = [];
  bool carregando = false;

  /// Verdadeiro enquanto espera o servidor gratuito sair do modo "dormindo".
  bool acordandoServidor = false;
  bool modoDemonstracao = false;
  String? aviso;
  TipoOcorrencia? filtro;
  int _proximoIdDemo = 100;

  List<Ocorrencia> get todas => _todas;
  List<Ocorrencia> get visiveis => filtro == null ? _todas : _todas.where((o) => o.tipo == filtro).toList();
  int contar(TipoOcorrencia tipo) => _todas.where((o) => o.tipo == tipo).length;
  int get urgentesAbertas =>
      _todas.where((o) => o.tipo.urgente && o.status == StatusOcorrencia.aberta).length;

  void filtrar(TipoOcorrencia? tipo) {
    filtro = filtro == tipo ? null : tipo;
    notifyListeners();
  }

  Future<void> carregar() async {
    carregando = true;
    notifyListeners();
    try {
      try {
        _todas = await api.listar(timeout: const Duration(seconds: 10));
      } on ApiException {
        rethrow;
      } catch (_) {
        // Servidor provavelmente dormindo: a hospedagem segura a requisição até ele acordar.
        acordandoServidor = true;
        notifyListeners();
        _todas = await api.listar(timeout: const Duration(seconds: 90));
      }
      modoDemonstracao = false;
      aviso = null;
    } on ApiException catch (e) {
      _entrarNaDemo(e.mensagem);
    } catch (_) {
      _entrarNaDemo('Não foi possível conectar ao servidor. Os registros abaixo são fictícios.');
    }
    acordandoServidor = false;
    carregando = false;
    notifyListeners();
  }

  /// Erros de validação da API são repassados para o formulário mostrar.
  /// Falta de conexão faz o registro ficar só na demonstração, avisando a pessoa.
  Future<ResultadoRegistro> registrar(NovaOcorrencia nova) async {
    if (!modoDemonstracao) {
      try {
        var criada = await api.criar(nova);
        var resultado = ResultadoRegistro.salvoNoBanco;
        if (nova.foto != null) {
          // O registro já foi salvo; se só a foto falhar, não perde nem duplica o registro.
          try {
            criada = await api.enviarFoto(criada.id, nova.foto!, nova.nomeFoto ?? 'foto.jpg');
          } catch (_) {
            resultado = ResultadoRegistro.salvoSemFoto;
          }
        }
        _todas = [criada, ..._todas];
        notifyListeners();
        return resultado;
      } on ApiException {
        rethrow;
      } catch (_) {
        _entrarNaDemo('A API ficou indisponível. O último registro ficou apenas neste aparelho.');
      }
    }
    _todas = [
      Ocorrencia(
        id: _proximoIdDemo++,
        demo: true,
        latitude: nova.ponto.latitude,
        longitude: nova.ponto.longitude,
        situacao: nova.situacao,
        tipo: nova.tipo,
        especie: nova.especie,
        status: StatusOcorrencia.aberta,
        fotoBytes: nova.foto,
        dataRegistro: DateTime.now(),
      ),
      ..._todas,
    ];
    notifyListeners();
    return ResultadoRegistro.salvoNaDemo;
  }

  /// Usados pelo painel admin depois de alterar ou apagar uma ocorrência.
  void substituir(Ocorrencia nova) {
    _todas = [for (final o in _todas) o.id == nova.id && !o.demo ? nova : o];
    notifyListeners();
  }

  void remover(Ocorrencia ocorrencia) {
    _todas = _todas.where((o) => !(o.id == ocorrencia.id && o.demo == ocorrencia.demo)).toList();
    notifyListeners();
  }

  void _entrarNaDemo(String mensagem) {
    if (!modoDemonstracao) _todas = ocorrenciasDemo();
    modoDemonstracao = true;
    aviso = mensagem;
  }
}
