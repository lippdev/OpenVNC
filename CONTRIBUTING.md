# Contribuição

Adotamos o [Git Flow descrito pela Atlassian](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow).

| Branch | Origem | Destino |
| --- | --- | --- |
| `feature/<nome>` | `develop` | `develop` |
| `release/<versao>` | `develop` | `main` com tag e `develop` |
| `hotfix/<nome>` | `main` | `main` com tag e `develop` ou release ativa |

Cada mudança lógica recebe um commit próprio: documentação, funcionalidade e correção independentes não devem ser agrupadas. Usar mensagens como `docs: ...`, `feat(core): ...` e `fix(macos): ...`.

Revisar o diff antes do commit. Registrar o que foi compilado, o que foi validado e o que depende de um host real. Integrar features concluídas com `git merge --no-ff`; `main` recebe somente releases e hotfixes. Não publicar versões incompletas para encerrar uma feature.
