# Host Android de Vigília do Musgo

Kotlin 2.1.20, Android Gradle Plugin 8.10.1, Gradle 8.11.1, Godot Android AAR
4.5.1.stable. JDK 17 ou 21, SDK 36, Build Tools 35.0.0; Android 8/API 26 ou
superior, OpenGL ES 3. Arquiteturas arm64-v8a e x86_64. O target é API 36.

O jogo é exportado pelo projeto Godot para `app/src/main/assets/game.pck`.
`MainActivity`, uma subclasse de `GodotActivity`, carrega esse pacote. O
`getHostPlugins()` registra uma única instância do plugin `IdleBridge`.

```sh
# A partir da raiz do repositório: exporte o pacote conforme o README principal.
cd android
export ANDROID_HOME=/caminho/para/android-sdk
./gradlew testDebugUnitTest lintDebug assembleDebug
# Resultado: app/build/outputs/apk/debug/app-debug.apk
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

O build debug usa a assinatura de desenvolvimento padrão do Android. Não distribua
essa chave, não a use para publicação e não versione `local.properties`, chaves,
SDKs, caches Gradle ou APKs. Nenhum segredo é necessário para compilar.

## Contrato de integração

O singleton Godot se chama `IdleBridge` e expõe:

| Método | Retorno/efeito |
|---|---|
| `clock_json()` | JSON `{wall, mono, boot}`; segundos decimais. `mono` vem de `elapsedRealtime`; `boot` de `BOOT_COUNT`. |
| `can_overlay()` | Consentimento `Settings.canDrawOverlays`. |
| `request_overlay_permission()` | Abre configurações por gesto explícito; se SAW já autorizada, solicita notificações. |
| `start_overlay(json)` | Valida a linha do tempo e inicia o serviço apenas com Activity RESUMED. |
| `stop_overlay()` | Encerra serviço/janela. |
| `is_overlay_active()` | Verdadeiro somente após `WindowManager.addView` funcionar. |
| `status_json()` | `{state,message}`, com state idle/starting/active/error/closed. |

Payload aceito por `start_overlay`:

```json
{"version":1,"clock":{"wall":1.0,"mono":100.25,"boot":"7"},"duration":300,"frames":[]}
```

`frames` contém exatamente `duration + 1` snapshots: frame zero é o estado no
instante `clock`; cada frame seguinte é o resultado de um tick do motor GDScript.
O payload acima ilustra o formato, mas a lista vazia é intencionalmente rejeitada.
Limite de 2 MB e duração máxima de 300 segundos. O app salva um arquivo privado
temporário e renomeia antes de iniciar o serviço, evitando o limite de Binder.

O motor GDScript congela no checkpoint persistido enquanto o modo flutuante está
ativo. Somente ele calcula combate, RNG, inventário e recompensas. O Kotlin **não
simula RPG**: seleciona o snapshot pelo relógio monotônico. Ao voltar, o GDScript
reconcilia exatamente os ticks decorridos com a mesma função de combate. O preview
é imutável e descartável; o serviço não salva progressão. O serviço não recebe
comandos de equipamento nem de missões para não invalidar a linha do tempo.

## Serviço e restrições

- `SYSTEM_ALERT_WINDOW` só é usado após consentimento nas configurações.
- API 33+: este protótipo exige permissão de notificação para manter um controle
  de fechamento visível. Negação preserva tela completa; nova tentativa é explícita.
- `TYPE_APPLICATION_OVERLAY`; janela arrastável, redimensionável e limitada às
  barras/cutouts. O menu oferece abrir jogo e fechar; a notificação também oferece
  fechar. O teclado e outros apps não são controlados.
- `specialUse` (API 34+) descreve uma janela de jogo visível e solicitada pelo usuário.
  Não se declara `dataSync`, `mediaPlayback`, `shortService` ou `systemExempted`.
  `specialUse` não é aprovação de publicação: distribuição na Play Store exige
  justificar e submeter o uso à análise do Google Play.
- O serviço é iniciado apenas a partir da Activity visível. Não se depende da
  exceção de SAW para início em segundo plano, restringida no Android 15.
- Nenhum AccessibilityService, captura de tela, leitura de apps, wakelock, boot
  receiver, alarme exato, tentativa de ignorar Doze ou pedido de desativação de
  otimização de bateria. `START_NOT_STICKY`, `stopWithTask=true`.
- Atualização nativa no máximo uma vez por segundo. Tela desligada encerra a
  janela. Ao retornar à Activity, fechar tarefa, revogar permissão ou atingir cinco
  minutos, o serviço termina. Não há renderizador Godot no serviço.
- Fabricantes podem impedir overlays; telas sensíveis de outros apps podem
  escondê-los. Exceções e relógio/boot inválido geram fallback para tela completa.
- Perda do processo nunca exige recuperar o preview: recuperar checkpoint e
  cálculo idle limitado é responsabilidade do jogo. Depois de reiniciar aparelho,
  o preview antigo é inválido.

## Validação

`TimelineTest`: fronteiras de segundos, seleção exata de frame, reboot/regressão,
payload incompleto, limite de duração e ausência de boot ID.
`WindowBoundsTest`: arraste além dos limites, resize, tela pequena e mil casos
aleatórios de geometria. Essas são provas de lógica pura, não testes de serviço
ou permissão em dispositivo. Consulte o relatório principal para o resultado
real do build e o checklist de validação física.

Referências oficiais consultadas na implementação:

- [Godot Android library](https://docs.godotengine.org/en/4.5/tutorials/platform/android/android_library.html)
- [GodotActivity 4.5.1](https://github.com/godotengine/godot/blob/4.5.1-stable/platform/android/java/lib/src/org/godotengine/godot/GodotActivity.kt)
- [Tipos de foreground service](https://developer.android.com/develop/background-work/services/fgs/service-types)
- [Restrições de início em segundo plano](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start)
- [Mudanças Android 15](https://developer.android.com/about/versions/15/behavior-changes-15)
