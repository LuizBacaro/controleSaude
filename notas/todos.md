# TODOs do ExameFácil

Cobrança do consultório, a partir de 2026-11-13. O desenho está em `notas/evolucao.md` (entrada dessa data). Não trocar por um botão “ir ao site” dentro do app da Play.

- [ ] Criar o preço no Stripe e gravar `STRIPE_SECRET_KEY`, `STRIPE_PRICE_ID` e `STRIPE_WEBHOOK_SECRET` nas funções. O webhook aponta para `stripe-webhook`. Sem isso o site não cobra.
- [ ] Criar a assinatura `plano_medico_mensal` na Play e a credencial da Play Developer API para `confirm-play-purchase`. Sem a conferência no servidor, a compra não libera o consultório.
- [ ] Enviar o AAB 1.0.7 (`build/app/outputs/bundle/release/app-release.aab`) à produção só quando o produto da Play existir. A 1.0.6 já está publicada. Não anexar pacote antigo no lugar.
- [ ] Provar no site: “Sou médico”, cadastro em `/plano` e, com o Stripe configurado, a volta em `/#/plano?pago=1` abrindo o consultório. No Android, o paywall compra pela Play e “Meus exames” continua aberto.

Ordem que destrava o uso real. Guardar o PDF original para reprocessar laudos antigos fica para depois.

- [x] Liberar o endereço publicado no login do Supabase. Em 2026-10-25, no projeto `xdzognwurazkbmckzldf`, Authentication → URL Configuration ficou com Site URL `https://examefacil.pages.dev` e Redirect URLs `https://examefacil.pages.dev/**`.
- [ ] Provar o consultório nesse endereço. Criar uma conta de médico e uma de paciente, convidar, aceitar e abrir a Evolução. Revogar e confirmar que o laudo some na hora.
- [ ] Guardar uma cópia de `android/upload-keystore.jks` e da senha que está em `android/key.properties`. Sem esses arquivos a Play recusa a próxima atualização do mesmo app. A 1.0.2 (versionCode 3) está em análise.
- [ ] Fechar a ficha da loja. A Play pode devolver a versão por política de privacidade, segurança dos dados ou capturas de tela. Na Apple, cadastrar o identificador `br.com.examefacil.laudos`.
- [ ] Quando o fluxo acima estiver estável, publicar um domínio próprio (por exemplo `app.examefacil.com.br`) na mesma Pages e repetir a Site URL do Supabase com esse domínio.
