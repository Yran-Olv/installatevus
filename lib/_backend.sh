#!/bin/bash
#
# functions for setting up app backend

readonly BAILEYS_VERSION_DEFAULT="latest"

backend_project_dir() {
  printf "/home/deploy/%s/backend" "${instancia_add}"
}

backend_hostname_from_url() {
  local url="$1"
  url="${url#https://}"
  url="${url#http://}"
  printf "%s" "${url%/}"
}

#######################################
# creates Redis container and Postgres db
#######################################
backend_redis_create() {
  print_banner
  printf "${WHITE} 💻 Criando Redis e configurando Postgres...${GRAY_LIGHT}\n\n"
  sleep 1

  usermod -aG docker deploy 2>/dev/null || true

  local redis_container="redis-${instancia_add}"
  if docker container inspect "${redis_container}" >/dev/null 2>&1; then
    docker container rm "${redis_container}" --force >/dev/null 2>&1 || true
  fi

  docker run \
    --pull always \
    --name "${redis_container}" \
    -p "${redis_port}:6379" \
    --restart always \
    --detach \
    redis:7.2-alpine \
    redis-server --requirepass "${mysql_root_password}" --save 60 1 --loglevel warning

  sudo -u postgres psql -v ON_ERROR_STOP=1 <<SQL
DO \$\$ BEGIN
  PERFORM 1 FROM pg_roles WHERE rolname = '${instancia_add}';
  IF NOT FOUND THEN
    EXECUTE 'CREATE ROLE ' || quote_ident('${instancia_add}') || ' LOGIN PASSWORD ''${mysql_root_password}''';
  ELSE
    EXECUTE 'ALTER ROLE ' || quote_ident('${instancia_add}') || ' PASSWORD ''${mysql_root_password}''';
  END IF;
END \$\$;

DO \$\$ BEGIN
  PERFORM 1 FROM pg_database WHERE datname = '${instancia_add}';
  IF NOT FOUND THEN
    EXECUTE 'CREATE DATABASE ' || quote_ident('${instancia_add}') ||
            ' OWNER ' || quote_ident('${instancia_add}');
  ELSE
    EXECUTE 'ALTER DATABASE ' || quote_ident('${instancia_add}') ||
            ' OWNER TO ' || quote_ident('${instancia_add}');
  END IF;
END \$\$;
SQL

  sleep 1
}

#######################################
# sets environment variables for backend
#######################################
backend_set_env() {
  print_banner
  printf "${WHITE} 💻 Configurando variáveis de ambiente (backend)...${GRAY_LIGHT}\n\n"
  sleep 1

  local backend_dir
  backend_dir="$(backend_project_dir)"
  local backend_host
  backend_host="$(backend_hostname_from_url "${backend_url}")"
  local frontend_host
  frontend_host="$(backend_hostname_from_url "${frontend_url}")"

  run_as_deploy "mkdir -p '${backend_dir}'"

  cat <<EOF >"${backend_dir}/.env"
NODE_ENV=production
BACKEND_URL=https://${backend_host}
FRONTEND_URL=https://${frontend_host}
PROXY_PORT=443
PORT=${backend_port}

DB_HOST=localhost
DB_DIALECT=postgres
DB_USER=${instancia_add}
DB_PASS=${mysql_root_password}
DB_NAME=${instancia_add}
DB_PORT=5432

JWT_SECRET=${jwt_secret}
JWT_REFRESH_SECRET=${jwt_refresh_secret}

REDIS_URI=redis://:${mysql_root_password}@127.0.0.1:${redis_port}
REDIS_OPT_LIMITER_MAX=1
REDIS_OPT_LIMITER_DURATION=3000
REDIS_HOST=127.0.0.1
REDIS_PORT=${redis_port}
REDIS_PASSWORD=${mysql_root_password}

REDIS_AUTHSTATE_SERVER=127.0.0.1
REDIS_AUTHSTATE_PORT=${redis_port}
REDIS_AUTHSTATE_PWD=${mysql_root_password}
REDIS_AUTHSTATE_DATABASE=0

USER_LIMIT=${max_user}
CONNECTIONS_LIMIT=${max_whats}
CLOSED_SEND_BY_ME=true

GERENCIANET_SANDBOX=false
GERENCIANET_CLIENT_ID=sua-id
GERENCIANET_CLIENT_SECRET=sua_chave_secreta
GERENCIANET_PIX_CERT=nome_do_certificado
GERENCIANET_PIX_KEY=chave_pix_gerencianet

STRIPE_PUB=
STRIPE_PRIVATE=
STRIPE_OK_URL=
STRIPE_CANCEL_URL=

MP_ACCESS_TOKEN=
MP_PUBLIC_KEY=
MP_CLIENT_ID=
MP_CLIENT_SECRET=
MP_NOTIFICATION_URL=
EOF

chown deploy:deploy "${backend_dir}/.env"

  sleep 1
}

#######################################
# installs node.js dependencies
#######################################
backend_node_dependencies() {
  print_banner
  printf "${WHITE} 💻 Instalando dependências do backend...${GRAY_LIGHT}\n\n"
  sleep 1

  local backend_dir
  backend_dir="$(backend_project_dir)"
  local baileys_version="${baileys_version:-${BAILEYS_VERSION_DEFAULT}}"

  run_as_deploy "
    cd '${backend_dir}' && \
    npm install --legacy-peer-deps && \
    npm install --legacy-peer-deps '@whiskeysockets/baileys@${baileys_version}'
  "

  sleep 1
}

#######################################
# compiles backend code
#######################################
backend_node_build() {
  print_banner
  printf "${WHITE} 💻 Compilando o código do backend...${GRAY_LIGHT}\n\n"
  sleep 1

  local backend_dir
  backend_dir="$(backend_project_dir)"

  run_as_deploy "
    cd '${backend_dir}' && \
    NODE_OPTIONS=--openssl-legacy-provider npm run build
  "

  sleep 1
}

#######################################
# updates backend
#######################################
backend_update() {
  print_banner
  printf "${WHITE} 💻 Atualizando o backend...${GRAY_LIGHT}\n\n"
  sleep 1

  local project_dir="/home/deploy/${empresa_atualizar}"
  local backend_dir="${project_dir}/backend"

  run_as_deploy "
    cd '${project_dir}' && \
    pm2 stop '${empresa_atualizar}-backend' >/dev/null 2>&1 || true && \
    git fetch --all --prune && \
    git pull && \
    cd '${backend_dir}' && \
    npm install --legacy-peer-deps && \
    npm install --legacy-peer-deps '@whiskeysockets/baileys@${baileys_version:-${BAILEYS_VERSION_DEFAULT}}' && \
    rm -rf dist && \
    NODE_OPTIONS=--openssl-legacy-provider npm run build && \
    npx sequelize db:migrate && \
    npx sequelize db:seed:all && \
    pm2 start dist/server.js --name '${empresa_atualizar}-backend' --max-memory-restart 512M && \
    pm2 save
  "

  sleep 1
}

#######################################
# runs db migrate
#######################################
backend_db_migrate() {
  print_banner
  printf "${WHITE} 💻 Executando db:migrate...${GRAY_LIGHT}\n\n"
  sleep 1

  local backend_dir
  backend_dir="$(backend_project_dir)"

  run_as_deploy "
    cd '${backend_dir}' && \
    npx sequelize db:migrate
  "

  sleep 1
}

#######################################
# runs db seed
#######################################
backend_db_seed() {
  print_banner
  printf "${WHITE} 💻 Executando db:seed...${GRAY_LIGHT}\n\n"
  sleep 1

  local backend_dir
  backend_dir="$(backend_project_dir)"

  run_as_deploy "
    cd '${backend_dir}' && \
    npx sequelize db:seed:all
  "

  sleep 1
}

#######################################
# starts backend using pm2
#######################################
backend_start_pm2() {
  print_banner
  printf "${WHITE} 💻 Iniciando pm2 (backend)...${GRAY_LIGHT}\n\n"
  sleep 1

  local backend_dir
  backend_dir="$(backend_project_dir)"

  run_as_deploy "
    cd '${backend_dir}' && \
    pm2 start dist/server.js --name '${instancia_add}-backend' --max-memory-restart 512M && \
    pm2 save
  "

  sleep 1
}

#######################################
# configures nginx for backend
#######################################
backend_nginx_setup() {
  print_banner
  printf "${WHITE} 💻 Configurando nginx (backend)...${GRAY_LIGHT}\n\n"
  sleep 1

  local backend_hostname
  backend_hostname="$(backend_hostname_from_url "${backend_url}")"

  cat <<EOF >/etc/nginx/sites-available/${instancia_add}-backend
server {
  server_name ${backend_hostname};
  location / {
    proxy_pass http://127.0.0.1:${backend_port};
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

  ln -sf "/etc/nginx/sites-available/${instancia_add}-backend" "/etc/nginx/sites-enabled/${instancia_add}-backend"
  sleep 1
}

