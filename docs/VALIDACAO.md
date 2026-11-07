# Relatório de validação — 6 de novembro de 2026

## Resultado e alcance

O protótipo foi executado no Godot 4.5.1 e compilado para Android. Não houve
aparelho conectado ao ADB; nenhum teste de serviço, permissão, rotação ou toque em
Android real foi declarado como concluído. As capturas de retrato e paisagem
vieram da execução gráfica do projeto no desktop, com OpenGL Compatibility.

| Verificação executada | Resultado |
|---|---|
| Núcleo GDScript (`test_runner.gd`) | 95 assertivas aprovadas, zero falhas. |
| Sessão real com ponte/relógio controlados (`test_session.gd`) | 43 assertivas aprovadas, zero falhas. |
| Testes JVM Kotlin | 10 testes aprovados: Timeline 6, WindowBounds 4; zero falhas/erros. |
| Importação e execução headless do projeto | Scripts carregados sem erros. |
| Exportação de `game.pck` e execução isolada com `--main-pack` | Sucesso; nenhum erro de script/recurso no smoke test. |
| Layout gráfico | Retrato e paisagem abertos e inspecionados; capturas incluídas. |
| Arte e som | Regeneração idêntica, dimensões/transparência PNG, PCM WAV e amplitude conferidos. |
| Build Android | `testDebugUnitTest lintDebug assembleDebug`: BUILD SUCCESSFUL. |
| Lint Android | Zero erros, 26 avisos; detalhes abaixo. |
| Validação em dispositivo | Não executada; `adb devices -l` retornou lista vazia. |

São **138 assertivas Godot e 10 casos de teste JVM**. As assertivas não representam
138 cenários independentes. Os testes verificam replay determinístico, os 301
quadros da projeção contra a mesma função de combate, quatro classes vencendo o
chefe, limite de idle, evolução por duas horas, inventário, equipamento, derrota,
missões e recompensas sem duplicação. Persistência inclui temporário, checksum,
backup, arquivo corrompido, formatos futuros e arquivamento explícito para reset.

Os testes de sessão incluem pausa/resume/foco duplicado, checkpoint antes do
overlay, bloqueio de mutações, falha de abertura, consentimento simulado e
restauração de FPS. A seleção de quadros em Kotlin testa bordas de segundo,
regressão temporal, boot divergente e payload inválido. A geometria inclui telas
pequenas e mil combinações de arraste/redimensionamento.

## Ambiente e procedimentos

- Godot 4.5.1 Standard já disponível; AAR `org.godotengine:godot:4.5.1.stable`.
- JDK 21; Android SDK 36; Build Tools 35.0.0; Gradle 8.11.1; AGP 8.10.1; Kotlin 2.1.20.
- Ferramentas ausentes foram baixadas para `work/android-tools` após autorização.
- Gradle utiliza heap de 1,5 GB e dois workers para este ambiente com pouca RAM.
- Caches, SDK, dados de teste e chave debug ficaram fora do repositório.
- Inicialmente a sandbox bloqueou sockets de editor/Gradle/ADB e a sessão gráfica.
  Foi usada execução autorizada para os processos que precisam desses recursos.
  O exportador headless registrou falhas de socket do editor; o PCK exportado foi
  depois executado isoladamente sem erro de script/recurso.
- O APK é debug, com duas ABIs e bibliotecas nativas sem strip; não é um build
  otimizado para distribuição em loja. A assinatura é de desenvolvimento.

Comandos reproduzíveis estão no [README](../README.md). Logs de trabalho ficaram
fora do repositório; os relatórios Android são reproduzidos pelo Gradle em
`android/app/build/reports/` e `android/app/build/test-results/`. Não foram
publicados logs que contenham caminhos de credenciais ou chaves.

## Limitações que permanecem

- Integração nativa compilada, mas ainda sem comprovação em aparelho. Executar
  [TESTES_MANUAIS.md](TESTES_MANUAIS.md) antes de apresentar o overlay como validado.
- Overlay finito de cinco minutos, sem ações que mudem a expedição; renderização
  aproximada de 1 Hz. Fecha ao apagar a tela, retornar ao jogo ou por restrição.
- `specialUse` tem justificativa declarada; não houve submissão nem aprovação da
  Google Play. Fabricantes podem recusar ou ocultar overlays.
- Tempo civil após reboot é limitado, mas não autenticado por servidor. Checksum
  protege contra corrupção acidental, não contra edição deliberada do save.
- O jogo é local; sem backup/nuvem. Desinstalar ou limpar dados apaga progresso.
- Balanceamento de longo prazo, consumo real de bateria e acessibilidade completa
  não foram avaliados. O conteúdo é uma área com dez encontros e um chefe.

## Git e GitHub

Commits separados para núcleo/arte, interface/sessão, Android e documentação.
A autenticação CLI foi confirmada depois de permitir o acesso de rede; o erro
inicial da sandbox não era uma credencial inválida. O repositório remoto foi
verificado antes da criação, sem sobrescrever repositórios existentes.

Repositório público criado e branch `main` enviada com sucesso:
[github.com/mhacks-cloud/idle-rpg-mobile](https://github.com/mhacks-cloud/idle-rpg-mobile).
A API do GitHub confirmou visibilidade pública e branch padrão `main`. Não foram
enviados APKs, SDKs, caches, chave debug, saves ou credenciais ao Git.

## Artefato final e lint

- APK debug: `idle-rpg-mobile-debug.apk`, entregue fora da pasta dos fontes.
- Tamanho: **149.062.761 bytes** (aproximadamente 142,2 MiB).
- SHA-256: `a6a13559683da86acda9b56412011f8d5d5ba504a7e03feeaa5323d1d8fdb677`.
- ABIs verificadas no ZIP: `arm64-v8a` e `x86_64`.
- `assets/game.pck` dentro do APK é idêntico ao pacote final executado no smoke test.
- Cinco arquivos de licença/notice presentes dentro de `assets/licenses/`.
- `apksigner verify --verbose`: assinatura v2 válida, um signatário debug.
- `zipalign -c -P 16 4`: terminou com código 0. Isso verifica alinhamento do APK;
  não substitui execução em dispositivo com páginas de memória de 16 KiB.
- Build final após ajustes de manifesto: `lintDebug assembleDebug`, sucesso em
  52 segundos, 46 tarefas (13 executadas, 33 atualizadas).

O lint terminou com **0 erros e 26 avisos**: nove sugestões de KTX, nove avisos
sobre textos PT-BR embutidos no renderer nativo, três avisos de versão de
ferramentas/dependências, três `ImplicitSamInstance` nas chamadas Android
`stopService(Intent)` (inspecionadas: o argumento é Intent, não listener SAM),
um sobre `fullUser` e um sobre `Gravity.LEFT` usado para coordenadas físicas de
arraste. Não foram suprimidos em massa. Internacionalização e refinamento de
form factors são evoluções; comportamento em dispositivo continua pendente.
O aviso de extração de dados foi corrigido com configuração explícita de backup
para versões anteriores ao Android 12 e regras de extração para Android 12+.

A chave de assinatura debug permaneceu apenas no diretório local de ferramentas,
nunca nos fontes ou no ZIP. O ZIP de fontes contém arquivos versionados e não
inclui caches de build, o APK ou o histórico `.git`; o histórico está no
repositório Git local e no GitHub.
