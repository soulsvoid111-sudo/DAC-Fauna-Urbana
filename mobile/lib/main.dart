import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const forest = Color(0xFF205C45);
const leaf = Color(0xFF4D8B62);
const pale = Color(0xFFE8F2E8);
const background = Color(0xFFF5F7F3);
const ink = Color(0xFF20332A);
const muted = Color(0xFF718078);
const apiBaseUrl = 'http://127.0.0.1:8000';

void main() => runApp(const FaunaUrbanaApp());

class FaunaUrbanaApp extends StatelessWidget {
  const FaunaUrbanaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Fauna Urbana',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: forest),
          scaffoldBackgroundColor: background,
          appBarTheme: const AppBarTheme(
            backgroundColor: background,
            foregroundColor: ink,
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFFE7ECE7)),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFFF7F9F6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> ocorrencias = [];
  bool carregando = true;
  bool modoDemonstracao = false;
  String? aviso;
  int proximoIdDemo = 4;

  final List<Map<String, dynamic>> dadosDemo = [
    {
      'id': 'DEMO-01',
      'latitude': -20.4697,
      'longitude': -54.6201,
      'situacao': 'Animal encontrado próximo à via',
      'data_registro': '2026-10-22T09:15:00',
    },
    {
      'id': 'DEMO-02',
      'latitude': -20.4551,
      'longitude': -54.6038,
      'situacao': 'Arara-canindé avistada em área urbana',
      'data_registro': '2026-10-21T16:40:00',
    },
    {
      'id': 'DEMO-03',
      'latitude': -20.4823,
      'longitude': -54.6352,
      'situacao': 'Capivara avistada próxima a uma área verde',
      'data_registro': '2026-10-20T07:50:00',
    },
  ];

  @override
  void initState() {
    super.initState();
    buscarOcorrencias();
  }

  Future<void> buscarOcorrencias() async {
    if (!mounted) return;
    setState(() {
      carregando = true;
      aviso = null;
    });
    try {
      final resposta = await http
          .get(Uri.parse('$apiBaseUrl/ocorrencias'))
          .timeout(const Duration(seconds: 5));
      if (resposta.statusCode == 200) {
        final lista = jsonDecode(resposta.body) as List<dynamic>;
        if (!mounted) return;
        setState(() {
          ocorrencias = lista
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
          modoDemonstracao = false;
          carregando = false;
        });
      } else {
        _usarDemo('A API respondeu com código ${resposta.statusCode}.');
      }
    } catch (_) {
      _usarDemo('API indisponível. Os registros abaixo são fictícios e servem apenas para demonstração.');
    }
  }

  void _usarDemo(String mensagem) {
    if (!mounted) return;
    setState(() {
      modoDemonstracao = true;
      aviso = mensagem;
      ocorrencias = dadosDemo.map((item) => Map<String, dynamic>.from(item)).toList();
      carregando = false;
    });
  }

  Future<void> registrarOcorrencia(double latitude, double longitude, String situacao) async {
    if (modoDemonstracao) {
      _adicionarDemo(latitude, longitude, situacao);
      return;
    }
    try {
      final resposta = await http
          .post(
            Uri.parse('$apiBaseUrl/ocorrencias'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'latitude': latitude, 'longitude': longitude, 'situacao': situacao}),
          )
          .timeout(const Duration(seconds: 5));
      if (resposta.statusCode == 200 || resposta.statusCode == 201) {
        await buscarOcorrencias();
      } else {
        _usarDemo('A API não aceitou o cadastro. Este registro será apenas demonstrativo.');
        _adicionarDemo(latitude, longitude, situacao);
      }
    } catch (_) {
      _usarDemo('API indisponível. Este registro ficará somente nesta demonstração, não no banco.');
      _adicionarDemo(latitude, longitude, situacao);
    }
  }

  void _adicionarDemo(double latitude, double longitude, String situacao) {
    final novo = <String, dynamic>{
      'id': 'DEMO-${(proximoIdDemo++).toString().padLeft(2, '0')}',
      'latitude': latitude,
      'longitude': longitude,
      'situacao': situacao,
      'data_registro': DateTime.now().toIso8601String(),
    };
    if (!mounted) return;
    setState(() {
      modoDemonstracao = true;
      aviso = 'Modo demonstração: alterações ficam apenas na memória do aplicativo e não são salvas no banco.';
      ocorrencias = [novo, ...ocorrencias];
    });
  }

  void abrirFormulario() {
    final situacao = TextEditingController();
    final latitude = TextEditingController(text: '-20.4697');
    final longitude = TextEditingController(text: '-54.6201');
    final formKey = GlobalKey<FormState>();
    bool enviando = false;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Row(children: [
            Icon(Icons.add_location_alt_outlined, color: forest),
            SizedBox(width: 10),
            Expanded(child: Text('Nova ocorrência')),
          ]),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                    controller: situacao,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'O que foi observado?',
                      hintText: 'Ex.: animal encontrado próximo à via',
                      prefixIcon: Icon(Icons.pets_outlined),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Descreva a ocorrência.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: latitude,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(labelText: 'Latitude', prefixIcon: Icon(Icons.north)),
                    validator: (v) => double.tryParse((v ?? '').replaceAll(',', '.')) == null ? 'Latitude inválida.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: longitude,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(labelText: 'Longitude', prefixIcon: Icon(Icons.east)),
                    validator: (v) => double.tryParse((v ?? '').replaceAll(',', '.')) == null ? 'Longitude inválida.' : null,
                  ),
                  if (modoDemonstracao) ...[
                    const SizedBox(height: 10),
                    const Text('Modo demonstração: o registro não será enviado ao banco.', style: TextStyle(color: muted, fontSize: 12)),
                  ],
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: enviando ? null : () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
            FilledButton.icon(
              onPressed: enviando ? null : () async {
                if (!formKey.currentState!.validate()) return;
                setDialogState(() => enviando = true);
                try {
                  await registrarOcorrencia(
                    double.parse(latitude.text.replaceAll(',', '.')),
                    double.parse(longitude.text.replaceAll(',', '.')),
                    situacao.text.trim(),
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                      content: Text(modoDemonstracao ? 'Registro demonstrativo adicionado.' : 'Ocorrência registrada.'),
                    ));
                  }
                } catch (_) {
                  setDialogState(() => enviando = false);
                  if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Não foi possível registrar a ocorrência.')));
                }
              },
              icon: enviando
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check),
              label: Text(enviando ? 'Salvando...' : 'Adicionar registro'),
            ),
          ],
        ),
      ),
    ).then((_) {
      situacao.dispose();
      latitude.dispose();
      longitude.dispose();
    });
  }

  String formatarData(dynamic valor) {
    if (valor == null) return 'Data não informada';
    final data = DateTime.tryParse(valor.toString());
    if (data == null) return valor.toString();
    final d = data.toLocal();
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(d.day)}/${dois(d.month)}/${d.year} • ${dois(d.hour)}:${dois(d.minute)}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          titleSpacing: 18,
          title: const Row(children: [
            CircleAvatar(backgroundColor: pale, radius: 18, child: Icon(Icons.eco_outlined, color: forest, size: 21)),
            SizedBox(width: 10),
            Text('Fauna Urbana', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.4)),
          ]),
          actions: [
            IconButton(tooltip: 'Atualizar', onPressed: carregando ? null : buscarOcorrencias, icon: const Icon(Icons.refresh_rounded)),
            const SizedBox(width: 8),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: abrirFormulario,
          backgroundColor: forest,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Registrar ocorrência'),
        ),
        body: RefreshIndicator(
          onRefresh: buscarOcorrencias,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
            children: [
              _hero(),
              const SizedBox(height: 18),
              if (modoDemonstracao) ...[_demoBanner(), const SizedBox(height: 18)],
              _summary(),
              const SizedBox(height: 28),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Registros recentes', style: TextStyle(color: ink, fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  SizedBox(height: 4),
                  Text('Observações compartilhadas pela comunidade', style: TextStyle(color: muted, fontSize: 12)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(color: pale, borderRadius: BorderRadius.circular(30)),
                  child: Text('${ocorrencias.length} registros', style: const TextStyle(color: forest, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ]),
              const SizedBox(height: 14),
              if (carregando)
                const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator(color: forest)))
              else if (ocorrencias.isEmpty)
                _emptyState()
              else
                ...ocorrencias.map(_occurrenceCard),
              const SizedBox(height: 12),
              const Center(child: Text('Fauna Urbana • Ciência cidadã e conservação', textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 11))),
            ],
          ),
        ),
      );

  Widget _hero() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF174B38), Color(0xFF347454)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Stack(children: [
          Positioned(right: -8, top: 4, child: Icon(Icons.nature_people_outlined, size: 108, color: Colors.white.withValues(alpha: 0.13))),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white24)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.public, color: Colors.white, size: 14), SizedBox(width: 6), Text('CIÊNCIA CIDADÃ', style: TextStyle(color: Colors.white, fontSize: 10, letterSpacing: 1.1, fontWeight: FontWeight.w800))]),
            ),
            const SizedBox(height: 18),
            const SizedBox(width: 255, child: Text('A natureza também vive na cidade.', style: TextStyle(color: Colors.white, fontSize: 27, height: 1.12, fontWeight: FontWeight.w800, letterSpacing: -0.7))),
            const SizedBox(height: 10),
            const SizedBox(width: 270, child: Text('Registre observações e ajude a ampliar o conhecimento sobre a fauna urbana.', style: TextStyle(color: Color(0xFFE0EEE4), fontSize: 13, height: 1.45))),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: abrirFormulario,
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: forest, padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12)),
              icon: const Icon(Icons.add, size: 19),
              label: const Text('Fazer um registro', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ]),
        ]),
      );

  Widget _demoBanner() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFFFF4DB), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFEBD49B))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline, color: Color(0xFF805A12)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Modo demonstração', style: TextStyle(color: Color(0xFF805A12), fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(aviso ?? 'Os dados exibidos são fictícios.', style: const TextStyle(color: Color(0xFF6D572C), fontSize: 12, height: 1.4)),
            const SizedBox(height: 6),
            const Text('Toque em atualizar para tentar conectar novamente.', style: TextStyle(color: Color(0xFF6D572C), fontSize: 12)),
          ])),
        ]),
      );

  Widget _summary() => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Container(width: 54, height: 54, decoration: BoxDecoration(color: pale, borderRadius: BorderRadius.circular(17)), child: const Icon(Icons.pets_outlined, color: forest, size: 29)),
            const SizedBox(width: 15),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Ocorrências registradas', style: TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text('${ocorrencias.length}', style: const TextStyle(color: ink, fontSize: 29, height: 1.1, fontWeight: FontWeight.w800)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(color: modoDemonstracao ? const Color(0xFFFFF4DB) : pale, borderRadius: BorderRadius.circular(30)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(modoDemonstracao ? Icons.science_outlined : Icons.check_circle_outline, size: 14, color: modoDemonstracao ? const Color(0xFF805A12) : forest),
                const SizedBox(width: 5),
                Text(modoDemonstracao ? 'Exemplo' : 'Conectado', style: TextStyle(color: modoDemonstracao ? const Color(0xFF805A12) : forest, fontSize: 11, fontWeight: FontWeight.w800)),
              ]),
            ),
          ]),
        ),
      );

  Widget _occurrenceCard(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '—';
    final situacao = item['situacao']?.toString() ?? 'Situação não informada';
    final latitude = item['latitude']?.toString() ?? '—';
    final longitude = item['longitude']?.toString() ?? '—';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 43, height: 43, decoration: BoxDecoration(color: pale, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.pets_outlined, color: forest, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ocorrência #$id', style: const TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 3),
              Text(formatarData(item['data_registro']), style: const TextStyle(color: muted, fontSize: 11)),
            ])),
            const Icon(Icons.more_horiz, color: muted),
          ]),
          const SizedBox(height: 15),
          Text(situacao, style: const TextStyle(color: ink, fontSize: 15, height: 1.4, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(color: const Color(0xFFF5F7F3), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.location_on_outlined, size: 17, color: leaf),
              const SizedBox(width: 7),
              Expanded(child: Text('$latitude, $longitude', style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600))),
              const Icon(Icons.my_location_outlined, size: 15, color: muted),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _emptyState() => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(children: [
            Container(width: 64, height: 64, decoration: const BoxDecoration(color: pale, shape: BoxShape.circle), child: const Icon(Icons.nature_outlined, color: forest, size: 32)),
            const SizedBox(height: 14),
            const Text('Ainda não há registros', style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 6),
            const Text('Compartilhe uma observação de fauna urbana com a comunidade.', textAlign: TextAlign.center, style: TextStyle(color: muted, height: 1.45, fontSize: 13)),
            const SizedBox(height: 16),
            OutlinedButton.icon(onPressed: abrirFormulario, icon: const Icon(Icons.add_location_alt_outlined), label: const Text('Registrar ocorrência')),
          ]),
        ),
      );
}
