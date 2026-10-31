import 'package:flutter/foundation.dart';

import '../models/ocorrencia.dart';

/// Lista de ocorrências usada no painel da equipe (lista, mapa e filtros).
class OcorrenciasController extends ChangeNotifier {
  List<Ocorrencia> _todas = [];
  TipoOcorrencia? filtro;

  /// Quem sabe montar o endereço da foto (com o token da equipe).
  String? Function(Ocorrencia)? urlFoto;

  List<Ocorrencia> get todas => _todas;
  List<Ocorrencia> get visiveis => filtro == null ? _todas : _todas.where((o) => o.tipo == filtro).toList();
  int contar(TipoOcorrencia tipo) => _todas.where((o) => o.tipo == tipo).length;

  void definir(List<Ocorrencia> lista) {
    _todas = lista;
    notifyListeners();
  }

  void filtrar(TipoOcorrencia? tipo) {
    filtro = filtro == tipo ? null : tipo;
    notifyListeners();
  }

  void substituir(Ocorrencia nova) {
    _todas = [for (final o in _todas) o.id == nova.id ? nova : o];
    notifyListeners();
  }

  void remover(Ocorrencia ocorrencia) {
    _todas = _todas.where((o) => o.id != ocorrencia.id).toList();
    notifyListeners();
  }
}
