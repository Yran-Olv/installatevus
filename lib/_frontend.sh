#!/bin/bash
#
# functions for setting up app frontend

frontend_project_dir() {
  printf "/home/deploy/%s/frontend" "${instancia_add}"
}

frontend_hostname_from_url() {
  local url="$1"
  url="${url#https://}"
  url="${url#http://}"
  printf "%s" "${url%/}"
}

#######################################
# installs node packages
#######################################
frontend_node_dependencies() {
  print_banner
  printf "${WHITE} 💻 Instalando dependências do frontend...${GRAY_LIGHT}\n\n"
  sleep 1

  local frontend_dir
  frontend_dir="$(frontend_project_dir)"

  run_as_deploy "
    cd '${frontend_dir}' && \
    npm install --legacy-peer-deps
  "

  sleep 1
}

#######################################
# compiles frontend code
#######################################
frontend_node_build() {
  print_banner
  printf "${WHITE} 💻 Compilando o código do frontend...${GRAY_LIGHT}\n\n"
  sleep 1

  local frontend_dir
  frontend_dir="$(frontend_project_dir)"

  run_as_deploy "
    cd '${frontend_dir}' && \
    npm run build
  "

  sleep 1
}

#######################################
# updates frontend code
#######################################
frontend_update() {
  print_banner
  printf "${WHITE} 💻 Atualizando o frontend...${GRAY_LIGHT}\n\n"
  sleep 1

  local project_dir="/home/deploy/${empresa_atualizar}"
  local frontend_dir="${project_dir}/frontend"

  run_as_deploy "
    cd '${project_dir}' && \
    pm2 stop '${empresa_atualizar}-frontend' >/dev/null 2>&1 || true && \
    git fetch --all --prune && \
    git pull && \
    cd '${frontend_dir}' && \
    npm install --legacy-peer-deps && \
    rm -rf build && \
    npm run build && \
    pm2 start server.js --name '${empresa_atualizar}-frontend' --max-memory-restart 512M && \
    pm2 save
  "

  sleep 1
}

#######################################
# sets frontend environment variables
#######################################
frontend_set_env() {
  print_banner
  printf "${WHITE} 💻 Configurando variáveis de ambiente (frontend)...${GRAY_LIGHT}\n\n"
  sleep 1

  local frontend_dir
  frontend_dir="$(frontend_project_dir)"
  local backend_host
  backend_host="$(frontend_hostname_from_url "${backend_url}")"

  run_as_deploy "mkdir -p '${frontend_dir}'"

  cat <<EOF >"${frontend_dir}/.env"
REACT_APP_BACKEND_URL=https://${backend_host}
REACT_APP_HOURS_CLOSE_TICKETS_AUTO=24
REACT_APP_LOCALE=pt-br
REACT_APP_TIMEZONE=America/Sao_Paulo
REACT_APP_TRIALEXPIRATION=7
EOF

chown deploy:deploy "${frontend_dir}/.env"

  cat <<EOF >"${frontend_dir}/server.js"
const express = require("express");
const path = require("path");

const app = express();
const buildPath = path.join(__dirname, "build");

app.use(
  express.static(buildPath, {
    dotfiles: "deny",
    index: false,
  })
);

app.get("/*", (_req, res) => {
  res.sendFile(path.join(buildPath, "index.html"), {
    dotfiles: "deny",
  });
});

app.listen(${frontend_port}, () => {
  console.log("Frontend iniciado na porta ${frontend_port}");
});
EOF

chown deploy:deploy "${frontend_dir}/server.js"

  sleep 1
}

#######################################
# starts pm2 for frontend
#######################################
frontend_start_pm2() {
  print_banner
  printf "${WHITE} 💻 Iniciando pm2 (frontend)...${GRAY_LIGHT}\n\n"
  sleep 1

  local frontend_dir
  frontend_dir="$(frontend_project_dir)"

  run_as_deploy "
    cd '${frontend_dir}' && \
    pm2 start server.js --name '${instancia_add}-frontend' --max-memory-restart 512M && \
    pm2 save
  "

  pm2 startup systemd >/dev/null 2>&1 || true
  sudo env PATH="$PATH:/usr/bin" /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u deploy --hp /home/deploy >/dev/null 2>&1 || true

  sleep 1
}

#######################################
# sets up nginx for frontend
#######################################
frontend_nginx_setup() {
  print_banner
  printf "${WHITE} 💻 Configurando nginx (frontend)...${GRAY_LIGHT}\n\n"
  sleep 1

  local frontend_hostname
  frontend_hostname="$(frontend_hostname_from_url "${frontend_url}")"

  cat <<EOF >/etc/nginx/sites-available/${instancia_add}-frontend
server {
  server_name ${frontend_hostname};
  location / {
    proxy_pass http://127.0.0.1:${frontend_port};
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_cache_bypass \$http_upgrade;
  }
}
EOF

  ln -sf "/etc/nginx/sites-available/${instancia_add}-frontend" "/etc/nginx/sites-enabled/${instancia_add}-frontend"
  sleep 1
}

