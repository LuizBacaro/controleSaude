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
- Não criar de novo os testes de dump (`test/dump_*.dart`, `test/pdf_dump.txt`). Teste temporário de inspeção: apagar antes de encerrar.
- Faixa do PDF só substitui a fixa quando é uma faixa única. Linha com homem, mulher, anos, criança ou gestante fica com a faixa fixa; senão o leitor pega a banda errada.
- Importar não salva direto: `readPdf*` devolve rascunho e só `saveReport` grava. Não voltar a gravar dentro da leitura.
- Laudos são carregados no bootstrap, antes do login. Após login e cadastro, chamar `examsRepository.load()`; no logout, `clear()`. Com RLS por usuário, sem isso a lista fica vazia ou de outra conta.
- O MCP do Supabase não está conectado. SQL novo vai em `supabase/migrations/` e o Luiz roda no SQL Editor. Não contar com a migração já aplicada. Dado de conta específica (ex.: nascimento) também vai por SQL, nunca pela `service_role`.
- `rg` não está instalado no terminal; usar `grep` em comandos de shell.
- `pkill -f "...flutter run..."` no mesmo comando mata o próprio shell (o padrão casa com ele). Rodar `flutter run` sozinho.
- Faixa por sexo/idade: o bloco de referência termina no próximo exame (`Resultado:`, `Rótulo:` seguido de número, `Resultados anteriores`). Sem esse corte, a bilirrubina direta pegou a faixa da total.
- “Inferior ou igual a”, “menor ou igual a” e “≤” são limite máximo. O leitor não entendia “Inferior ou igual a” e caía na faixa errada.
- Sexo e idade do PDF têm prioridade sobre o perfil. Faixa fixa “Homens” não vale para mulher: sem banda no PDF, o status fica sem avaliação.

## O que está valendo

- Projeto Supabase `xdzognwurazkbmckzldf`, região `us-east-1`. URL do cliente sem `/rest/v1`.
- Tabelas `exam_reports` e `exam_results`, RLS aberto para anon/authenticated. `profiles` é só do dono. `text_value` guarda resultado qualitativo.
- Cabeçalho do laudo: paciente, médico, laboratório e convênio. Três layouts já cobertos — colunas empilhadas (resultado.pdf), palavra por linha (ipc.pdf) e `Rótulo : valor` (exame.pdf).
- Histórico mostra laboratório, data, médico e convênio. O detalhe abre com esse cabeçalho (`ReportHeading`).
- Importação abre a tela “Conferir laudo”: cabeçalho, resultados marcáveis, aviso de PDF repetido. Só os marcados são salvos.
- Hemograma e exames simples usam a faixa impressa logo após o valor. Quando o laudo separa por sexo ou idade, escolhe a banda do paciente (`_bandRangeAfter`): “Homens:/Mulheres:”, tabela Idade × Homens × Mulheres (linha Adultos), “< 65 anos”, “Adultos:”. Sem banda, a fixa do código.
- Sexo e idade saem do PDF (`Sexo/Idade: M/41`, `Data nasc (42 anos)`, IPC `Idade 39 Ano(s)`); o perfil (`profiles.birth_date`, `sex`) completa o que faltar.
- Cadastro pede data de nascimento e sexo. No Perfil, “Dados para as faixas de referência” edita os dois. Vale para os próximos imports.
- Painel: cartão da última coleta, “Atenção nesta coleta” e “Mudou desde a coleta anterior” (variação ≥ 10%).
- `supabase/migrations/002_laudos_por_usuario.sql` cria `user_id` com padrão `auth.uid()` e políticas por dono. Pendente de rodar no SQL Editor; até lá o RLS segue aberto.
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

### 2026-10-11 — Plano de melhorias do produto (1ª leva)

Pedido: planejar e implementar as melhorias sugeridas — conferir antes de salvar, Painel da última coleta, faixa do PDF e laudos por conta.

Deu certo:

- Faixa do PDF: o hemograma de cada laboratório usa a própria faixa (IPC Hemoglobina 13,5–17,5; resultado.pdf Segmentados 50–70 e Hemoglobina 17,3 alta). Faixa IPC quebrada em três linhas (`4,30` / `-` / `5,70`) é juntada antes de ler.
- Conferir laudo: leitura e gravação separadas; desmarcar tira o resultado do laudo salvo; aviso quando o mesmo arquivo e a mesma coleta já existem.
- Painel: deixou de listar os oito primeiros em ordem alfabética e passou a mostrar a última coleta.
- Laudos por conta: migração pronta; o app recarrega ao entrar e limpa ao sair. Texto do Perfil corrigido (dizia “armazenados localmente”).
- 11 testes passando, `dart analyze` sem problemas.

Deu errado no caminho:

- `rg` não existe no shell do notebook; o filtro de saída do teste falhou até trocar por `grep`.
- O MCP do Supabase sumiu da sessão, então a migração não pôde ser aplicada daqui.

Ainda exige ação de quem usa: rodar `002_laudos_por_usuario.sql` no SQL Editor. Ficou para a próxima leva: guardar o PDF original para reprocessar laudos antigos sem reimportar.

### 2026-10-11 — Faixa de referência pela idade e pelo sexo

Pedido: avaliar baixo, normal ou alto pela faixa de idade e sexo do paciente; pedir data de nascimento no cadastro.

Antes: o app usava faixa fixa de homem adulto e ignorava as bandas do laudo. No `resultado.pdf`, a creatinina mostrava 0,76–1,24; o laudo diz “Homens: 0,70 – 1,20”.

Deu certo:

- Banda escolhida em cinco PDFs: creatinina 0,70–1,20 (resultado, exame4); tabela de creatinina e fosfatase com linha Adultos (exame, Exame2); ureia “< 65 anos”; TSH “Adultos”; IPC por palavra (“Homem.: 3,4 a 7,0”, e para mulher “2,4 a 6,0”).
- Sexo e idade lidos do próprio PDF; perfil completa.
- Cadastro com data de nascimento e sexo obrigatórios; Perfil com edição. Salva em `profiles` e nos metadados da conta.
- 12 testes passando, `dart analyze` limpo.

Deu errado no caminho:

- Primeira versão pegava a faixa da bilirrubina total para a direta e a indireta (o bloco não parava no exame seguinte, e “Inferior ou igual a” não era entendido). Corrigido e coberto por teste.
- Trecho de banda com 70 caracteres fixos passava do “Homens:” para as linhas de criança; o corte agora para em “De 01 a…”, “Crianças”, “Adultos” e no outro sexo.

Ainda exige ação de quem usa: preencher data de nascimento e sexo no Perfil (a conta atual não tem) e reimportar os laudos para reavaliar.

### 2026-10-11 — Nascimento da conta existente e Perfil com idade

Pedido: confirmar a 1ª leva (faixa do PDF, conferir laudo, Painel da última coleta, laudos por conta, testes/instalação/notas) e gravar 21/02/1984 na conta `luizsalvador31@gmail.com`, mostrando sexo, nascimento e idade no Perfil.

Deu certo:

- A 1ª leva já estava completa: 12 testes, instalada no SM A528B, entradas neste arquivo.
- Perfil ganhou o cartão com sexo, nascimento e idade calculada; borda de aviso quando falta algo.
- `supabase/migrations/003_nascimento_luiz.sql` grava a data em `profiles` e nos metadados da conta, com um select de conferência.

Deu errado / limite:

- Sem MCP do Supabase nesta sessão, a data não pôde ser gravada daqui. O SQL fica para o SQL Editor. Não usar a `service_role` colada no chat para contornar.

Ainda exige ação de quem usa: rodar `003_nascimento_luiz.sql` (e o `002`, se ainda não rodou), fechar e abrir o app.
