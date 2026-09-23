# OpenVNC

Cliente nativo de macOS para usar um Windows remoto em um monitor virtual adaptado ao Mac, com fullscreen e troca de Spaces pelos gestos do sistema.

Projeto em desenvolvimento inicial. A primeira entrega prepara o cliente e o contrato de sessão; streaming e criação do monitor virtual ainda não estão implementados.

## Arquitetura

- **SwiftUI + AppKit:** interface e integração com o Mac.
- **Rust:** núcleo compartilhado, acessível por uma interface C pequena.
- **Windows:** futuro agente para autorização e gestão de display; driver existente a selecionar.
- **Tailscale:** conectividade inicial, configurada pelo usuário. Sem serviço de nuvem próprio.

Veja [a arquitetura e o plano inicial](docs/architecture.md) e [as regras de contribuição](CONTRIBUTING.md).

## Licença

A intenção é distribuir como open source. A licença será definida após a seleção dos componentes de vídeo/driver e antes da primeira distribuição; nenhuma licença de terceiros é presumida neste scaffold.
