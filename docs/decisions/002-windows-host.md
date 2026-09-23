# ADR-002: primeiro incremento do Windows Host

Estado: implementação de diagnóstico; validação na máquina do usuário pendente.

## Decisão

Distribuir um executável portátil x64 em Rust, com controles nativos Win32, antes
do instalador permanente e da gestão de displays. Reutilizar o diagnóstico
PowerShell somente de leitura, incorporado no executável, com saída JSON e
timeout. Executar na sessão do usuário sem elevação, sem alterar políticas de
execução, serviços, firewall ou drivers.

O código não recebe comandos remotos, não abre listener e não apresenta botão
de pareamento sem implementação. A senha VNC não é necessária ao diagnóstico.
O relatório é compartilhado manualmente. Os avisos distinguem coleta parcial
de sucesso; sua ausência não prova compatibilidade com um futuro driver.

`windows-sys` 0.61.2 usa MIT/Apache-2.0 e fornece bindings da Microsoft; `serde_json`
1.0.145 usa MIT/Apache-2.0 e valida a estrutura JSON antes de apresentá-la. Lockfile
fixa dependências transitivas. Os textos upstream acompanham o pacote em
`THIRD-PARTY-NOTICES.txt`. Nenhuma dependência inclui driver de display.

## Limitações

- Windows PowerShell 5.1 e permissão para executar o script local são necessários.
- O pacote não é assinado com Authenticode nem é uma release de produção.
- A janela usa layout fixo com virtualização DPI padrão do Windows; alta escala,
  leitor de tela, múltiplos monitores e fontes devem ser validados no host real.
- O app precisa aguardar a coleta encerrar para fechar (máximo de 60 segundos).
- Não há instalação, bandeja, autostart, pareamento, monitor virtual ou captura.

## Próximo incremento

Obter o relatório da máquina alvo, avaliar uma versão específica do driver e
validar captura/restauração com autorização para instalação. Projetar pareamento
com aprovação local, identidade própria, credenciais protegidas e revogação
antes de adicionar qualquer comando remoto que altere a topologia.
