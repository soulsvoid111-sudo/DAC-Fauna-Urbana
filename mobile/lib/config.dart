import 'package:latlong2/latlong.dart';

/// Endereço da API. No celular físico, `127.0.0.1` é o próprio celular, então
/// rode com o IP do computador na mesma rede:
///   flutter run --dart-define=API_URL=http://192.168.0.10:8000
/// No emulador Android use http://10.0.2.2:8000.
const apiBaseUrl = String.fromEnvironment('API_URL', defaultValue: 'http://127.0.0.1:8000');

/// Centro inicial do mapa: Campo Grande (MS).
const centroPadrao = LatLng(-20.4697, -54.6201);

const tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const userAgentPackage = 'br.ucdb.faunaurbana';
