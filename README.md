## 🛠️ Instalador Automático – Visão Geral

ACESSANDO DIRETORIO DO INSTALADOR & INICIANDO INSTALAÇÕES ADICIONAIS (USAR ESTE COMANDO PARA SEGUNDA OU MAIS INSTALAÇÃO:
```bash
cd /root/installatevus && sudo chmod +x install_primaria && sudo ./install_primaria
```

## erro encontrado o instalador não configura o pm2 corretamente

1️⃣ Configurar PM2 para iniciar no boot

Como você está usando o usuário deploy:

# Logado como deploy
pm2 startup systemd


Ele vai te mostrar um comando parecido com:

sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u deploy --hp /home/deploy


Copie e execute esse comando exatamente como ele aparecer. Isso cria o serviço systemd para o PM2.

2️⃣ Salvar processos atuais do PM2

Depois de iniciar suas aplicações (backend e frontend), salve a lista de processos:

pm2 save


Isso cria o arquivo /home/deploy/.pm2/dump.pm2 que será carregado automaticamente no boot.

3️⃣ Testar reinício

Agora, quando você reiniciar a VPS:

sudo reboot


Depois do reboot, logue como deploy e rode:

pm2 list


Você deverá ver todos os processos restaurados automaticamente.

4️⃣ Dicas importantes

Certifique-se de que você sempre inicia suas aplicações como deploy antes de pm2 save.

Se mudar o path ou o nome dos scripts, atualize o PM2 e salve novamente com pm2 save.

Para reiniciar uma aplicação específica sem perder a lista, você pode fazer:

pm2 restart atevus-backend
pm2 save



## outro erro encontrado ele não cria usaurio deploy
1. Criar o usuário deploy corretamente

Execute:

sudo adduser deploy


Defina senha.

2. Adicionar o usuário ao sudo
sudo usermod -aG sudo deploy

3. Criar pasta no home do deploy (se você usa scripts que apontam para /home/deploy/)
sudo mkdir -p /home/deploy
sudo chown deploy:deploy /home/deploy -R

4. Testar login
su - deploy


Se entrar sem erro → resolvido.
Este repositório contém dois scripts que automatizam a preparação de servidores Ubuntu 22.04 LTS para rodar o stack completo (backend + frontend) do projeto:

- `install_primaria`: provisiona uma infraestrutura “do zero” (usuário, pacotes, Node, Postgres, Redis, Docker, Nginx, PM2, Certbot, deploy do código etc.).
- `install_instancia`: reaproveita a infraestrutura já criada para subir uma nova empresa/instância usando portas/domínios diferentes.

Os scripts são idempotentes, pedem todas as informações necessárias via CLI (senhas, domínios, portas, limites de usuários) e persistem credenciais no arquivo `config` (permissões 600) para reutilização.

---

## ✅ O que o instalador faz

- Atualiza e instala dependências do sistema, incluindo Git, Node.js 20 LTS, Postgres 14, Docker CE, Snapd, UFW, Nginx, PM2, Certbot.
- Cria o usuário `deploy`, define senha e adiciona aos grupos necessários (`sudo`, `docker`).
- Clona o repositório do projeto informado e prepara as pastas `backend` e `frontend`.
- Configura `.env` de backend/frontend com os dados fornecidos (URLs, portas, limites, credenciais).
- Provisiona Redis (container Docker com senha) e banco Postgres (role + database com senha).
- Instala dependências Node (com `npm install --legacy-peer-deps`), força `@whiskeysockets/baileys@6.7.7`, compila frontend/backend com suporte ao Node 20 (`--openssl-legacy-provider`).
- Executa `npx sequelize db:migrate` e `npx sequelize db:seed:all`.
- Configura processos PM2 (`<instancia>-backend`, `<instancia>-frontend`) e salva o estado.
- Gera configurações Nginx separadas para backend e frontend, aplica limite `client_max_body_size` e recarrega o serviço.
- Executa Certbot (via Snap) apontando para os domínios informados.
- Disponibiliza utilitários adicionais (via menu): atualização de instância, deleção, bloqueio/desbloqueio, alteração de domínios, backup do Postgres.

---

## 📦 Pré-requisitos

| Item | Mínimo | Recomendado |
| --- | --- | --- |
| Sistema operacional | Ubuntu 20.04 | Ubuntu 22.04 LTS (suportado oficialmente) |
| Node.js | 20.x LTS | 20.x LTS |
| Memória RAM | 4 GB | 8 GB |
| Armazenamento | 40 GB SSD | 80 GB SSD |
| Acesso | Usuário root (ou sudo) via SSH | — |
| DNS | Apontamento A/AAAA e CNAME para backend/frontend | — |

> **Importante**: rode os scripts em uma VPS limpa ou, pelo menos, saiba que serviços existentes (Postgres, Redis, Nginx) serão reconfigurados caso use `install_primaria`.

---

## 🚀 Como usar

### 1. Preparar o servidor
```bash
sudo apt update -y && sudo apt upgrade -y
sudo adduser deploy
sudo usermod -aG sudo deploy
```

### 2. Clonar o repositório e iniciar a instalação primária
```bash
sudo apt install -y git
git clone https://github.com/murjunior/beurus
cd beurus
chmod +x install_primaria install_instancia
sudo ./install_primaria
```

O script irá:
- Solicitar senhas, link do repositório, nome da instância, portas etc.
- Instalar e configurar todos os serviços necessários.
- Salvar as credenciais em `./config` (permissão 600).

### 3. Criar novas instâncias
Após a primeira instalação, use o mesmo diretório para adicionar mais empresas:
```bash
cd ~/beurus
sudo ./install_instancia
```
Responda ao prompt com o nome da instância, domínios e portas específicas. O script reaproveita os serviços globais e apenas clona/configura a nova pasta.

### 4. Menu de utilidades
Ao iniciar qualquer script, escolha uma das opções:
- `0` Instalar sistema (fluxo descrito acima)
- `1` Atualizar sistema (git pull + npm install/build + migrations/seeds)
- `2` Deletar sistema (remove PM2, diretórios, containers, bancos, confs)
- `3` Bloquear sistema (para PM2 backend)
- `4` Desbloquear sistema
- `5` Alterar domínios (regera `.env`, Nginx e certificado)
- `6` Executar backup (dump Postgres + SCP)

---

## ⚙️ Variáveis e personalização

- **Baileys**: a versão padrão é fixada em `6.7.7` (arquivo `variables/_app.sh`). Alterar esse valor permite usar outra release.
- **Email Certbot**: definido em `variables/_app.sh` (`deploy_email=deploy@deploy.com`), ajuste antes de rodar para receber alertas reais.
- **Limites padrão (.env)**: usuário/WhatsApp máximos, timezone e outras configs podem ser editadas nos templates (`lib/_backend.sh`, `lib/_frontend.sh`).
- **Arquivo `config`**: depois que o script roda, o arquivo guarda as últimas credenciais. Apague-o caso precise reinserir tudo manualmente.

---

## 🧪 Após a instalação

1. Valide os serviços:
   ```bash
   sudo systemctl status nginx
   sudo systemctl status postgresql
   sudo docker ps
   sudo -u deploy pm2 list
   ```
2. Acesse os domínios informados (backend e frontend) e confira o certificado SSL.
3. Caso veja erros nas migrations/seeds, verifique os scripts Sequelize e reexecute manualmente:
   ```bash
   sudo -u deploy bash -lc "cd /home/deploy/<instancia>/backend && npx sequelize db:migrate"
   sudo -u deploy bash -lc "cd /home/deploy/<instancia>/backend && npx sequelize db:seed:all"
   ```

---

## ❓ Perguntas frequentes

- **Posso rodar novamente?** Sim, os scripts são idempotentes. Reutilizam o arquivo `config` e sobrescrevem configs onde necessário.
- **Posso pular a reinstalação de dependências?** Hoje não, o instalador sempre roda `npm install` para garantir consistência. Você pode customizar as funções se quiser.
- **Preciso mudar algo para outra versão do Ubuntu?** O script foi testado para Ubuntu 22.04 LTS. Em releases diferentes, revise as fontes (NodeSource, Docker) e pacotes.
- **E se o Certbot falhar?** Verifique se os domínios apontam para o IP da VPS e tente: `sudo certbot --nginx -d api.seudominio -d app.seudominio`.

---

## 📎 Recursos úteis

- [Documentação oficial do NodeSource (Node 20)](https://github.com/nodesource/distributions/blob/master/README.md#debinstall)
- [Instalação do Docker Engine no Ubuntu](https://docs.docker.com/engine/install/ubuntu/)
- [PostgreSQL Debian/Ubuntu packages](https://www.postgresql.org/download/linux/ubuntu/)
- [Certbot + Nginx](https://certbot.eff.org/instructions?ws=nginx&os=ubuntufocal)
- [Guia PM2](https://pm2.keymetrics.io/)

---

Pronto! Com esses scripts você automatiza toda a infraestrutura para hospedar o projeto no Ubuntu 22.04 com poucos comandos. Ajuste conforme necessário para sua realidade (logs, monitoramento, escalabilidade) e bons deploys. 🍀
