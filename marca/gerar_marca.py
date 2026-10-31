"""Gera a logo e os ícones do SOFUR a partir de formas simples.

    python marca/gerar_marca.py

Saídas em marca/: icone.png (1024, fundo verde), icone_frente.png (só a pegada,
fundo transparente, para o ícone adaptativo do Android) e logo.png (ícone + nome).
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

PASTA = Path(__file__).parent
ESCALA = 4  # desenha 4x maior e reduz, para bordas suaves
VERDE_ESCURO = (23, 75, 56)
VERDE_CLARO = (52, 116, 84)
FOLHA = (77, 139, 98)
BRANCO = (255, 255, 255)


def degrade(tamanho: int) -> Image.Image:
    img = Image.new("RGB", (tamanho, tamanho))
    px = img.load()
    for y in range(tamanho):
        for x in range(tamanho):
            t = (x + y) / (2 * (tamanho - 1))
            px[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(VERDE_ESCURO, VERDE_CLARO))
    return img


def elipse_girada(desenho_base: Image.Image, cx, cy, rx, ry, angulo, cor):
    """Desenha uma elipse girada (em graus) sobre a imagem."""
    camada = Image.new("L", desenho_base.size, 0)
    ImageDraw.Draw(camada).ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=255)
    camada = camada.rotate(-angulo, center=(cx, cy), resample=Image.BICUBIC)
    desenho_base.paste(Image.new("RGBA", desenho_base.size, cor + (255,)), (0, 0), camada)


def folha(cx, cy, comprimento, largura, angulo):
    """Pontos de uma folha (duas curvas que se encontram nas pontas)."""
    pts = []
    for i in range(61):
        t = i / 60
        x = (t - 0.5) * comprimento
        y = math.sin(math.pi * t) ** 0.85 * largura / 2
        pts.append((x, y))
    pts += [(x, -y) for x, y in reversed(pts)]
    a = math.radians(angulo)
    return [(cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a)) for x, y in pts]


def pegada(tamanho: int, area: float) -> Image.Image:
    """Pegada branca com uma folha na almofada, centrada, ocupando `area` do quadro."""
    s = tamanho * ESCALA
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    u = s * area  # unidade de medida relativa ao tamanho útil
    ox = oy = (s - u) / 2

    def p(x, y):
        return ox + x * u, oy + y * u

    # Almofada principal: forma única e lisa, mais larga em cima
    d = ImageDraw.Draw(img)
    cx, cy = p(0.5, 0.69)
    contorno = []
    for i in range(360):
        t = math.radians(i)
        cima = math.sin(t) < 0
        rx = u * 0.255 * (1 + (0.10 * -math.sin(t) if cima else -0.06 * math.sin(t)))
        ry = u * (0.175 if cima else 0.205)
        contorno.append((cx + rx * math.cos(t), cy + ry * math.sin(t)))
    d.polygon(contorno, fill=BRANCO + (255,))

    # Dedos
    for x, y, ang in [(0.14, 0.40, -28), (0.355, 0.19, -9), (0.645, 0.19, 9), (0.86, 0.40, 28)]:
        px, py = p(x, y)
        elipse_girada(img, px, py, u * 0.09, u * 0.12, ang, BRANCO)

    # Folha verde sobre a almofada, com nervura branca
    d = ImageDraw.Draw(img)
    fx, fy = p(0.5, 0.70)
    d.polygon(folha(fx, fy, u * 0.34, u * 0.17, -40), fill=FOLHA + (255,))
    a = math.radians(-40)
    meia = u * 0.12
    d.line(
        [(fx - meia * math.cos(a), fy - meia * math.sin(a)), (fx + meia * math.cos(a), fy + meia * math.sin(a))],
        fill=BRANCO + (255,),
        width=max(2, int(u * 0.009)),
    )
    return img.resize((tamanho, tamanho), Image.LANCZOS)


def icone(tamanho=1024) -> Image.Image:
    fundo = degrade(tamanho).convert("RGBA")
    fundo.alpha_composite(pegada(tamanho, 0.62))
    return fundo


def icone_arredondado(tamanho=1024) -> Image.Image:
    img = icone(tamanho)
    mascara = Image.new("L", (tamanho * ESCALA,) * 2, 0)
    ImageDraw.Draw(mascara).rounded_rectangle([0, 0, tamanho * ESCALA - 1, tamanho * ESCALA - 1], radius=tamanho * ESCALA * 0.22, fill=255)
    img.putalpha(mascara.resize((tamanho, tamanho), Image.LANCZOS))
    return img


def fonte(tamanho, negrito=True):
    nomes = ["segoeuib.ttf", "arialbd.ttf"] if negrito else ["segoeui.ttf", "arial.ttf"]
    for nome in nomes:
        try:
            return ImageFont.truetype(nome, tamanho)
        except OSError:
            continue
    return ImageFont.load_default()


def logo() -> Image.Image:
    """Ícone + "SOFUR" + descrição, fundo transparente."""
    alt = 360
    img = Image.new("RGBA", (1500, alt), (0, 0, 0, 0))
    img.alpha_composite(icone_arredondado(300), (30, 30))
    d = ImageDraw.Draw(img)
    d.text((380, 52), "SOFUR", font=fonte(190), fill=VERDE_ESCURO + (255,))
    d.text((388, 262), "Sistema de Ocorrências da Fauna Urbana", font=fonte(46, negrito=False), fill=(102, 117, 109, 255))
    return img.crop(img.getbbox())


if __name__ == "__main__":
    icone().convert("RGB").save(PASTA / "icone.png")
    icone_arredondado().save(PASTA / "icone_arredondado.png")
    pegada(1024, 0.50).save(PASTA / "icone_frente.png")  # zona segura do ícone adaptativo
    logo().save(PASTA / "logo.png")
    print("ok")
