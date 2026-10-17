# TODOs do ExameFácil

Ordem que destrava o uso real. Guardar o PDF original para reprocessar laudos antigos fica para depois.

- [ ] Liberar o endereço publicado no login do Supabase. Sem isso, o link de confirmação de e-mail continua apontando para o computador local e uma conta nova não entra em https://examefacil.pages.dev. No projeto `xdzognwurazkbmckzldf`, em Authentication → URL Configuration:
  - Site URL: `https://examefacil.pages.dev`
  - Redirect URLs: `https://examefacil.pages.dev/**`
- [ ] Provar o consultório nesse endereço. Criar uma conta de médico e uma de paciente, convidar, aceitar e abrir a Evolução. Revogar e confirmar que o laudo some na hora.
- [ ] Guardar uma cópia de `android/upload-keystore.jks` e da senha que está em `android/key.properties`. Sem esses arquivos a Play recusa a próxima atualização do mesmo app. O pacote 1.0.0 já está em análise; não gerar outro pacote enquanto isso.
- [ ] Fechar a ficha da loja. A Play pode devolver a versão por política de privacidade, segurança dos dados ou capturas de tela. Na Apple, cadastrar o identificador `br.com.examefacil.laudos`.
- [ ] Quando o fluxo acima estiver estável, publicar um domínio próprio (por exemplo `app.examefacil.com.br`) na mesma Pages e repetir a Site URL do Supabase com esse domínio.
