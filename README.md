# OpenVNC

Cliente nativo de macOS para usar um Windows remoto em um monitor virtual adaptado ao Mac, com fullscreen e troca de Spaces pelos gestos do sistema.

Projeto em desenvolvimento inicial. A primeira entrega prepara o cliente e o contrato de sessão; streaming e criação do monitor virtual ainda não estão implementados.

## Arquitetura

- **SwiftUI + AppKit:** interface e integração com o Mac.
- **Rust:** núcleo compartilhado, acessível por uma interface C pequena.
- **Windows:** futuro agente para autorização e gestão de display; driver existente a selecionar.
- **Tailscale:** conectividade inicial, configurada pelo usuário. Sem serviço de nuvem próprio.

Veja [a arquitetura e o plano inicial](docs/architecture.md) e [as regras de contribuição](CONTRIBUTING.md).

## Compilar no Mac

Requisitos: macOS 13+, ferramentas de desenvolvimento Apple com Swift 5.9+ e Rust/Cargo (edition 2021). A compilação usa somente dependências locais e ferramentas do sistema.

```sh
bash scripts/build-macos.sh
open dist/OpenVNC.app
```

O script compila Rust, liga a biblioteca estática ao cliente Swift e gera um `.app` com assinatura ad hoc para desenvolvimento local. Não é um pacote notarizado para distribuição. `swift build` isolado não inclui a biblioteca Rust; use o script.

O app permite informar IP/nome Tailscale, preparar resolução e escala para a tela atual e entrar em fullscreen nativo. A preparação é local: não verifica disponibilidade do host nem cria um monitor. O endereço informado fica salvo nas preferências locais; não são solicitadas credenciais.

## Licença

A intenção é distribuir como open source. A licença será definida após a seleção dos componentes de vídeo/driver e antes da primeira distribuição; nenhuma licença de terceiros é presumida neste scaffold.
