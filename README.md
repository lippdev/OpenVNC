# OpenVNC

Cliente nativo de macOS para usar um Windows remoto em um monitor virtual adaptado ao Mac, com fullscreen e troca de Spaces pelos gestos do sistema.

Projeto em desenvolvimento inicial. O cliente já integra conexão VNC por WebSocket, controle e fullscreen. A criação automática do monitor virtual ainda não está implementada. A sessão completa com imagem e entrada no Windows ainda precisa de validação no host real.

## Arquitetura

- **SwiftUI + AppKit:** interface e integração com o Mac.
- **Rust:** núcleo compartilhado, acessível por uma interface C pequena.
- **noVNC em WKWebView:** renderer local e protocolo VNC, empacotados no app.
- **Windows:** futuro agente para autorização e gestão de display; driver existente a selecionar.
- **Tailscale:** conectividade inicial, configurada pelo usuário. Sem serviço de nuvem próprio.

Veja [a arquitetura e o plano inicial](docs/architecture.md) e [as regras de contribuição](CONTRIBUTING.md).

## Compilar no Mac

Requisitos: macOS 13+, ferramentas Apple com Swift 5.9+, Rust/Cargo (edition 2021), Node.js 20+ e npm. O primeiro download das dependências requer internet; o aplicativo pronto não usa CDN nem requer Node em execução.

```sh
npm ci --ignore-scripts --no-audit --no-fund
bash scripts/build-macos.sh
open dist/OpenVNC.app
```

O script compila Rust, liga a biblioteca estática ao cliente Swift e gera um `.app` com assinatura ad hoc para desenvolvimento local. Não é um pacote notarizado para distribuição. `swift build` isolado não inclui a biblioteca Rust; use o script.

## Conectar

1. Mantenha Mac e Windows conectados à sua tailnet e autorizados pelas políticas Tailscale.
2. No app, informe o IP Tailscale do Windows e a porta do **websockify** (normalmente `6080`, não a porta TCP `5900` do VNC).
3. Digite a senha VNC. Marque “Usar e salvar senha no Chaves” se quiser persistir a credencial após uma conexão bem-sucedida. Senha vazia com essa opção marcada consulta o Chaves; “Esquecer senha salva” remove a credencial do endpoint atual.
4. Conecte e use a tela cheia. O app tem desconexão/cancelamento, modo de visualização e envio de Ctrl+Alt+Del. Reconexão é manual, pelo mesmo formulário.

Sem TLS, o núcleo aceita somente IPs explícitos nos intervalos Tailscale. Nomes de host exigem WSS nesta versão. Um servidor WSS precisa de certificado válido; a verificação TLS não é desativada. A exceção ATS fica restrita ao conteúdo WebKit para permitir o WS existente sobre o túnel Tailscale. Nenhuma política de tailnet é alterada pelo app.

Endereço e opções ficam nas preferências locais. A senha não entra em URL, logs ou preferências; permanece na memória da sessão e opcionalmente no Chaves. O bundle inclui fontes e licenças do noVNC em `Contents/Resources/Viewer/ThirdParty`.

**O monitor exibido é o selecionado pelo servidor VNC.** Ajustar a imagem ao tamanho da janela não cria monitor nem muda resolução no Windows. As dimensões mostradas na sessão são as do canvas/framebuffer do renderer, não uma medição de fps, bitrate ou latência.

## Próxima etapa: monitor virtual

O [roteiro de investigação no Windows](docs/windows-display-spike.md) inclui um diagnóstico somente de leitura e os critérios para escolher e validar o driver. Nenhum driver é instalado pelo aplicativo atual.

## Licença

A intenção é distribuir como open source. A licença do código próprio será definida antes da primeira distribuição pública. noVNC 1.7.0 é MPL-2.0; as fontes originais e avisos de seus componentes acompanham o app. esbuild (MIT) é ferramenta de build. Veja [ADR-001](docs/decisions/001-vnc-renderer.md).
