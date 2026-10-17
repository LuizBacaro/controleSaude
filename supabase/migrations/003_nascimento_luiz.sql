-- Data de nascimento da conta já existente do Luiz.
-- Rodar uma vez no SQL Editor do projeto xdzognwurazkbmckzldf.

update public.profiles
  set birth_date = date '1984-02-21'
  where lower(email) = 'luizsalvador31@gmail.com';

update auth.users
  set raw_user_meta_data =
    coalesce(raw_user_meta_data, '{}'::jsonb) || '{"birth_date": "1984-02-21"}'::jsonb
  where lower(email) = 'luizsalvador31@gmail.com';

-- Conferência: deve aparecer uma linha com birth_date 1984-02-21 e o sexo cadastrado.
select p.email, p.display_name, p.sex, p.birth_date
from public.profiles p
where lower(p.email) = 'luizsalvador31@gmail.com';
