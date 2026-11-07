# Roteiro de testes manuais em dispositivo

**Estado inicial deste roteiro: não executado.** As caixas abaixo são
critérios de aceitação, não declarações de sucesso. Registrar modelo,
versão Android, ABI, hash do APK, data, resultado e evidência por execução.
Resultados do ambiente de desenvolvimento pertencem a
[VALIDACAO.md](VALIDACAO.md).

## Preparação

- [ ] Usar uma instalação de teste; anotar se há progresso que deve ser preservado.
- [ ] Instalar o APK debug produzido pelo build documentado no README.
- [ ] Registrar `adb devices`, `adb shell getprop ro.build.version.sdk` e `adb shell getprop ro.product.cpu.abi`.
- [ ] Testar pelo menos API 26/28, API 33, API 34 e API 35/36, conforme dispositivos/emuladores disponíveis.
- [ ] Incluir um aparelho físico arm64, além de emulador x86_64 se disponível. A configuração inicial inclui essas duas ABIs; não presume suporte armv7.
- [ ] Incluir tela pequena, tablet ou janela ampla, navegação por gestos, recorte de câmera e fonte do sistema ampliada.
- [ ] Capturar logs com `adb logcat -v time` durante cada falha; anotar passos exatos e evitar incluir dados de outros aplicativos na evidência.

## Primeira abertura e tela completa

- [ ] A primeira execução abre o tutorial em português, sem pedir permissões de overlay antes de uma ação explícita.
- [ ] Guerreiro, arqueiro, mago e curandeiro iniciam uma expedição válida, com aparência, atributos e habilidade próprios.
- [ ] Confirmar a criação de uma nova expedição pelo fluxo apresentado; conferir que não ocorre reset por toque acidental em uma classe.
- [ ] O personagem alterna exploração, combate, vitória e derrota sem precisar de toques para atacar.
- [ ] As animações e os sons correspondem aos eventos; pixels permanecem nítidos, sem depender de recursos externos.
- [ ] XP, nível, vida, sementes, etapa e cooldown mudam de forma coerente; o nível sobe após atingir a experiência exigida.
- [ ] Chegar à etapa do chefe Ancião do Emaranhado; confirmar identificação visual e recompensas após vitória.
- [ ] Confirmar que derrota permite recuperação e continuação, sem remover equipamentos já conquistados.
- [ ] Trocar equipamento altera os atributos; tentar equipar repetidamente não duplica o bônus.
- [ ] Obter itens de raridades distintas; preencher a mochila e verificar a conversão do excedente em sementes, sem crescimento ilimitado.
- [ ] Treinar consome o custo exibido e aumenta o ataque; saldo insuficiente não permite compra nem saldo negativo.
- [ ] Uma missão incompleta não permite resgate; uma concluída entrega a recompensa uma única vez, inclusive após reabrir o aplicativo.
- [ ] Alternar som e economia de bateria; reiniciar e conferir que as escolhas são preservadas.
- [ ] Em retrato e paisagem, textos e botões continuam acessíveis, com rolagem quando necessária. O conteúdo não fica sob barras ou recortes.
- [ ] Girar dez vezes durante combate, tutorial e inventário: não há segunda instância do jogo, reset, tela preta permanente ou travamento.

## Consentimento e fallback

- [ ] Tocar em **Janela flutuante** abre a autorização apropriada do Android quando ela ainda não existe.
- [ ] Negar a sobreposição mantém a sessão jogável em tela completa e não cria janela ou serviço persistente.
- [ ] Conceder a sobreposição e retornar não abre o overlay automaticamente: o usuário confirma a intenção tocando novamente no botão.
- [ ] No Android 13+, negar notificações mantém o fallback em tela completa; conceder e tentar novamente permite continuar o fluxo.
- [ ] Desabilitar o canal de notificação pelo sistema e registrar o comportamento real, incluindo a indicação de serviço em execução fornecida pelo Android.
- [ ] Em aparelho sem suporte a sobreposição para este app, conferir a mensagem e a continuidade do modo tela completa.
- [ ] A tentativa de início interrompida por Home ou bloqueio da tela não provoca crash nem serviço invisível duradouro.
- [ ] Nenhuma tela solicita AccessibilityService, captura de tela, controle de outros aplicativos ou dispensa de otimização de bateria.

## Janela flutuante

- [ ] A janela aparece sobre outro aplicativo depois do consentimento; existe uma notificação de serviço com ação para fechar.
- [ ] A representação mostra a classe, vida, nível, XP, sementes, etapa e eventos da expedição selecionada.
- [ ] Arrastar pelo cabeçalho move a janela sem executar botões por acidente.
- [ ] Redimensionar pelo controle inferior respeita os limites e mantém os controles de fechar/abrir acessíveis.
- [ ] Arrastar para todas as bordas, inclusive após rotação, não perde a janela fora da área útil.
- [ ] Tocar fora da janela permite usar o aplicativo abaixo; o overlay não recebe nem injeta ações nele.
- [ ] Abrir um diálogo protegido do sistema pode ocultar ou bloquear o overlay; o jogo respeita essa decisão e continua depois sem contorná-la.
- [ ] Fechar pelo botão × remove janela e notificação; conferir em `adb shell dumpsys activity services br.edu.vigiliadomusgo` que o serviço terminou.
- [ ] Fechar pela notificação produz o mesmo resultado.
- [ ] Abrir pelo botão ↗ e pela notificação retorna à única Activity existente e encerra o overlay.
- [ ] A projeção termina ao alcançar cerca de cinco minutos, com precisão de atualização de um segundo; uma nova janela exige abrir o jogo e solicitar outra sessão.
- [ ] Apagar a tela encerra a janela e o serviço. Desbloquear não os reabre automaticamente.
- [ ] Remover a tarefa dos recentes encerra o serviço; reiniciar o aparelho não inicia nada automaticamente.
- [ ] Revogar a sobreposição enquanto a janela está ativa encerra o serviço sem crash. Retornar ao jogo conserva a sessão.

## Coerência entre os modos

- [ ] Anotar classe, etapa, nível, moedas, XP e número de encontros antes da transição. Permanecer 20–40 segundos no overlay e retornar: progressão coerente, sem reinício ou ganho duplicado.
- [ ] Repetir a transição imediatamente antes de vitória, derrota, mudança de nível e encontro do chefe.
- [ ] Fazer cinco alternâncias rápidas; conferir que há no máximo uma janela e uma sessão mutável.
- [ ] Fechar o overlay e esperar antes de abrir o jogo: o tempo restante é reconciliado uma única vez.
- [ ] Comparar o último quadro visível com o estado após retorno, admitindo apenas o tempo real transcorrido entre as duas observações.
- [ ] O overlay não permite equipar itens, treinar ou resgatar missões; ao retornar, essas ações ficam novamente disponíveis.
- [ ] Simular processo encerrado pelo sistema usando as ferramentas de teste disponíveis. A abertura seguinte carrega o checkpoint e calcula o tempo; não aplica recompensas previstas duas vezes.

## Persistência e relógio

- [ ] Usar **Salvar agora**, fechar e reabrir; classe, inventário, atributos, missões e opções persistem.
- [ ] Deixar o jogo ativo por mais de 15 segundos e encerrar abruptamente a instalação de teste: o autosave anterior permite recuperação.
- [ ] Colocar em segundo plano por 30 segundos, cinco minutos e mais de duas horas: o avanço respeita o limite de 7.200 segundos por reconciliação.
- [ ] Alterar o relógio civil no mesmo boot durante uma sessão de teste: no Android, o tempo monotônico deve impedir ganho equivalente à alteração artificial.
- [ ] Reiniciar o aparelho entre sessões e conferir o fallback limitado; voltar o relógio civil não produz progresso negativo ou reversão de conquistas.
- [ ] Em fixtures de teste, invalidar o checksum do save principal e manter backup válido: confirmar recuperação e aviso visível.
- [ ] Em fixtures, invalidar todos os saves: confirmar aviso e preservação dos originais, sem alegar recuperação inexistente.
- [ ] Abrir fixture de versão futura: não sobrescrever automaticamente com o formato atual.
- [ ] Simular falha de escrita ou pouco espaço em armazenamento de teste: avisar o jogador, manter o estado em memória e permitir nova tentativa.

Use fixtures e uma instalação separada para falhas de armazenamento. Não
altere saves pessoais para executar esses casos. O caminho de `user://`
depende da plataforma; localize-o na instalação debug antes de preparar
qualquer fixture. Não se presume que o checksum seja uma assinatura contra
adulteração deliberada.

## Energia, desempenho e encerramento

- [ ] No profiler, medir CPU/memória durante tela completa e overlay; registrar valores, dispositivo e duração, sem inferir autonomia somente pela taxa de atualização.
- [ ] Confirmar que o overlay redesenha aproximadamente a 1 Hz e não mantém loop gráfico contínuo em segundo plano.
- [ ] Medir a preparação de 301 quadros e o retorno após duas horas idle em aparelho de menor desempenho; não deve haver ANR.
- [ ] Abrir e fechar o overlay vinte vezes; memória retida não cresce continuamente e não restam Views, callbacks ou notificações órfãs.
- [ ] Ativar economia de bateria do Android: aceitar encerramento pelo sistema e recuperar a sessão ao retornar, sem tentar forçar reinício.
- [ ] Após fechar janela ou apagar tela, confirmar ausência de wakelock do aplicativo e término do serviço.
- [ ] Repetir os casos essenciais em ao menos dois fabricantes, se disponíveis; registrar diferenças de permissão e gerenciamento de tarefas.

## Registro de execução

| Caso ou grupo | Aparelho / API / ABI | Resultado | Evidência / observação |
|---|---|---|---|
| Primeira abertura e combate | — | Não executado | — |
| Permissões e fallback | — | Não executado | — |
| Overlay e ciclo de vida | — | Não executado | — |
| Reconciliação de estado | — | Não executado | — |
| Persistência e relógio | — | Não executado | — |
| Energia e memória | — | Não executado | — |

Só marcar um caso como aprovado após executar os passos e conferir seu
resultado. Falhas devem registrar a menor sequência reproduzível, logs
relevantes e se o modo tela completa permaneceu utilizável.
