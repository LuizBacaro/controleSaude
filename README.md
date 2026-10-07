# Controle Saúde

App mobile (Flutter) para acompanhar a evolução dos exames de sangue a partir do PDF do laboratório.

Arquitetura inspirada em `rescue-garage-platform`: features com `domain` / `data` / `presentation`, Riverpod e GoRouter.

## O que faz

1. **Cadastro / login** (local no aparelho)
2. Após o cadastro, **pede o PDF do exame**
3. **Extrai os marcadores** (hemograma, glicose, HbA1c, lipídico, INR, creatinina, etc.)
4. Monta um **painel** com status (normal / baixo / alto)
5. Mantém **histórico de laudos** e **gráficos de evolução** por marcador

## Como rodar

```bash
cd "/home/luiz/Área de trabalho/Projetos/controleSaude"
flutter pub get
flutter run -d android
# ou
flutter run -d chrome
```

No primeiro uso: criar conta → importar PDF (ou usar **Carregar exame de exemplo**).

## Estrutura

```
lib/
  core/           # theme, router, providers
  features/
    auth/         # cadastro, login, perfil
    exams/        # parser PDF, modelos, histórico
    dashboard/    # painel e evolução
    onboarding/   # importação do PDF
```

## PDF suportado

O parser foi calibrado no formato de laudo Unilab (texto extraído do PDF), como o arquivo `exames.pdf`. Laboratórios com layout muito diferente podem exigir ajustes no `LabPdfParser`.

## Privacidade

- Dados ficam no **SharedPreferences** deste aparelho (mock local).
- Não há backend na versão atual.
- O app é **informativo** e não substitui avaliação médica.

## Testes

```bash
flutter test
flutter analyze
```
