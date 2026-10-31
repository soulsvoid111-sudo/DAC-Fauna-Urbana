import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../services/ocorrencias_controller.dart';
import '../theme.dart';
import '../widgets/detalhe_sheet.dart';
import 'lista_screen.dart';

class MapaScreen extends StatelessWidget {
  const MapaScreen({super.key, required this.controller});
  final OcorrenciasController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Stack(children: [
          FlutterMap(
            options: const MapOptions(
              initialCenter: centroPadrao,
              initialZoom: 12.5,
              interactionOptions: InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            ),
            children: [
              TileLayer(urlTemplate: tileUrl, userAgentPackageName: userAgentPackage),
              MarkerLayer(markers: [
                for (final o in controller.visiveis)
                  Marker(
                    point: o.ponto,
                    width: 44,
                    height: 44,
                    child: GestureDetector(
                      onTap: () => mostrarDetalhe(context, controller, o),
                      child: Container(
                        decoration: BoxDecoration(
                          color: o.tipo.cor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 6, offset: Offset(0, 2))],
                        ),
                        child: Icon(o.tipo.icone, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
              ]),
              RichAttributionWidget(attributions: [
                TextSourceAttribution(
                  'OpenStreetMap contributors',
                  onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
                ),
              ]),
            ],
          ),
          Positioned(
            left: 12,
            right: 0,
            top: 10,
            child: FiltroTipos(controller: controller, fundoBranco: true),
          ),
          if (controller.modoDemonstracao)
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: warnBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: warnBorder),
                ),
                child: const Text('Dados de demonstração',
                    style: TextStyle(color: warnInk, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ),
        ]),
      );
}
