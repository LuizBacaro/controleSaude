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
- Nome na loja: **ExameFácil**. Pacote Android e bundle iOS: `br.com.examefacil.laudos`. A Apple já recusou `br.com.examefacil` (ocupado) e `br.com.examefacil.app` (terminar em `.app` é inválido). Trocar `applicationId` cria outro app e apaga a sessão local.
- O papel da conta fica em `profiles.role`, não no JWT. Médico não lista pacientes: só lê a Evolução de quem convidou e ele aceitou. Não reaplicar `supabase/schema.sql`.
- No login, carregar os laudos antes de avisar o roteador. Avisar com a memória vazia manda para a importação e o Painel fica sem dados enquanto as outras abas guardam o estado antigo.
- `flutter create . --platforms=web` troca a lista de plataformas no `.metadata`. Conferir se Android e iOS continuam lá.
- Conta é Supabase Auth (`public.profiles`). A senha mínima é 6. Desinstalar apaga a sessão, não a conta. Confirmação de e-mail não pôde ser desligada (token sem permissão de auth).
- No cliente só entra a chave anon. A `service_role` não vai no app, no git nem nas anotações. Quem colou essa chave no chat deve rotacioná-la.
- `exam_reports` não tem coluna de médico nem de convênio. Isso vai no `notes` em JSON (`doctor`, `insurance`, `unrecognized`). Enviar coluna que não existe derruba o import. `patient_name` e `lab_name` já existem.
- Laudo antigo não se reescreve sozinho. Mudou o leitor: apagar o item no Histórico e importar o PDF de novo.
- `flutter test` e `flutter run` não rodam como root (falha no `engine.stamp`). Celular: `flutter run -d RQCT3055G5X`. “Lost connection to device” com exit 0, depois do install, deixa o APK no aparelho.
- Não criar de novo os testes de dump (`test/dump_*.dart`, `test/pdf_dump.txt`). Teste temporário de inspeção: apagar antes de encerrar.
- Faixa do PDF só substitui a fixa quando é uma faixa única. Linha com homem, mulher, anos, criança ou gestante fica com a faixa fixa; senão o leitor pega a banda errada.
- Importar não salva direto: `readPdf*` devolve rascunho e só `saveReport` grava. Não voltar a gravar dentro da leitura.
- Laudos são carregados no bootstrap, antes do login. Após login e cadastro, chamar `examsRepository.load()`; no logout, `clear()`. Com RLS por usuário, sem isso a lista fica vazia ou de outra conta.
- MCP do Supabase: a configuração oficial fica em `.cursor/mcp.json` (URL com `project_ref` e `features`, sem token no arquivo). Conectar com `agent mcp enable supabase` e `agent mcp login supabase`. Não renovar à mão o refresh do `mcp-auth.json`: é de uso único e a sessão anterior ficou sem login assim.
- O MCP do Playwright fica no mesmo `.cursor/mcp.json` (`npx -y @playwright/mcp@latest`) e entra com `agent mcp enable playwright`. Não apagar essa entrada ao mexer no Supabase.
- `rg` não está instalado no terminal; usar `grep` em comandos de shell.
- `pkill -f "...flutter run..."` no mesmo comando mata o próprio shell (o padrão casa com ele). Rodar `flutter run` sozinho.
- Faixa por sexo/idade: o bloco de referência termina no próximo exame (`Resultado:`, `Rótulo:` seguido de número, `Resultados anteriores`). Sem esse corte, a bilirrubina direta pegou a faixa da total.
- “Inferior ou igual a”, “menor ou igual a” e “≤” são limite máximo. O leitor não entendia “Inferior ou igual a” e caía na faixa errada.
- Sexo e idade do PDF têm prioridade sobre o perfil. Faixa fixa “Homens” não vale para mulher: sem banda no PDF, o status fica sem avaliação.
- Não esperar a rede dentro de `main` antes de `runApp`. A Syncfusion só carrega na importação do PDF (`deferred`). As abas Evolução, Histórico e Perfil não montam junto com o Painel.
- O ícone da abertura é o escudo em `ic_launcher_foreground`, fundo `#0A3352`. Recortar em cima do branco e só reduzir deixa uma borda clara. A borda transparente tem que ficar na cor do escudo. O escudo cabe na máscara redonda (diâmetro 72/108); maior que isso, o topo oposto à seta é cortado.
- No encontro da seta com o escudo sobra um vão branco da página. Esse vão se pinta no verde da seta (por volta de 49, 236, 186). Amostrar o pixel claro ao lado pinta de novo um ciano quase branco.

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
- `002_laudos_por_usuario` já aplicada: `exam_reports` e `exam_results` têm `user_id` padrão `auth.uid()`, anon sem acesso, política só do dono. Laudos antigos foram atribuídos à única conta.
- Conta do Luiz: `profiles.birth_date` 1984-02-21 e `sex` M. O Perfil mostra sexo, nascimento e idade. Reabrir o app para recarregar o perfil.
- Ícone: fundo `#0A3352`, logo em `assets/brand/logo.png`.
- Cadastro pergunta primeiro se a conta é de paciente ou de médico. Médico informa UF e número do CRM. Conta antiga continua paciente.
- Paciente convida em Médicos. Médico aceita no Consultório e abre a Evolução daquele paciente, só leitura. Sem aceite, o laudo não abre.
- O mesmo projeto Flutter abre no navegador (`web/`) e no celular, no Supabase `xdzognwurazkbmckzldf`. Na tela larga a navegação fica na lateral.
- `004_medico_e_acesso` já aplicada: `profiles.role`, CRM, `doctor_directory` e `care_grants`. A chave anon não lê diretório nem convite.

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

### 2026-10-11 — MCP do Supabase pelo login oficial

Pedido: usar a configuração do painel (`features` na URL), `agent mcp enable/login/list` e instalar `supabase/agent-skills`.

Deu certo:

- `.cursor/mcp.json` ficou só com a URL oficial, sem token. `agent mcp list` mostra `supabase: ready`.
- Login pelo navegador concluiu. `execute_sql` gravou nascimento 1984-02-21; o sexo já era M.
- `apply_migration` aplicou `laudos_por_usuario`. Uma conta, 3 laudos e 155 resultados ficaram com dono.
- Skills em `.agents/skills/supabase` e `.agents/skills/supabase-postgres-best-practices`.

Deu errado:

- A primeira tentativa das skills falhou com `ENOTFOUND` dentro do sandbox. Com rede livre, o `npx` concluiu.
- O cabeçalho `Authorization` com `SUPABASE_ACCESS_TOKEN` não é o caminho do painel. Foi removido.

### 2026-10-11 — App pesado demais para abrir

Pedido: depois das alterações, o aplicativo ficou pesado e não abria mais.

Deu certo:

- No SM A528B o debug abria, mas só depois de uma janela preta: o `main` esperava o Supabase e os laudos, e o sistema registrava cerca de 300 quadros perdidos. A memória ficava em torno de 360 MB. O núcleo de debug tinha 107 MB, com o leitor de PDF da Syncfusion inteiro no caminho da abertura.
- A primeira tela agora é leve e aparece antes da rede. Se a conexão falhar, dá para tentar de novo em vez de ficar preso.
- O leitor de PDF só entra na memória quando um PDF é importado. Evolução, Histórico e Perfil só são montados na primeira visita.
- 12 testes passando, `dart analyze` limpo. O debug novo foi instalado no SM A528B: a janela passou de 4,7 s para 3,0 s e sumiu o segundo travamento, aquele de ~200 quadros depois que a tela já existia. Painel, laudo e as outras abas abriram.

Deu errado / limite:

- O APK de release não compilou: o CMake quebra no caminho com acento (`Área de trabalho`). O que está no celular continua sendo debug, com a máquina virtual do Dart, e a memória fica perto de 400 MB. O `flutter run` segue mais pesado que um release.

### 2026-10-12 — Borda do ícone na abertura

Pedido: no instante em que aparece só o escudo (`ic_launcher_foreground`), a borda estava ruim.

Deu certo:

- A arte saiu de `logo.png`, sem o texto. O fundo claro foi tirado e a borda transparente ficou na cor do desenho, não num fio branco.
- Regenerados os cinco tamanhos do foreground e o `ic_launcher` legado, mais `assets/brand/app_icon.png`. O fundo do adaptive icon continua `#0A3352`.

### 2026-10-12 — MCP do Playwright de novo

Pedido: instalar de novo o MCP do Playwright, se tivesse sumido.

Deu certo:

- Não estava em `.cursor/mcp.json` nem no `mcp.json` do usuário. Voltou no arquivo do projeto, ao lado do Supabase.
- `agent mcp list` mostra `playwright: ready`. O pacote `@playwright/mcp` responde e o Chromium já está no cache.

### 2026-10-12 — Escudo menor no ícone do celular

Pedido: centralizar o escudo do ícone. A parte de cima, no lado oposto à seta, era cortada pela borda redonda do app.

Deu certo:

- O desenho ocupava 61% da tela do ícone e passava 12 px da máscara. Ficou em 50%, com cerca de 8 px de folga dentro do círculo.
- Atualizados `assets/brand/app_icon.png`, o foreground e o `ic_launcher` em todos os tamanhos. Fundo continua `#0A3352`.

### 2026-10-12 — Branco no começo da seta

Pedido: a mancha branca perto do começo da seta em `assets/brand/app_icon.png` ficar no verde que o desenho já usa.

Deu certo:

- O vão entre o cabo da seta e o escudo era resto do fundo branco da página, cerca de 120 pixels no recorte. Foi pintado no verde da seta (49, 236, 186), junto com a franja clara em volta.
- O mesmo recorte foi para o `app_icon` e para os ícones do Android, nos cinco tamanhos. A ponta da seta e a cruz não foram mexidas.

### 2026-10-14 — Pacote das lojas

Pedido: o identificador `br.com.examefacil.app` também não passou no cadastro. Usar outra string só para a Play Store e a Apple aceitarem.

Deu certo:

- Pacote Android e bundle iOS passaram a `br.com.examefacil.laudos`. O nome na tela continua ExameFácil.
- `br.com.examefacil` já estava registrado. Terminar em `.app` a Apple trata como identificador inválido.

Ainda exige ação de quem usa: cadastrar `br.com.examefacil.laudos` nas duas lojas. Instalar esse pacote no celular cria outro app e pede login de novo; a conta no Supabase permanece.

### 2026-10-17 — Médico, convite e navegador

Pedido: no cadastro, escolher paciente ou médico; médico informa o CRM; o paciente convida e o médico só vê a Evolução depois de aceitar; o mesmo banco serve o app e o navegador do consultório. O Painel esvaziava ao sair e entrar de novo.

Deu certo:

- Migração `004_medico_e_acesso.sql`: papel, CRM, lista pública só com nome e CRM, convite e leitura do laudo apenas com aceite.
- Cadastro com a escolha e o CRM. Médico cai no Consultório. Paciente ganhou a aba Médicos.
- Tela larga usa a barra lateral. O alvo web do Flutter foi criado sem tirar Android e iOS.
- Login carrega os laudos antes de o roteador decidir a tela. Sair descarta as abas visitadas.

Deu certo depois:

- O SQL foi executado no Editor. A API enxerga `profiles.role`, `doctor_directory` e `care_grants`. A chave anon recebe permissão negada no diretório e nos convites.

Deu errado / limite:

- O conector do Supabase não autenticou nesta sessão. A conferência foi pela API pública, sem entrar numa conta.

Ainda exige ação de quem usa: criar uma conta de médico e uma de paciente no app para convidar e aceitar. Não reaplicar `schema.sql`.

### 2026-10-17 — Assinatura de release para a Play

Pedido: a Play rejeita o pacote enquanto o release usa a chave de debug. Publicar a versão de produção.

Deu certo:

- O release passou a assinar com a chave de upload em `android/upload-keystore.jks`, lida de `android/key.properties`. Os dois já estão fora do git.
- `flutter build appbundle --release` gerou o pacote 1.0.0 (versionCode 1), assinado com o certificado da GoStart Lab.

Ainda exige ação de quem usa: guardar uma cópia do keystore e da senha que está só no `key.properties`. Sem esse arquivo a Play não aceita atualização do mesmo app.

Não repetir: não voltar o `signingConfig` do release para `debug`. Não colocar o keystore nem o `key.properties` no git.
