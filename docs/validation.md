# Validação da fundação — 2026-09-23

- Ambiente: Mac arm64, Swift 6.4, Cargo 1.98.1.
- `cargo build --offline`: passou, sem dependências externas.
- `bash scripts/build-macos.sh`: passou; cliente Swift ligado à biblioteca Rust e bundle `dist/OpenVNC.app` gerado com assinatura ad hoc.
- `git diff --check`: passou.
- Não foram executados testes automatizados nem validação visual/interativa.
- A compilação precisou de acesso ao cache de módulos do Swift fora do sandbox de execução do agente.

## Validação manual pendente

Abrir o app, informar IP/nome Tailscale e preparar a configuração. Conferir a tela reportada, mover a janela entre telas com escalas diferentes e preparar novamente. Entrar em fullscreen e alternar Spaces pelos gestos configurados no macOS. Verificar rejeição de URL, porta embutida e endereço inválido.

A versão atual não conecta ao Windows; estas verificações não demonstram streaming, autorização, criação de monitor ou compatibilidade com um driver. Isso pertence aos marcos seguintes. Compatibilidade com macOS 13 e Macs Intel ainda não foi validada.
