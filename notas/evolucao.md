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
- O CMake do Android quebra no caminho com acento (`Área de trabalho`). Build de `flutter build` e `flutter run` passa por `scripts/build_ascii.sh`, que compila em `~/builds/controleSaude` e devolve a pasta `build`. Um atalho não resolve: o CMake usa o caminho real.
- Conta é Supabase Auth (`public.profiles`). A senha mínima é 6. Desinstalar apaga a sessão, não a conta. O release não instala por cima do debug: a assinatura é outra e o Android remove o app antigo. Confirmação de e-mail não pôde ser desligada (token sem permissão de auth). A Site URL do Auth não pode voltar para `localhost`: o link de confirmação deixa de abrir `https://examefacil.pages.dev`. O redirecionamento permitido é `https://examefacil.pages.dev/**`.
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
- Não esperar a rede nem o `SharedPreferences` dentro de `main` antes de `runApp`. Enquanto o primeiro quadro não sai, o Android 12 fica no ícone branco e a Play recusa como app que não abre. `shared_preferences_android` 2.5.0 e 2.5.1 quebram o release: o R8 renomeia `kotlin.coroutines.Continuation` e o app cai ao abrir as preferências. Ficar em 2.5.2 ou mais novo. A Syncfusion só carrega na importação do PDF (`deferred`). As abas Evolução, Histórico e Perfil não montam junto com o Painel.
- O ícone da abertura é o escudo em `ic_launcher_foreground`, fundo `#0A3352`. Recortar em cima do branco e só reduzir deixa uma borda clara. A borda transparente tem que ficar na cor do escudo. O escudo cabe na máscara redonda (diâmetro 72/108); maior que isso, o topo oposto à seta é cortado.
- No encontro da seta com o escudo sobra um vão branco da página. Esse vão se pinta no verde da seta (por volta de 49, 236, 186). Amostrar o pixel claro ao lado pinta de novo um ciano quase branco.
- `FilledButton` do tema tem largura infinita (`Size.fromHeight`). Dentro do `trailing` de um `ListTile`, o botão come o cartão e, no debug, o nome some com o erro de largura. Botão de ação fica embaixo do nome, ou num `Expanded`.

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
- O mesmo projeto Flutter abre no navegador (`web/`) e no celular, no Supabase `xdzognwurazkbmckzldf`. Na tela larga a navegação fica na lateral. O endereço publicado é `https://examefacil.pages.dev`. A Site URL do Auth é esse endereço, e o redirecionamento permitido é `https://examefacil.pages.dev/**`.
- `004_medico_e_acesso` já aplicada: `profiles.role`, CRM, `doctor_directory` e `care_grants`. A chave anon não lê diretório nem convite.
- Médicos: cada médico é um cartão com nome, CRM e o botão embaixo. A lista recarrega ao reabrir a aba. Consultório: uma coluna, convites só quando existem, pacientes em ordem alfabética com busca.
- A abertura pinta o logo e o indicador antes de ler o disco e de conectar o Supabase. Pacote na Play: 1.0.2 (versionCode 3), em análise desde 2026-10-25. O 1.0.1 quebrava no release por causa do R8. O celular de teste está nessa 1.0.2.

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

### 2026-10-17 — Build web e caminho com acento

Pedido: tratar o acento do caminho antes do build, gerar o site e publicar na Cloudflare Pages. Depois liberar essa URL no Supabase.

Deu certo:

- `scripts/build_ascii.sh` copia o projeto para `~/builds/controleSaude` quando o caminho real tem acento, compila lá e devolve `build/`. O hook `.cursor/hooks.json` encaminha `flutter build` e `flutter run` para esse script.
- `flutter build web --release` concluiu. O site está em `build/web`, com o título ExameFácil.

Deu errado / limite:

- A Cloudflare não está autenticada neste computador. O login pelo navegador expirou sem autorização, então não há URL `.pages.dev`.
- A Site URL do Auth não está numa tabela do banco. O MCP autenticou, mas não tem ferramenta para gravar essa configuração. Sem a URL publicada, não há o que liberar.

Ainda exige ação de quem usa: autorizar a Cloudflare quando o login abrir de novo. Em seguida a Site URL entra em Authentication, URL Configuration.

### 2026-10-17 — Site no ar

Pedido: tentar de novo a publicação na Cloudflare.

Deu certo:

- O login da conta `Luizsalvador31@gmail.com` entrou. O projeto Pages `examefacil` foi criado e os 42 arquivos de `build/web` subiram como produção.
- O endereço que responde é `https://examefacil.pages.dev`.

Ainda exige ação de quem usa: colocar essa origem na Site URL e na lista de redirecionamentos do Supabase, em Authentication → URL Configuration. O MCP não grava essa configuração.

### 2026-10-17 — Assinatura de release para a Play

Pedido: a Play rejeita o pacote enquanto o release usa a chave de debug. Publicar a versão de produção.

Deu certo:

- O release passou a assinar com a chave de upload em `android/upload-keystore.jks`, lida de `android/key.properties`. Os dois já estão fora do git.
- `flutter build appbundle --release` gerou o pacote 1.0.0 (versionCode 1), assinado com o certificado da GoStart Lab. A Play aceitou o pacote e a versão de produção, com o Brasil, entrou em análise.

Ainda exige ação de quem usa: guardar uma cópia do keystore e da senha que está só no `key.properties`. Sem esse arquivo a Play não aceita atualização do mesmo app.

Não repetir: não voltar o `signingConfig` do release para `debug`. Não colocar o keystore nem o `key.properties` no git.

### 2026-10-17 — Versão nova no celular e lista de passos

Pedido: instalar a última versão no celular ligado ao notebook e guardar os próximos passos num markdown de TODOs.

Deu certo:

- O debug foi instalado no SM A528B (`RQCT3055G5X`). O app abriu e o Supabase iniciou.
- Os passos ficaram em `notas/todos.md`: Site URL do Auth, prova do consultório, cópia da chave da Play, ficha das lojas e, por último, domínio próprio.

### 2026-10-17 — Mariana sumiu da aba Médicos

Pedido: no celular, a médica Mariana não aparecia em Médicos para o convite. O Consultório, com muitos pacientes, precisa continuar simples.

Deu certo:

- A conta já estava no diretório (CRM/SP 123456). A aba tinha pedido a lista e recebido 200. O nome sumia porque o botão Convidar, com a largura infinita do tema, ocupava o `ListTile` inteiro.
- O cartão agora mostra o nome e o CRM, e o botão fica na linha de baixo. A busca segue A–Z e a aba recarrega quando volta a aparecer.
- O Consultório ficou numa coluna: convites só se houver pendência, pacientes com busca e uma linha por nome.

Deu errado / limite:

- Há outro médico de teste no diretório, Revisao Medico. A lista mostra os dois.
- O celular continuava com o APK antigo (quatro abas, sem Médicos). O código novo só aparece depois de instalar de novo.

### 2026-10-17 — Prova no celular

Pedido: abrir o app no SM A528B e conferir a aba Médicos de ponta a ponta, porque ainda não aparecia nada.

Deu certo:

- O aparelho estava na versão anterior. O debug novo foi instalado por cima.
- Na conta do Luiz, Médicos mostra Mariana, CRM/SP 123456, e o botão Convidar. O convite foi enviado e o cartão passou a “Aguardando aceite”.
- O convite ficou pendente no banco, do paciente Luiz Salvador para a médica Mariana.

Ainda exige ação de quem usa: entrar na conta da Mariana e aceitar o convite no Consultório. Sem a senha dela, o aceite não foi feito daqui.

### 2026-10-25 — Rejeição da Play e versão 1.0.1

Pedido: ver no Play Console por que o Exame Fácil foi rejeitado por política e publicar a última versão do `main`.

Deu certo:

- A conta `luizsalvador31@gmail.com` abriu o console. O problema é um só: política de recursos corrompidos, “o app não abre ou não carrega”, na experiência do app, versionCode 1 (1.0.0), recusado em 21 de out. de 2026. O app saiu da loja. A evidência é a abertura do Android: fundo branco e só o ícone, sem a tela do Flutter.
- O `origin/main` (`81efd76`) é o mesmo código do 1.0.0. A Play não aceita de novo o versionCode 1. O `main` esperava o `SharedPreferences` antes do `runApp`, então o primeiro quadro não saía.
- O `runApp` agora acontece na hora. Disco e Supabase entram depois, com a tela do logo. Pacote 1.0.1 (versionCode 2), assinado com a chave de upload, subiu na produção com lançamento completo. A visão geral da publicação ficou em “Alterações em análise”, junto com a ficha que já estava pronta (Brasil, página da loja, privacidade, saúde, segurança dos dados).

Deu errado / limite:

- A análise do Google ainda não terminou. A mensagem no console é que a revisão pode achar outro problema. Não há relatório de pré-lançamento: o 1.0.0 foi direto para a produção.
- O código novo está na árvore de trabalho, ainda sem commit. O `main` local continua atrás do `origin/main`.

### 2026-10-25 — Main publicado e celular na 1.0.1

Pedido: o código já foi commitado, enviado e mergeado no `main`. Atualizar a Play se precisar, e o SM A528B ligado no notebook, e testar.

Deu certo:

- O `origin/main` (`6412697`, merge do `bea614c`) é a 1.0.1 (versionCode 2), o mesmo pacote que já está em “Alterações em análise”. Não houve outro envio.
- O celular tinha o debug 1.0.0. O release 1.0.1 instalou no `RQCT3055G5X`. O processo desenhou o primeiro quadro cerca de 3 segundos depois de abrir. Não houve crash.

Deu errado / limite:

- A assinatura do release não casa com a do debug. O Android removeu o app antigo, então a sessão local desse celular se foi. A conta continua no Supabase.
- A tela estava bloqueada. Não deu para ver login, Painel nem as abas. No log, a abertura pulou 339 quadros antes do primeiro desenho.

### 2026-10-25 — Reinstalação no celular

Pedido: pode remover e instalar de novo a versão nova no celular.

Deu certo:

- O app antigo saiu e o release 1.0.1 (versionCode 2) entrou de novo no SM A528B. A tela passou do ícone branco e mostrou o logo do ExameFácil.

Deu errado / limite:

- Em seguida apareceu “Não consegui conectar”. O Wi-Fi do celular resolve `google.com` e `supabase.co`, mas `xdzognwurazkbmckzldf.supabase.co` não existe no DNS público. O banco respondeu que não está acessível. O último log do Postgres, em 24 de out., criou o ponto `restore_xdzognwurazkbmckzldf_2058917011`, sinal de projeto pausado. Sem restaurar o projeto, o login não abre.

### 2026-10-25 — Supabase no ar e release que abre

Pedido: o Supabase voltou; refazer os testes no celular.

Deu certo:

- O endereço do projeto voltou a resolver e a API responde. O banco lista as tabelas de novo.
- A 1.0.1 de release não conectava em menos de dois segundos. O erro era `NoSuchMethodError` em `SharedPreferencesApiRegistrar.getAll`: o R8 da  `shared_preferences_android` 2.5.0 renomeia `Continuation`. O plugin foi para 2.5.3.
- A 1.0.2 (versionCode 3) no SM A528B abre a tela de entrada, com “Criar conta” e “Já tenho conta”. O login mostra “Entrar”.
- A 1.0.1 em análise tinha o mesmo defeito. A análise foi reiniciada com a 1.0.2, lançamento completo. As verificações rápidas da Play ainda estavam rodando ao encerrar.

Deu errado / limite:

- O código desta correção ainda não foi commitado. Sem login no aparelho, Painel, Evolução e Histórico não foram abertos.

### 2026-10-25 — Main e prova da conta de revisão

Pedido: o código já foi commitado, enviado e mergeado no `main`. Seguir com os próximos passos.

Deu certo:

- O `origin/main` (`fb19d4c`) é a 1.0.2 com `shared_preferences_android` 2.5.3, o mesmo pacote que a Play já tem em “Alterações em análise”. Não houve outro envio.
- No SM A528B, a conta de revisão de paciente entrou. O Painel mostra “Olá, Revisao Play”, coleta de 03/08/2026, 38 marcadores e 5 fora da faixa. Evolução lista os marcadores. Histórico tem o laudo Unilab `exame-exemplo.pdf`. Médicos mostra Mariana (CRM/SP 123456) e Revisao Medico. Perfil mostra sexo masculino, nascimento 15/01/1990 e 36 anos.

Deu errado / limite:

- A Site URL do Supabase continua sem o endereço `https://examefacil.pages.dev`. O painel do Supabase pediu login e esta sessão não entrou. Sem isso, o link de confirmação de uma conta nova não abre o site.

### 2026-10-25 — Site URL do Auth no endereço publicado

Pedido: gravar no Supabase a Site URL `https://examefacil.pages.dev` e o redirecionamento `https://examefacil.pages.dev/**`.

Deu certo:

- Na tela Authentication → URL Configuration do projeto `xdzognwurazkbmckzldf`, a Site URL saiu de `http://localhost:3000` para `https://examefacil.pages.dev`. A lista de Redirect URLs, que estava vazia, ficou com `https://examefacil.pages.dev/**`. Os dois salvamentos responderam 200 e a tela passou a mostrar esses valores.

Deu errado / limite:

- Conta nova ainda não foi criada para ver o e-mail de confirmação abrir o site. As contas que já confirmaram o e-mail não dependem dessa troca.
