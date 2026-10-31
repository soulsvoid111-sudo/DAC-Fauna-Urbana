import 'package:flutter/foundation.dart';

import '../data/demo.dart';
import '../models/ocorrencia.dart';
import 'api.dart';

enum ResultadoRegistro { salvoNoBanco, salvoNaDemo }

/// Guarda as ocorrências carregadas e decide quando usar o modo demonstração.
class OcorrenciasController extends ChangeNotifier {
  OcorrenciasController({FaunaApi? api}) : api = api ?? FaunaApi();

  final FaunaApi api;
  List<Ocorrencia> _todas = [];
  bool carregando = false;
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
      _todas = await api.listar();
      modoDemonstracao = false;
      aviso = null;
    } on ApiException catch (e) {
      _entrarNaDemo(e.mensagem);
    } catch (_) {
      _entrarNaDemo('Não foi possível conectar à API. Os registros abaixo são fictícios.');
    }
    carregando = false;
    notifyListeners();
  }

  /// Erros de validação da API são repassados para o formulário mostrar.
  /// Falta de conexão faz o registro ficar só na demonstração, avisando a pessoa.
  Future<ResultadoRegistro> registrar(NovaOcorrencia nova) async {
    if (!modoDemonstracao) {
      try {
        final criada = await api.criar(nova);
        _todas = [criada, ..._todas];
        notifyListeners();
        return ResultadoRegistro.salvoNoBanco;
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

  Future<void> atualizarStatus(Ocorrencia ocorrencia, StatusOcorrencia status) async {
    final atualizada =
        ocorrencia.demo ? ocorrencia.copyWith(status: status) : await api.atualizarStatus(ocorrencia.id, status);
    _todas = [for (final o in _todas) (o.id == ocorrencia.id && o.demo == ocorrencia.demo) ? atualizada : o];
    notifyListeners();
  }

  void _entrarNaDemo(String mensagem) {
    if (!modoDemonstracao) _todas = ocorrenciasDemo();
    modoDemonstracao = true;
    aviso = mensagem;
  }
}
