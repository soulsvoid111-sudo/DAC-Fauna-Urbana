import 'package:flutter/material.dart';

import '../models/ocorrencia.dart';
import '../services/meus_registros_controller.dart';
import '../theme.dart';
import '../widgets/comuns.dart';
import '../widgets/detalhe_sheet.dart';

/// Tela inicial de quem registra: botão para avisar a equipe e os registros feitos neste aparelho.
class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key, required this.controller, required this.onRegistrar});
  final MeusRegistrosController controller;
  final VoidCallback onRegistrar;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final c = controller;
          return RefreshIndicator(
            onRefresh: c.atualizarSituacao,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                  children: [
                    _Chamada(onRegistrar: onRegistrar),
                    const SizedBox(height: 16),
                    const _ComoFunciona(),
                    const SizedBox(height: 24),
                    Row(children: [
                      const Expanded(
                        child: Text('Meus registros',
                            style: TextStyle(color: ink, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                      ),
                      if (c.carregando)
                        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: forest)),
                    ]),
                    const SizedBox(height: 4),
                    const Text('Só você vê esta lista. Ela fica guardada neste aparelho.',
                        style: TextStyle(color: muted, fontSize: 12)),
                    if (c.semConexao) ...[
                      const SizedBox(height: 10),
                      const Text('Sem conexão agora: mostrando a última situação conhecida.',
                          style: TextStyle(color: warnInk, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                    const SizedBox(height: 14),
                    if (c.registros.isEmpty && !c.carregando)
                      _Vazio(onRegistrar: onRegistrar)
                    else
                      for (final r in c.registros) _CartaoMeuRegistro(controller: c, registro: r),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pushNamed('/admin'),
                        style: TextButton.styleFrom(foregroundColor: muted.withValues(alpha: 0.7)),
                        child: const Text('Acesso da equipe', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
}

class _Chamada extends StatelessWidget {
  const _Chamada({required this.onRegistrar});
  final VoidCallback onRegistrar;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF174B38), Color(0xFF347454)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('CIÊNCIA CIDADÃ • CAMPO GRANDE (MS)',
              style: TextStyle(color: Color(0xFFCFE6D7), fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          const Text('Viu um animal silvestre ferido, morto ou em risco?',
              style: TextStyle(color: Colors.white, fontSize: 23, height: 1.15, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          const Text('Registre com foto e localização. A equipe SOFUR recebe na hora e aciona os responsáveis.',
              style: TextStyle(color: Color(0xFFE0EEE4), fontSize: 13, height: 1.45)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onRegistrar,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: forest,
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Registrar ocorrência', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
        ]),
      );
}

class _ComoFunciona extends StatelessWidget {
  const _ComoFunciona();

  Widget _passo(IconData icone, String texto) => Expanded(
        child: Column(children: [
          CircleAvatar(radius: 20, backgroundColor: pale, child: Icon(icone, color: forest, size: 20)),
          const SizedBox(height: 6),
          Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: ink, fontSize: 11, height: 1.3)),
        ]),
      );

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _passo(Icons.photo_camera_outlined, 'Você registra com foto e local'),
            _passo(Icons.send_outlined, 'A equipe recebe o aviso'),
            _passo(Icons.support_agent_outlined, 'Os responsáveis são acionados'),
          ]),
        ),
      );
}

class _CartaoMeuRegistro extends StatelessWidget {
  const _CartaoMeuRegistro({required this.controller, required this.registro});
  final MeusRegistrosController controller;
  final MeuRegistro registro;

  @override
  Widget build(BuildContext context) {
    final o = registro.ocorrencia;
    final url = controller.urlFoto(registro);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => mostrarDetalhe(context, o, urlFoto: url, explicacaoStatus: explicarStatus(o.status)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (url != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(width: 64, height: 64, child: FotoOcorrencia(ocorrencia: o, url: url, altura: 64)),
                )
              else
                IconeTipo(tipo: o.tipo, tamanho: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(o.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    Etiqueta(texto: o.tipo.rotulo, cor: o.tipo.cor),
                    Etiqueta(texto: o.status.rotulo, cor: o.status.cor),
                  ]),
                  const SizedBox(height: 8),
                  Text(explicarStatus(o.status), style: const TextStyle(color: ink, fontSize: 12, height: 1.35)),
                  const SizedBox(height: 6),
                  Text('Protocolo #${o.codigo} • ${formatarData(o.dataRegistro)}',
                      style: const TextStyle(color: muted, fontSize: 11)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio({required this.onRegistrar});
  final VoidCallback onRegistrar;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(children: [
            const Icon(Icons.nature_outlined, color: forest, size: 36),
            const SizedBox(height: 12),
            const Text('Você ainda não fez registros',
                style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 6),
            const Text('Quando registrar uma ocorrência, ela aparece aqui com a situação atualizada pela equipe.',
                textAlign: TextAlign.center, style: TextStyle(color: muted, height: 1.45, fontSize: 13)),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRegistrar,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Registrar ocorrência'),
            ),
          ]),
        ),
      );
}
