# TODOs do ExameFácil

Ordem que destrava o uso real. Guardar o PDF original para reprocessar laudos antigos fica para depois.

- [x] Liberar o endereço publicado no login do Supabase. Em 2026-10-25, no projeto `xdzognwurazkbmckzldf`, Authentication → URL Configuration ficou com Site URL `https://examefacil.pages.dev` e Redirect URLs `https://examefacil.pages.dev/**`.
- [ ] Provar o consultório nesse endereço. Criar uma conta de médico e uma de paciente, convidar, aceitar e abrir a Evolução. Revogar e confirmar que o laudo some na hora.
- [ ] Guardar uma cópia de `android/upload-keystore.jks` e da senha que está em `android/key.properties`. Sem esses arquivos a Play recusa a próxima atualização do mesmo app. A 1.0.2 (versionCode 3) está em análise.
- [ ] Fechar a ficha da loja. A Play pode devolver a versão por política de privacidade, segurança dos dados ou capturas de tela. Na Apple, cadastrar o identificador `br.com.examefacil.laudos`.
- [ ] Quando o fluxo acima estiver estável, publicar um domínio próprio (por exemplo `app.examefacil.com.br`) na mesma Pages e repetir a Site URL do Supabase com esse domínio.
