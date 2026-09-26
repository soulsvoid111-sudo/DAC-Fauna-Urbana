import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const FaunaUrbanaApp());
}

class FaunaUrbanaApp extends StatelessWidget {
  const FaunaUrbanaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fauna Urbana',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<dynamic> ocorrencias = [];
  bool carregando = true;
  String? erro;

  @override
  void initState() {
    super.initState();
    buscarOcorrencias();
  }

  Future<void> buscarOcorrencias() async {
    setState(() {
      carregando = true;
      erro = null;
    });

    try {
      final resposta = await http.get(
        Uri.parse('http://127.0.0.1:8000/ocorrencias'),
      );

      if (resposta.statusCode == 200) {
        setState(() {
          ocorrencias = jsonDecode(resposta.body);
          carregando = false;
        });
      } else {
        setState(() {
          erro = 'Erro da API: ${resposta.statusCode}';
          carregando = false;
        });
      }
    } catch (e) {
      setState(() {
        erro = 'Não foi possível conectar à API.';
        carregando = false;
      });
    }
  }

  Future<void> registrarOcorrencia(
    double latitude,
    double longitude,
    String situacao,
  ) async {
    final resposta = await http.post(
      Uri.parse('http://127.0.0.1:8000/ocorrencias'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        'situacao': situacao,
      }),
    );

    if (resposta.statusCode == 200) {
      await buscarOcorrencias();
    } else {
      throw Exception('Erro ao registrar ocorrência');
    }
  }

  void abrirFormulario() {
    final situacaoController = TextEditingController();
    final latitudeController =
        TextEditingController(text: '-20.4697');
    final longitudeController =
        TextEditingController(text: '-54.6201');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Registrar ocorrência'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: situacaoController,
                  decoration: const InputDecoration(
                    labelText: 'Situação',
                    hintText: 'Ex.: Animal encontrado próximo à via',
                  ),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: latitudeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Latitude',
                  ),
                ),

                const SizedBox(height: 12),

                TextField(
                  controller: longitudeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Longitude',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final situacao = situacaoController.text;

                if (situacao.isEmpty) {
                  return;
                }

                final latitude =
                    double.tryParse(latitudeController.text);

                final longitude =
                    double.tryParse(longitudeController.text);

                if (latitude == null || longitude == null) {
                  return;
                }

                try {
                  await registrarOcorrencia(
                    latitude,
                    longitude,
                    situacao,
                  );

                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Erro ao registrar ocorrência.',
                        ),
                      ),
                    );
                  }
                }
              },
              child: const Text('Registrar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fauna Urbana'),
        actions: [
          IconButton(
            onPressed: buscarOcorrencias,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: abrirFormulario,
        icon: const Icon(Icons.add),
        label: const Text('Registrar'),
      ),

      body: RefreshIndicator(
        onRefresh: buscarOcorrencias,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Monitoramento da fauna urbana',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Registro e visualização de ocorrências de fauna.',
              style: TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.pets,
                      size: 40,
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ocorrências registradas',
                          style: TextStyle(fontSize: 15),
                        ),
                        Text(
                          '${ocorrencias.length}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            if (carregando)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: CircularProgressIndicator(),
                ),
              ),

            if (erro != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(erro!),
                ),
              ),

            if (!carregando && erro == null && ocorrencias.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Nenhuma ocorrência registrada.',
                  ),
                ),
              ),

            for (final ocorrencia in ocorrencias)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on),
                          const SizedBox(width: 8),
                          Text(
                            'Ocorrência #${ocorrencia['id']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Text(
                        ocorrencia['situacao'],
                        style: const TextStyle(fontSize: 16),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'Latitude: ${ocorrencia['latitude']}',
                      ),

                      Text(
                        'Longitude: ${ocorrencia['longitude']}',
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Registrado em: ${ocorrencia['data_registro']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}