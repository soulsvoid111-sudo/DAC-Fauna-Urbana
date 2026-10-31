import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../data/especies.dart';
import '../models/ocorrencia.dart';
import '../services/api.dart';
import '../services/ocorrencias_controller.dart';
import '../theme.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key, required this.controller});
  final OcorrenciasController controller;

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

enum _EstadoGps { buscando, ok, manual, erro }

class _RegistroScreenState extends State<RegistroScreen> {
  final _form = GlobalKey<FormState>();
  final _situacao = TextEditingController();
  final _mapa = MapController();
  String _especie = '';

  TipoOcorrencia _tipo = TipoOcorrencia.avistamento;
  LatLng _ponto = centroPadrao;
  _EstadoGps _gps = _EstadoGps.buscando;
  String? _erroGps;
  Uint8List? _foto;
  String? _nomeFoto;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _usarGps();
  }

  @override
  void dispose() {
    _situacao.dispose();
    super.dispose();
  }

  Future<void> _usarGps() async {
    setState(() {
      _gps = _EstadoGps.buscando;
      _erroGps = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'A localização do aparelho está desligada.';
      }
      var permissao = await Geolocator.checkPermission();
      if (permissao == LocationPermission.denied) permissao = await Geolocator.requestPermission();
      if (permissao == LocationPermission.denied || permissao == LocationPermission.deniedForever) {
        throw 'Permissão de localização negada.';
      }
      final posicao = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
      );
      if (!mounted) return;
      final ponto = LatLng(posicao.latitude, posicao.longitude);
      setState(() {
        _ponto = ponto;
        _gps = _EstadoGps.ok;
      });
      _mapa.move(ponto, 16);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _gps = _EstadoGps.erro;
        _erroGps = e is String ? e : 'Não foi possível obter a localização.';
      });
    }
  }

  Future<void> _escolherFoto(ImageSource origem) async {
    try {
      final arquivo = await ImagePicker().pickImage(source: origem, maxWidth: 1600, imageQuality: 82);
      if (arquivo == null) return;
      final bytes = await arquivo.readAsBytes();
      if (!mounted) return;
      setState(() {
        _foto = bytes;
        _nomeFoto = arquivo.name;
      });
    } catch (_) {
      _avisar('Não foi possível abrir a câmera ou a galeria.');
    }
  }

  void _avisar(String texto) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _enviar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _enviando = true);
    try {
      final resultado = await widget.controller.registrar(NovaOcorrencia(
        ponto: _ponto,
        situacao: _situacao.text.trim(),
        tipo: _tipo,
        especie: _especie.trim().isEmpty ? null : _especie.trim(),
        foto: _foto,
        nomeFoto: _nomeFoto,
      ));
      if (!mounted) return;
      Navigator.pop(context);
      _avisarNaTelaAnterior(switch (resultado) {
        ResultadoRegistro.salvoNoBanco => 'Ocorrência registrada. Obrigado por ajudar!',
        ResultadoRegistro.salvoSemFoto => 'Ocorrência registrada, mas a foto não foi enviada. Tente uma foto menor.',
        ResultadoRegistro.salvoNaDemo => 'Sem conexão: o registro ficou só neste aparelho (modo demonstração).',
      });
    } on ApiException catch (e) {
      _avisar(e.mensagem);
      setState(() => _enviando = false);
    } catch (_) {
      _avisar('Não foi possível registrar a ocorrência.');
      setState(() => _enviando = false);
    }
  }

  void _avisarNaTelaAnterior(String texto) =>
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(texto)));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Nova ocorrência', style: TextStyle(fontWeight: FontWeight.w800))),
        body: Form(
          key: _form,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  if (widget.controller.modoDemonstracao) ...[
                    const Text('Modo demonstração: este registro não será enviado ao banco.',
                        style: TextStyle(color: warnInk, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                  ],
                  _titulo('1. Foto', 'Ajuda a identificar o animal. Mantenha distância segura.'),
                  _secaoFoto(),
                  const SizedBox(height: 24),
                  _titulo('2. O que está acontecendo?', null),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final t in TipoOcorrencia.values)
                      ChoiceChip(
                        avatar: Icon(t.icone, size: 18, color: _tipo == t ? Colors.white : t.cor),
                        label: Text(t.rotulo),
                        selected: _tipo == t,
                        showCheckmark: false,
                        selectedColor: t.cor,
                        labelStyle: TextStyle(color: _tipo == t ? Colors.white : ink, fontWeight: FontWeight.w600),
                        onSelected: (_) => setState(() => _tipo = t),
                      ),
                  ]),
                  if (_tipo.urgente) ...[const SizedBox(height: 12), const _AvisoUrgente()],
                  const SizedBox(height: 24),
                  _titulo('3. Qual animal?', 'Opcional. Deixe em branco se não souber.'),
                  _campoEspecie(),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _situacao,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Descreva o que você viu',
                      hintText: 'Ex.: quati mancando perto do estacionamento',
                      alignLabelWithHint: true,
                    ),
                    validator: (v) =>
                        (v ?? '').trim().length < 3 ? 'Conte em poucas palavras o que você viu.' : null,
                  ),
                  const SizedBox(height: 16),
                  _titulo('4. Onde?', 'Toque no mapa para ajustar o ponto exato.'),
                  _secaoLocal(),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton.icon(
              onPressed: _enviando ? null : _enviar,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              icon: _enviando
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
              label: Text(_enviando ? 'Enviando...' : 'Enviar registro',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ),
      );

  Widget _titulo(String texto, String? apoio) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(texto, style: const TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.w800)),
          if (apoio != null) ...[
            const SizedBox(height: 2),
            Text(apoio, style: const TextStyle(color: muted, fontSize: 12)),
          ],
        ]),
      );

  Widget _secaoFoto() {
    if (_foto != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(children: [
          Image.memory(_foto!, height: 210, width: double.infinity, fit: BoxFit.cover),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton.filled(
              tooltip: 'Remover foto',
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
              onPressed: () => setState(() => _foto = null),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),
        ]),
      );
    }
    return Row(children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () => _escolherFoto(ImageSource.camera),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Tirar foto'),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () => _escolherFoto(ImageSource.gallery),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Galeria'),
        ),
      ),
    ]);
  }

  Widget _campoEspecie() => Autocomplete<String>(
        optionsBuilder: (valor) {
          final busca = valor.text.trim().toLowerCase();
          if (busca.isEmpty) return const Iterable<String>.empty();
          return especiesComuns.where((e) => e.toLowerCase().contains(busca));
        },
        onSelected: (valor) => _especie = valor,
        fieldViewBuilder: (context, controller, foco, _) => TextFormField(
          controller: controller,
          focusNode: foco,
          maxLength: 100,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (v) => _especie = v,
          decoration: const InputDecoration(
            labelText: 'Espécie',
            hintText: 'Ex.: capivara, arara, quati',
            prefixIcon: Icon(Icons.pets_outlined),
            counterText: '',
          ),
        ),
      );

  Widget _secaoLocal() {
    final (icone, cor, texto) = switch (_gps) {
      _EstadoGps.buscando => (Icons.gps_not_fixed, muted, 'Buscando sua localização...'),
      _EstadoGps.ok => (Icons.gps_fixed, forest, 'Localização obtida pelo GPS'),
      _EstadoGps.manual => (Icons.touch_app_outlined, forest, 'Ponto ajustado no mapa'),
      _EstadoGps.erro => (Icons.gps_off, const Color(0xFFB3261E), '${_erroGps ?? 'Sem GPS'} Toque no mapa para marcar.'),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 230,
          child: FlutterMap(
            mapController: _mapa,
            options: MapOptions(
              initialCenter: _ponto,
              initialZoom: 14,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              onTap: (_, ponto) => setState(() {
                _ponto = ponto;
                _gps = _EstadoGps.manual;
              }),
            ),
            children: [
              TileLayer(urlTemplate: tileUrl, userAgentPackageName: userAgentPackage),
              MarkerLayer(markers: [
                Marker(
                  point: _ponto,
                  width: 44,
                  height: 44,
                  alignment: Alignment.topCenter,
                  child: Icon(Icons.location_on, color: _tipo.cor, size: 44),
                ),
              ]),
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Icon(icone, size: 18, color: cor),
        const SizedBox(width: 6),
        Expanded(child: Text(texto, style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w600))),
        TextButton.icon(
          onPressed: _gps == _EstadoGps.buscando ? null : _usarGps,
          icon: const Icon(Icons.my_location, size: 18),
          label: const Text('Usar GPS'),
        ),
      ]),
      Text('${_ponto.latitude.toStringAsFixed(5)}, ${_ponto.longitude.toStringAsFixed(5)}',
          style: const TextStyle(color: muted, fontSize: 11)),
    ]);
  }
}

class _AvisoUrgente extends StatelessWidget {
  const _AvisoUrgente();

  Widget _ligar(String numero, String rotulo) => Expanded(
        child: OutlinedButton(
          onPressed: () => launchUrl(Uri.parse('tel:$numero')),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF8C1D18),
            side: const BorderSide(color: Color(0xFFE6B8B3)),
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          ),
          child: Column(children: [
            Text(numero, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text(rotulo, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFDECEA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF2C6C1)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.emergency_outlined, color: Color(0xFF8C1D18), size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text('O animal precisa de ajuda agora?',
                  style: TextStyle(color: Color(0xFF8C1D18), fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 6),
          const Text(
            'Não tente pegar ou alimentar o animal. Acione a Polícia Militar Ambiental pelo 190 ou o Corpo de Bombeiros pelo 193, e depois registre aqui.',
            style: TextStyle(color: Color(0xFF6B1B16), fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 10),
          Row(children: [
            _ligar('190', 'Polícia Militar Ambiental'),
            const SizedBox(width: 8),
            _ligar('193', 'Bombeiros'),
          ]),
        ]),
      );
}
