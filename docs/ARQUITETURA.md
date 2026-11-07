# Vigília do Musgo — nota técnica acadêmica

## Proposta e originalidade

O protótipo investiga como apresentar a mesma expedição idle em uma tela
completa e em uma pequena janela Android. O jogador escolhe uma de quatro
classes, acompanha combates automáticos, equipa achados, treina atributos e
resgata missões no Bosque. A área possui dez encontros e um chefe, com novos
ciclos de dificuldade após sua conclusão.

A inspiração é o conceito geral de RPG compacto que acompanha outras
atividades. A ambientação, os nomes, a interface, o código, os personagens,
os sprites e os sons foram criados para este projeto. Não há recursos
copiados de TBH: Task Bar Hero. O gerador reproduzível e as licenças estão em
[CREDITOS.md](CREDITOS.md).

## Separação de responsabilidades

| Camada | Arquivos principais | Responsabilidade |
|---|---|---|
| Domínio | `godot/scripts/core/rpg_engine.gd` | Combate, atributos, experiência, equipamento, missões e sorteio determinístico. |
| Dados | `godot/data/*.json` | Classes, inimigos, itens, raridades e missões configuráveis. |
| Sessão | `godot/scripts/core/game_session.gd` | Autoridade mutável, ações do jogador, relógio, pausa, retomada e autosave. |
| Persistência | `godot/scripts/core/save_store.gd` | Envelope versionado, checksum, arquivo temporário e recuperação. |
| Apresentação | `godot/scripts/presentation/` | Interface Godot, animação, feedback e áudio. |
| Plataforma | `godot/scripts/platform/` | Adaptador Android/desktop e cálculo de tempo decorrido. |
| Host Android | `android/app/src/main/java/br/edu/vigiliadomusgo/` | Activity Godot, permissões, serviço, janela nativa e seleção de quadros. |

O domínio avança em passos inteiros de um segundo. Sua máquina de estados
tem os estados `exploration`, `combat`, `victory` e `defeat`. Exploração
encontra um adversário; combate resolve ataques e habilidades; vitória
entrega recompensas e avança a etapa; derrota recupera o personagem no
abrigo. O gerador pseudoaleatório tem semente persistida: o mesmo estado e
a mesma sequência de ações produzem os mesmos resultados.

## Uma autoridade entre os dois modos

`GameSession` mantém o estado válido para alterações. Antes de abrir a
janela flutuante, salva um checkpoint e usa `RpgEngine.preview(300)` para
avaliar uma **cópia descartável** com a mesma função de combate. Essa cópia
gera 301 resumos: o instante inicial e os próximos 300 segundos. Ela não
concede recompensas à sessão naquele momento.

O Kotlin recebe somente esses resumos, o identificador de inicialização do
aparelho e a âncora de tempo. `Timeline` escolhe o quadro correspondente ao
tempo decorrido. O serviço não calcula dano, não sorteia itens, não altera
o inventário e não mantém outro motor de RPG. Ao retornar à tela completa,
o overlay é encerrado e a sessão avança desde o checkpoint pela mesma
regra determinística. Portanto, o que foi mostrado corresponde ao estado
recalculado no retorno, respeitada a precisão de um segundo.

```text
GameSession ── salva checkpoint ──► SaveStore
     │
     ├── RpgEngine.preview ──► quadros somente leitura ──► OverlayService
     │                                                   seleciona pelo tempo
     └── retorno + tempo decorrido ──► RpgEngine.advance ──► estado reconciliado
```

Essa escolha reduz trabalho contínuo em segundo plano, mas delimita o
protótipo: o overlay apresenta uma projeção determinística de até cinco
minutos e não permite equipar itens ou resgatar missões. Ações que mudam a
expedição pertencem à tela completa. Encerrar a janela não encerra a
progressão idle, que será calculada na próxima abertura.

A integração usa a biblioteca AAR e um `GodotPlugin` carregado pela
`GodotActivity`. A documentação da versão 4.5 permite incorporar Godot a
um aplicativo Android e alerta para uma única instância do motor por
processo e o tratamento explícito de mudanças de configuração. O Manifest
declara essas mudanças; sua robustez em rotação ainda exige teste em
aparelho. [Biblioteca Android do Godot 4.5](https://docs.godotengine.org/en/4.5/tutorials/platform/android/android_library.html).

## Tempo e persistência

No mesmo boot Android, a sessão usa `SystemClock.elapsedRealtime()`, que
inclui o tempo de suspensão e não acompanha ajustes no relógio civil.
[Referência de SystemClock](https://developer.android.com/reference/android/os/SystemClock).

Após reboot, ou entre processos desktop, existe fallback para diferença
de timestamps civis, limitado a duas horas; diferenças negativas não
concedem progresso. Não há servidor de tempo confiável nem proteção
contra adulteração intencional do aparelho ou dos saves. O limite reduz
erros e ganhos extremos, mas não equivale a um sistema antitrapaça.

O save reúne estado e âncora de tempo em um envelope com versão e SHA-256.
A gravação cria e verifica um temporário, preserva o arquivo anterior e
renomeia o resultado. Na leitura, cópias válidas podem recuperar uma
interrupção. Um formato futuro não é sobrescrito automaticamente. O
checksum detecta dano acidental, não autentica autoria. Sem sincronização
remota, desinstalação ou limpeza dos dados elimina a progressão local.

## Android e consumo de recursos

O início do overlay parte de um toque com a Activity visível, após
autorização explícita de `SYSTEM_ALERT_WINDOW`. A janela usa
`TYPE_APPLICATION_OVERLAY`, pode ser movida, redimensionada dentro dos
limites da tela e fechada. Há retorno seguro à experiência em tela completa
se permissões, relógio ou criação do serviço falharem.

O serviço declara `specialUse` no Android 14+, com a justificativa de
acompanhante de jogo visível, solicitado pelo usuário e limitado no tempo.
Esse enquadramento é uma proposta técnica do protótipo, não aprovação de
publicação: o caso de uso e sua descrição são avaliados no Google Play.
Não são declarados tipos de mídia, localização ou sincronização para
contornar restrições. [Tipos de foreground service](https://developer.android.com/develop/background-work/services/fgs/service-types#special-use).

O aplicativo inicia o serviço enquanto a Activity está visível; não
depende da exceção de início em segundo plano por sobreposição. No
Android 15+, essa exceção exige uma janela efetivamente visível. Não há
reinício automático no boot nem tentativa de reabrir uma janela fechada
pelo usuário. [Restrições de início de serviços](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start).

O Canvas nativo atualiza aproximadamente uma vez por segundo, com base no
relógio, sem loop de renderização a 60 FPS. Apagar a tela encerra o serviço;
ele também termina ao fechar a janela, expirar a projeção ou perder a
permissão. Não se usa wakelock nem AccessibilityService. Os quadros omitem
o inventário completo, o payload tem limite de 2 MB e trafega por arquivo
privado, evitando um grande argumento Binder. O JSON ocupa memória
adicional após decodificação; o teto do payload não é um teto de heap.
Consumo de CPU, memória, energia e comportamento de fabricantes precisam
ser medidos em dispositivo.

## Diferenças entre desktop e mobile

| Aspecto | Desktop Godot | Android |
|---|---|---|
| Entrada e layout | Mouse e janela redimensionável. | Toque, retrato/paisagem, densidade e recortes de tela. |
| Janela compacta | Janela comum; sem integração com barra de tarefas. | Overlay nativo sujeito a consentimento e restrições do sistema. |
| Ciclo de vida | Foco da janela e encerramento do processo. | Activity, serviço, tela apagada e possível descarte pelo sistema. |
| Tempo | Monotônico durante o processo; civil entre sessões. | Monotônico entre sessões no mesmo boot; fallback após reboot. |
| Energia | Apresentação Godot limitada a 30 ou 15 FPS. | Mesmo limite em tela completa; overlay a aproximadamente 1 Hz. |

O escopo é um protótipo local de uma área. Balanceamento prolongado,
acessibilidade completa, migrações futuras, nuvem e publicação em loja
ficam para evolução. Resultados realmente executados constam em
[VALIDACAO.md](VALIDACAO.md); o roteiro de dispositivo está em
[TESTES_MANUAIS.md](TESTES_MANUAIS.md). A presença de código ou de um APK
não substitui a validação do overlay em Android real.
