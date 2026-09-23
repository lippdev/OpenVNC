# Regras do projeto

## Git Flow e commits (regra central)

Seguir https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow.

- `main`: versões publicadas; `develop`: integração.
- Criar `feature/<nome>` a partir de `develop`; integrar a feature concluída em `develop`.
- Criar `release/<versao>` de `develop`; finalizar em `main` com tag e reintegrar em `develop`.
- Criar `hotfix/<nome>` de `main`; reintegrar em `main` e `develop` (ou release ativa).
- Usar merges `--no-ff` para manter os limites das branches visíveis.
- Cada mudança lógica concluída deve ter seu próprio commit descritivo. Não acumular alterações independentes em um commit nem fazer squash dos commits por padrão.
- Antes de commitar, revisar o diff e incluir somente arquivos da mudança. Nunca incluir segredos, binários ou caches.
- Não desenvolver diretamente em `main` ou `develop`. Não reescrever histórico publicado.

## Produto

- Cliente Mac nativo: SwiftUI/AppKit. Núcleo compartilhável: Rust.
- Primeiro host: Windows, com monitor virtual adaptado à tela do Mac.
- Rede inicial: Tailscale existente; manter identidade e transporte desacoplados do fornecedor.
- Fullscreen nativo e gestos de Spaces pertencem ao macOS.
- Diferenciar resolução em pixels, tamanho lógico e escala. Não prometer uma sessão Windows independente.
- Reutilizar componentes open source após avaliar licença e compatibilidade.
- Não simular conexão, captura ou criação de display como sucesso real.
- Instalação de driver exige avaliação e autorização específica; desenvolver o cliente não autoriza instalar drivers no host.

## Validação

- Compilar os componentes alterados e registrar limitações da validação.
- Não adicionar ou executar testes automatizados sem solicitação do usuário.
- Manter README e decisões de arquitetura coerentes com o comportamento implementado.
