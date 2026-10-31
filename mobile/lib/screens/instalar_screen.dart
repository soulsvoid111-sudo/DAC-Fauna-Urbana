import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../theme.dart';

/// Passo a passo para instalar o SOFUR na tela inicial do celular.
class InstalarScreen extends StatefulWidget {
  const InstalarScreen({super.key});

  @override
  State<InstalarScreen> createState() => _InstalarScreenState();
}

enum _Aparelho {
  android('Android', 'Chrome', Icons.android),
  iphoneSafari('iPhone', 'Safari', Icons.phone_iphone),
  iphoneChrome('iPhone', 'Chrome', Icons.phone_iphone);

  const _Aparelho(this.sistema, this.navegador, this.icone);
  final String sistema;
  final String navegador;
  final IconData icone;

  /// Android só tem um caminho (Chrome); no iPhone mostra o navegador.
  String get rotulo => this == android ? sistema : '$sistema • $navegador';
}

/// O que aparece no desenho do celular em cada passo.
enum _Cena { abrirLink, menuAndroid, opcaoAndroid, confirmarAndroid, compartilharSafari, compartilharChrome, opcaoIos, confirmarIos, pronto }

class _Passo {
  const _Passo(this.titulo, this.texto, this.cena);
  final String titulo;
  final String texto;
  final _Cena cena;
}

const _endereco = 'fauna-urbana.onrender.com';

const _passos = {
  _Aparelho.android: [
    _Passo('Abra o SOFUR no Chrome', 'Digite $_endereco na barra de endereço do Chrome.', _Cena.abrirLink),
    _Passo('Toque nos três pontinhos', 'O menu fica no canto superior direito da tela.', _Cena.menuAndroid),
    _Passo('Adicionar à tela inicial', 'Toque em "Adicionar à tela inicial" (em alguns celulares aparece "Instalar app").',
        _Cena.opcaoAndroid),
    _Passo('Confirme', 'Toque em "Adicionar" (ou "Instalar") na janela que aparecer.', _Cena.confirmarAndroid),
    _Passo('Pronto!', 'O ícone do SOFUR fica na tela inicial. É só tocar para abrir, como qualquer app.', _Cena.pronto),
  ],
  _Aparelho.iphoneSafari: [
    _Passo('Abra o SOFUR no Safari', 'Digite $_endereco na barra de endereço do Safari.', _Cena.abrirLink),
    _Passo('Toque em Compartilhar', 'É o quadrado com uma seta para cima, na barra de baixo da tela.',
        _Cena.compartilharSafari),
    _Passo('Adicionar à Tela de Início', 'Role a lista de opções para baixo e toque em "Adicionar à Tela de Início".',
        _Cena.opcaoIos),
    _Passo('Toque em Adicionar', 'Fica no canto superior direito da janela.', _Cena.confirmarIos),
    _Passo('Pronto!', 'O ícone do SOFUR fica na tela de início. É só tocar para abrir, como qualquer app.', _Cena.pronto),
  ],
  _Aparelho.iphoneChrome: [
    _Passo('Abra o SOFUR no Chrome', 'Digite $_endereco na barra de endereço do Chrome.', _Cena.abrirLink),
    _Passo('Toque em Compartilhar', 'É o quadrado com uma seta para cima, ao lado da barra de endereço.',
        _Cena.compartilharChrome),
    _Passo('Adicionar à Tela de Início', 'Toque em "Adicionar à Tela de Início". Se não aparecer, toque em "Mais" '
        'ou atualize o iPhone e o Chrome.', _Cena.opcaoIos),
    _Passo('Toque em Adicionar', 'Fica no canto superior direito da janela.', _Cena.confirmarIos),
    _Passo('Pronto!', 'O ícone do SOFUR fica na tela de início. É só tocar para abrir, como qualquer app.', _Cena.pronto),
  ],
};

class _InstalarScreenState extends State<InstalarScreen> {
  // Já começa no aparelho de quem está usando.
  late _Aparelho _aparelho =
      defaultTargetPlatform == TargetPlatform.iOS ? _Aparelho.iphoneSafari : _Aparelho.android;
  final _paginas = PageController();
  int _pagina = 0;

  List<_Passo> get _lista => _passos[_aparelho]!;

  void _trocarAparelho(_Aparelho a) {
    setState(() {
      _aparelho = a;
      _pagina = 0;
    });
    _paginas.jumpToPage(0);
  }

  void _irPara(int i) => _paginas.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ultimo = _pagina == _lista.length - 1;
    return Scaffold(
      appBar: AppBar(title: const Text('Instalar o $nomeApp', style: TextStyle(fontWeight: FontWeight.w800))),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                  for (final a in _Aparelho.values)
                    ChoiceChip(
                      avatar: Icon(a.icone, size: 18, color: _aparelho == a ? Colors.white : forest),
                      label: Text(a.rotulo),
                      selected: _aparelho == a,
                      showCheckmark: false,
                      selectedColor: forest,
                      labelStyle: TextStyle(color: _aparelho == a ? Colors.white : ink, fontWeight: FontWeight.w700),
                      onSelected: (_) => _trocarAparelho(a),
                    ),
                ]),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _paginas,
                  itemCount: _lista.length,
                  onPageChanged: (i) => setState(() => _pagina = i),
                  itemBuilder: (_, i) => _PaginaPasso(numero: i + 1, total: _lista.length, passo: _lista[i]),
                ),
              ),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < _lista.length; i++)
                  GestureDetector(
                    onTap: () => _irPara(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _pagina ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _pagina ? forest : border,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pagina == 0 ? null : () => _irPara(_pagina - 1),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      child: const Text('Anterior'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: ultimo ? () => Navigator.of(context).pop() : () => _irPara(_pagina + 1),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      child: Text(ultimo ? 'Entendi' : 'Próximo'),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _PaginaPasso extends StatelessWidget {
  const _PaginaPasso({required this.numero, required this.total, required this.passo});
  final int numero;
  final int total;
  final _Passo passo;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [
            const SizedBox(height: 8),
            SizedBox(height: (box.maxHeight * 0.62).clamp(260, 420), child: _Celular(cena: passo.cena)),
            const SizedBox(height: 18),
            Text('PASSO $numero DE $total',
                style: const TextStyle(color: leaf, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(passo.titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(color: ink, fontSize: 21, fontWeight: FontWeight.w800, height: 1.2)),
            const SizedBox(height: 8),
            Text(passo.texto,
                textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 14, height: 1.45)),
            const SizedBox(height: 12),
          ]),
        ),
      );
}

// ---------- Desenho simplificado do celular em cada passo ----------

const _destaque = Color(0xFFE67E22);

class _Celular extends StatelessWidget {
  const _Celular({required this.cena});
  final _Cena cena;

  @override
  // O desenho é montado sempre no mesmo tamanho e só muda de escala, para nunca "estourar" em telas pequenas.
  Widget build(BuildContext context) => FittedBox(
        child: Container(
          width: 190,
          height: 359,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2A24),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 8))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: ColoredBox(color: const Color(0xFFF2F4F2), child: _conteudo()),
          ),
        ),
      );

  Widget _conteudo() => switch (cena) {
        _Cena.abrirLink => _Navegador(destaqueEndereco: true),
        _Cena.menuAndroid => _Navegador(destaqueMenu: true),
        _Cena.opcaoAndroid => _Navegador(sobreposicao: _MenuAndroid()),
        _Cena.confirmarAndroid => _Navegador(sobreposicao: _Dialogo(botao: 'Adicionar')),
        _Cena.compartilharSafari => _Navegador(ios: true, destaqueCompartilharEmBaixo: true),
        _Cena.compartilharChrome => _Navegador(ios: true, destaqueCompartilharEmCima: true),
        _Cena.opcaoIos => _Navegador(ios: true, sobreposicao: _FolhaCompartilhar()),
        _Cena.confirmarIos => _Navegador(ios: true, sobreposicao: _Dialogo(botao: 'Adicionar', topo: true)),
        _Cena.pronto => const _TelaInicial(),
      };
}

class _Anel extends StatelessWidget {
  const _Anel({required this.child, this.ativo = true});
  final Widget child;
  final bool ativo;

  @override
  Widget build(BuildContext context) => !ativo
      ? child
      : Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            border: Border.all(color: _destaque, width: 2.5),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: _destaque.withValues(alpha: 0.35), blurRadius: 10)],
          ),
          child: child,
        );
}

/// Navegador com a página do SOFUR aberta.
class _Navegador extends StatelessWidget {
  const _Navegador({
    this.ios = false,
    this.destaqueEndereco = false,
    this.destaqueMenu = false,
    this.destaqueCompartilharEmBaixo = false,
    this.destaqueCompartilharEmCima = false,
    this.sobreposicao,
  });
  final bool ios;
  final bool destaqueEndereco;
  final bool destaqueMenu;
  final bool destaqueCompartilharEmBaixo;
  final bool destaqueCompartilharEmCima;
  final Widget? sobreposicao;

  @override
  Widget build(BuildContext context) {
    final barraEndereco = Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 10, 6, 8),
      child: Row(children: [
        Expanded(
          child: _Anel(
            ativo: destaqueEndereco,
            child: Container(
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(color: const Color(0xFFEDEFED), borderRadius: BorderRadius.circular(13)),
              child: const Row(children: [
                Icon(Icons.lock_outline, size: 11, color: muted),
                SizedBox(width: 4),
                Expanded(
                  child: Text(_endereco,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.5, color: ink)),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 4),
        if (destaqueCompartilharEmCima)
          const _Anel(child: Icon(Icons.ios_share, size: 18, color: Color(0xFF1A73E8)))
        else if (!ios)
          _Anel(ativo: destaqueMenu, child: const Icon(Icons.more_vert, size: 20, color: ink)),
      ]),
    );

    final pagina = Expanded(
      child: Container(
        color: const Color(0xFFF5F7F3),
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.asset('assets/icone_app.png', width: 20, height: 20),
            ),
            const SizedBox(width: 6),
            const Text(nomeApp, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: ink)),
          ]),
          const SizedBox(height: 10),
          Container(
            height: 70,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF174B38), Color(0xFF347454)]),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 8),
          for (final w in [0.9, 0.7, 0.8])
            Container(
              margin: const EdgeInsets.only(top: 6),
              height: 8,
              width: 160 * w,
              decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(4)),
            ),
        ]),
      ),
    );

    final barraIos = Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        const Icon(Icons.chevron_left, size: 18, color: Color(0xFF1A73E8)),
        const Icon(Icons.chevron_right, size: 18, color: Color(0xFFB0B8C0)),
        _Anel(ativo: destaqueCompartilharEmBaixo, child: const Icon(Icons.ios_share, size: 18, color: Color(0xFF1A73E8))),
        const Icon(Icons.menu_book_outlined, size: 16, color: Color(0xFF1A73E8)),
        const Icon(Icons.copy_all_outlined, size: 16, color: Color(0xFF1A73E8)),
      ]),
    );

    return Stack(children: [
      Column(children: [barraEndereco, pagina, if (ios && !destaqueCompartilharEmCima) barraIos]),
      if (sobreposicao != null) ...[
        Positioned.fill(child: Container(color: const Color(0x66000000))),
        Positioned.fill(child: sobreposicao!),
      ],
    ]);
  }
}

class _MenuAndroid extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topRight,
        child: Container(
          margin: const EdgeInsets.only(top: 8, right: 6),
          width: 150,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final (icone, texto) in [
              (Icons.tab_outlined, 'Nova guia'),
              (Icons.history, 'Histórico'),
              (Icons.share_outlined, 'Compartilhar'),
            ])
              _ItemMenu(icone: icone, texto: texto),
            const _Anel(child: _ItemMenu(icone: Icons.add_to_home_screen, texto: 'Adicionar à tela inicial')),
            const _ItemMenu(icone: Icons.settings_outlined, texto: 'Configurações'),
          ]),
        ),
      );
}

class _FolhaCompartilhar extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: const Column(mainAxisSize: MainAxisSize.min, children: [
            _ItemMenu(icone: Icons.copy, texto: 'Copiar'),
            _ItemMenu(icone: Icons.bookmark_border, texto: 'Adicionar Favorito'),
            _Anel(child: _ItemMenu(icone: Icons.add_box_outlined, texto: 'Adicionar à Tela de Início')),
            _ItemMenu(icone: Icons.print_outlined, texto: 'Imprimir'),
          ]),
        ),
      );
}

class _ItemMenu extends StatelessWidget {
  const _ItemMenu({required this.icone, required this.texto});
  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(children: [
          Icon(icone, size: 14, color: ink),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texto, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: ink)),
          ),
        ]),
      );
}

class _Dialogo extends StatelessWidget {
  const _Dialogo({required this.botao, this.topo = false});
  final String botao;
  final bool topo;

  @override
  Widget build(BuildContext context) => Align(
        alignment: topo ? Alignment.topCenter : Alignment.center,
        child: Container(
          margin: EdgeInsets.fromLTRB(10, topo ? 10 : 0, 10, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (topo) ...[
              const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Flexible(
                  child: Text('Cancelar',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, color: Color(0xFF1A73E8))),
                ),
                SizedBox(width: 6),
                Flexible(
                  child: _Anel(
                    child: Text('Adicionar',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 9, color: Color(0xFF1A73E8), fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              const Text('Adicionar à Tela de Início', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
            ] else
              const Text('Adicionar à tela inicial', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset('assets/icone_app.png', width: 28, height: 28),
              ),
              const SizedBox(width: 8),
              const Text(nomeApp, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
            if (!topo) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: _Anel(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: const Color(0xFF1A73E8), borderRadius: BorderRadius.circular(14)),
                    child: Text(botao, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ]),
        ),
      );
}

/// Tela inicial do celular com o ícone do SOFUR instalado.
class _TelaInicial extends StatelessWidget {
  const _TelaInicial();

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF3E6B8A), Color(0xFF7FA7B8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(14, 28, 14, 14),
        child: GridView.count(
          crossAxisCount: 4,
          mainAxisSpacing: 14,
          crossAxisSpacing: 10,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var i = 0; i < 7; i++)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            Column(children: [
              Expanded(
                child: _Anel(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset('assets/icone_app.png', fit: BoxFit.contain),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              const Text(nomeApp, style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w700)),
            ]),
          ],
        ),
      );
}
