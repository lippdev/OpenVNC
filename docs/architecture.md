# Arquitetura inicial

## Experiência alvo

Conectar o Mac ao próprio Windows pela tailnet, solicitar um monitor virtual com proporção e resolução adequadas, controlar esse monitor e entrar em fullscreen nativo. A sessão remota usa a mesma sessão de usuário do Windows.

## Limites dos componentes

O núcleo Rust valida o destino e o pedido de display. A interface Swift chama o núcleo por uma ABI C e apresenta o resultado. Comunicação, autenticação e motor de vídeo serão adicionados atrás desses limites; não colocar lógica de protocolo na View.

O agente Windows será responsável por pareamento, autorização, ciclo de vida do display, restauração da topologia e integração com captura/entrada. O driver não será reimplementado sem primeiro avaliar soluções existentes.

## Display

Capturar as informações da tela em que a janela está localizada. Distinguir pontos do AppKit, pixels do framebuffer e resolução física do painel: os modos escalados do macOS podem produzir valores diferentes. O pedido inicial usa o framebuffer da tela, acompanhado da escala; o host deverá negociar os modos realmente disponíveis. Escala do macOS não garante que o Windows consiga aplicar DPI equivalente por monitor.

## Rede e vídeo

Tailscale é o caminho de rede inicial, não a identidade permanente do produto. Um endereço válido não prova disponibilidade, identidade nem autorização. Pareamento autenticado antecederá comandos que modificam o host.

Avaliar primeiro captura VNC do display virtual, pois o usuário já aprovou a experiência VNC. Avaliar Sunshine/Moonlight se captura ou fluidez forem insuficientes. Não incorporar dependências antes de revisar as licenças. O transporte futuro pode acrescentar descoberta/NAT/relay sem alterar a interface do usuário.

## Marcos

1. Fundação: regras Git Flow, núcleo Rust, ponte Swift, leitura da tela e preparação local do pedido.
2. Prova Windows: selecionar driver e método de captura; validar em ambiente autorizado, com rollback.
3. Sessão: pareamento, criação real do display e negociação de modo.
4. Vídeo e controle: integração do motor escolhido, coordenadas/DPI e liberação de teclas na desconexão.
5. Experiência: fullscreen, reconexão, clipboard e restauração do layout.

O primeiro marco não abre conexão, instala driver nem promete streaming. Os seguintes dependem de acesso a um Windows de teste.
