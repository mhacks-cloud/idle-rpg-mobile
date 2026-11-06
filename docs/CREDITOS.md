# Créditos e originalidade

**Vigília do Musgo** é um protótipo acadêmico original. O conceito de um RPG
idle compacto é uma referência de gênero; nomes, ambientação, personagens,
layout, código, gráficos e áudio deste projeto não foram extraídos de
**TBH: Task Bar Hero** nem de outro jogo.

## Arte e sons do projeto

Todos os arquivos PNG e WAV em `godot/assets/` são produzidos exclusivamente
por `tools/generate_assets.py`, escrito para este projeto. Não há imagens de
referência incorporadas, fontes de pixel art externas, amostras de áudio,
sprites baixados ou recursos de terceiros misturados às imagens.

- **Personagens:** guerreiro com escudo-lanterna, arqueiro de capuz, mago com
  cristal e curandeiro com cajado de folhas.
- **Criaturas:** Gota errante (`dew_slime`), Carrapicho (`bark_mite`),
  Mariposa-lume (`lantern_moth`) e Ancião do Emaranhado (`root_guardian`).
- **Ambiente:** bosque noturno, clareira, cogumelos e lanterna, desenhados em
  uma grade inteira de pixels.
- **Áudio:** um efeito curto de ataque e um arpejo de vitória, sintetizados
  matematicamente em PCM mono de 22.050 Hz e 16 bits. Não contêm gravações.
- **Ícone:** lanterna cercada por duas folhas, desenhada em 64 × 64 pixels.

Os recursos gráficos e sonoros gerados são disponibilizados sob
**CC0 1.0 Universal**. O autor renuncia a direitos autorais na máxima extensão
permitida pela lei; a dedicação não se aplica a marcas de terceiros.
Texto legal: <https://creativecommons.org/publicdomain/zero/1.0/legalcode.pt>.
O código do gerador segue a licença MIT do projeto.

## Reprodução

Com Python 3 e Pillow instalados:

```sh
python3 tools/generate_assets.py
```

Pillow é necessário apenas para regenerar os arquivos, não para executar o
jogo. O gerador usa uma semente fixa (`417203`) e não acessa a rede.
`godot/assets/manifest.json` registra os hashes SHA-256 dos recursos para
permitir verificar sua origem e integridade.

Cada folha de personagem possui quatro quadros de **24 × 24 pixels** na
horizontal, formando um PNG transparente de **96 × 24 pixels**: repouso,
passo, ataque e recuperação. Use filtragem *nearest* e escala inteira sempre
que o espaço disponível permitir. O bosque mede **640 × 240 pixels**.

## Ferramentas e dependências

- **Godot Engine:** licença MIT; ver <https://godotengine.org/license/>.
- **Kotlin:** Apache License 2.0; ver <https://kotlinlang.org/>.
- **AndroidX e Android Gradle Plugin:** licenças incluídas nos respectivos
  pacotes, predominantemente Apache License 2.0.
- **Pillow:** HPND; usado somente como ferramenta de geração dos PNG.

As bibliotecas mantêm seus próprios titulares e licenças. O projeto utiliza
as fontes padrão das plataformas; nenhum arquivo de fonte foi copiado.
O histórico Git registra a autoria técnica da implementação; o estudante
deve identificar na entrega acadêmica a assistência de IA conforme as
regras de sua instituição.
