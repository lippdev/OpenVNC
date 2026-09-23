# Prova de monitor virtual no Windows

Estado: diagnóstico preparado; nenhuma instalação executada. O usuário confirmou imagem, mouse, teclado, fullscreen, barras dinâmicas, troca de Spaces e uso da senha salva no cliente Mac.

## 1. Coletar o ambiente

Copiar `scripts/windows/Get-OpenVNCHostDiagnostics.ps1` para o Windows. Na sessão interativa, executar no PowerShell a partir da pasta do script:

```powershell
.\Get-OpenVNCHostDiagnostics.ps1 -OutputPath "$env:USERPROFILE\Desktop\openvnc-host.json"
```

O script apenas consulta versão do Windows, GPU, telas, drivers de display, serviço VNC, listeners conhecidos e interface Tailscale. Não lê senhas, screenshots, nomes de usuário, linhas de comando ou inventário de outros peers. O relatório contém IPs internos e topologia; revisar antes de compartilhar. Usa contexto DPI temporário somente na thread de diagnóstico e o restaura. O JSON não sobrescreve arquivo existente.

Ainda não foi executado neste Windows. Caso a política de execução bloqueie o script, registrar a mensagem e revisar a política aplicável; não é necessário desativá-la globalmente.

## 2. Candidato inicial

Consulta das releases upstream em 2026-09-23: a tag [25.7.23](https://github.com/VirtualDrivers/Virtual-Display-Driver/releases/tag/25.7.23) descreve um aplicativo de controle beta portátil, com drivers de vídeo e áudio que o mantenedor declara assinados. A página informa instalação manual para ARM64. A tag [25.5.2](https://github.com/VirtualDrivers/Virtual-Display-Driver/releases/tag/25.5.2) oferece instalador x64 e arquivos de instalação manual para x64 e ARM64. Nenhum desses artefatos foi baixado, verificado ou selecionado para este host: a escolha aguarda versão/arquitetura do Windows e inventário de drivers. A declaração upstream não substitui a validação da assinatura do artefato. O experimento OpenVNC requer somente vídeo; não instalar o driver de áudio incluído no pacote.

Avaliar [VirtualDrivers/Virtual-Display-Driver](https://github.com/VirtualDrivers/Virtual-Display-Driver). O projeto anuncia monitores virtuais e modos personalizados; o [LICENSE](https://github.com/VirtualDrivers/Virtual-Display-Driver/blob/master/LICENSE) declara MIT. Isso o torna um candidato para a prova, não uma dependência já aprovada para distribuição.

Antes de instalar, escolher uma release exata compatível com a versão/arquitetura do Windows, registrar URL e SHA-256 do artefato, verificar assinatura do instalador e catálogo do driver no Windows e documentar como remover o dispositivo/pacote específico. Não habilitar test signing nem desativar Secure Boot. A documentação upstream relata problemas possíveis com atualizações de GPU e reordenação de monitores; registrar o layout atual e ter acesso local para recuperação.

O [sample IDD da Microsoft](https://learn.microsoft.com/en-us/samples/microsoft/windows-driver-samples/indirect-display-driver-sample/) permanece referência de API, não instalador de produção.

## 3. Experimento após selecionar o artefato e autorizar a instalação

1. Registrar topologia original e seleção atual do TightVNC; manter um caminho de recuperação local.
2. Criar exatamente um monitor estendido e conservar resolução/posição dos displays físicos.
3. Anunciar 1920×1080 e o modo calculado pelo Mac, se suportado; registrar o modo realmente aplicado.
4. Selecionar somente o display virtual no TightVNC. Os comandos de seleção existem na [documentação oficial](https://www.tightvnc.com/doc/win/TightVNC_2.7_for_Windows_Server_Command-Line_Options.pdf), mas índices e persistência precisam ser conferidos na versão instalada. Não presumir que o display adicional é sempre o número 3.
5. Conectar pelo OpenVNC, verificar conteúdo em movimento e texto, comparar framebuffer com modo real, clicar numa grade e validar coordenadas.
6. Observar dez minutos, reconectar e alternar fullscreen/Spaces. Não chamar isso de benchmark definitivo.
7. Reverter seleção VNC e topologia; verificar janelas que estavam na tela virtual. Se houver falha de captura, restaurar o estado inicial.

## Critérios de decisão

- Captura preta/estática invalida a combinação VNC/driver, não necessariamente o driver. Comparar depois com WGC ou Sunshine em investigação separada.
- Modo solicitado deve ser aplicado no host; `scaleViewport` do cliente não comprova isso.
- Não automatizar criação/remoção remota antes de comprovar captura e restauração.
- Após a prova, implementar agente autenticado que gerencie somente o display que pertence à sessão OpenVNC. O VNC atual não fornece esse contrato.
