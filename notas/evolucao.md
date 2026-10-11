# Evolução do ExameFácil

Diário do que deu certo, do que quebrou e do que não repetir. A cada mudança pedida, acrescentar uma entrada datada no final e, se o erro puder voltar, uma linha em **Não repetir**.

O app lê laudos em PDF (Unilab e IPC), guarda no Supabase e mostra Painel, Evolução e Histórico.

## Não repetir

- A data da coleta vem do PDF (`Data atend.` ou `Coleta:`). Nunca usar a hora do upload nem `DateTime.now()` como coleta. `importedAt` é a única data de agora.
- O texto do PDF no app vem do Syncfusion (`PdfTextExtractor`), não do `pdftotext`. Rótulo e valor muitas vezes caem em linhas separadas. `Resultado` e `:` também. Testar com o extrator do app.
- Regex de lipídios: `COLESTEROL TOTAL` não pode pegar “Total e Frações”; `LDL` não pode pegar `VLDL`; `HDL` não pode pegar “Não HDL”; triglicérides no IPC se escreve `TRIGLICÉRIDES`.
- Faixa etária, “resultado anterior”, CNES, páginas e texto de documento não são exame. Marcador numérico desconhecido precisa de unidade.
- Urina tipo I fica na categoria própria (`Urina: …`). Hemácias e glicose da urina não entram na série do sangue.
- Rota de marcador é query `nome` em `/marcador`. Não chamar `Uri.decodeComponent` de novo: o GoRouter já decodifica e o acento quebra com “invalid argument”.
- Nome na loja: **ExameFácil**. Pacote Android e bundle iOS: `br.com.examefacil.app`. `br.com.examefacil` a Apple recusou. Trocar `applicationId` cria outro app e apaga a sessão local.
- Conta é Supabase Auth (`public.profiles`). A senha mínima é 6. Desinstalar apaga a sessão, não a conta. Confirmação de e-mail não pôde ser desligada (token sem permissão de auth).
- No cliente só entra a chave anon. A `service_role` não vai no app, no git nem nas anotações. Quem colou essa chave no chat deve rotacioná-la.
- `exam_reports` não tem coluna de médico nem de convênio. Isso vai no `notes` em JSON (`doctor`, `insurance`, `unrecognized`). Enviar coluna que não existe derruba o import. `patient_name` e `lab_name` já existem.
- Laudo antigo não se reescreve sozinho. Mudou o leitor: apagar o item no Histórico e importar o PDF de novo.
- `flutter test` e `flutter run` não rodam como root (falha no `engine.stamp`). Celular: `flutter run -d RQCT3055G5X`. “Lost connection to device” com exit 0, depois do install, deixa o APK no aparelho.
- Não criar de novo os testes de dump (`test/dump_*.dart`, `test/pdf_dump.txt`).

## O que está valendo

- Projeto Supabase `xdzognwurazkbmckzldf`, região `us-east-1`. URL do cliente sem `/rest/v1`.
- Tabelas `exam_reports` e `exam_results`, RLS aberto para anon/authenticated. `profiles` é só do dono. `text_value` guarda resultado qualitativo.
- Cabeçalho do laudo: paciente, médico, laboratório e convênio. Três layouts já cobertos — colunas empilhadas (resultado.pdf), palavra por linha (ipc.pdf) e `Rótulo : valor` (exame.pdf).
- Histórico mostra laboratório, data, médico e convênio. O detalhe abre com esse cabeçalho.
- Ícone: fundo `#0A3352`, logo em `assets/brand/logo.png`.

## Histórico

### 2026-10-11 — Cabeçalho do laudo no Histórico

Pedido: ao abrir um exame no Histórico, mostrar o cabeçalho do PDF (quando, qual médico, qual laboratório), como em `titulo.png`, `titulo2.png` e `titulo3.png`.

Deu certo:

- Leitura pelo Syncfusion, não pela ordem visual do `pdftotext`.
- `resultado.pdf`: Nome, Médico e Convênio vêm primeiro; os valores (Luis Roberto, Luciana dos Santos Schraiber, Unimed) vêm nas linhas seguintes. Origem Unilab.
- `ipc.pdf`: cada palavra numa linha. Nome, Dr(a) Waldemar Paschoalino Junior, Destino IPC - Central, convênio Unimed Araraquara.
- `exame.pdf`: `Solicitante :` na linha de baixo é Dra. Cecilia Meirelles Barros, unidade Unilab. A imagem `titulo3.png` mostra outro médico; o valor certo é o texto do PDF.
- Persistência no JSON de `notes`, sem coluna nova. Testes dos três PDFs passaram. App reinstalado no SM A528B.

Deu errado antes, e ficou corrigido:

- Nome só com regex `Nome : NOME` falhava no laudo em colunas.
- `labName` só existia se o texto contivesse a palavra Unilab; o IPC ficava sem laboratório.
- Sessão antiga de `flutter run` caiu com “Lost connection to device” depois que a instalação nova tomou o lugar. O APK novo permaneceu.

Ainda exige ação de quem usa: laudos importados antes não têm médico nem convênio. Apagar e importar de novo.
