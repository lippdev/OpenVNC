# OpenVNC Host — diagnóstico

Primeira versão portátil para Windows 10/11 x64. Extraia o pacote inteiro e abra
`OpenVNC-Host.exe` na sessão local ou na sessão VNC existente, como usuário normal.
O executável de desenvolvimento ainda não tem assinatura Authenticode. Respeite
as políticas de segurança do computador; não desative proteções para executá-lo.

1. Clique em **Coletar diagnóstico** e aguarde até 60 segundos.
2. Confira o resumo e os avisos no JSON mostrado na janela.
3. Clique em **Abrir pasta do relatório** para copiar `openvnc-host.json` ao Mac.

Cada coleta salva um arquivo separado em `%LOCALAPPDATA%\OpenVNC\Reports`, sem
sobrescrever relatórios anteriores. O relatório contém IPs internos e topologia
das telas. Não é enviado automaticamente a nenhum serviço. Feche o app após a
coleta; ele não permanece na bandeja nem inicia com o Windows.

O diagnóstico usa Windows PowerShell 5.1, presente no Windows, e respeita a política
de execução de scripts. Caso a política bloqueie a coleta, a UI informa falha;
nenhuma política é alterada. Dados indisponíveis são registrados como avisos.
Não execute via RDP se quiser medir a topologia usada pelo VNC.

Esta entrega não abre portas, não instala drivers, não cria monitores e não
implementa pareamento ou captura. O TightVNC/websockify existente continua sendo
o caminho de vídeo e controle. O próximo marco é analisar o relatório do host,
selecionar o driver e depois implementar autorização e gestão de display.

## Compilar

No Windows x64, com Rust MSVC e Visual Studio Build Tools (C++/Windows SDK):

```powershell
.\scripts\build-windows-host.ps1
```

O GitHub Actions também compila e disponibiliza um artefato com executável,
licenças e SHA-256. Uma compilação no runner não comprova a coleta na máquina do
usuário. Nenhum teste automatizado ou instalação de driver faz parte do workflow.

## Implementação e licenças

Janela Win32 em Rust (`windows-sys`), coleta PowerShell incorporada no executável,
processo de coleta em uma thread separada, timeout e visualização JSON. O script
temporário é removido ao concluir; o relatório fica disponível para exportação.
Código próprio MIT. Dependências e seus avisos estão em `THIRD-PARTY-NOTICES.txt`.
