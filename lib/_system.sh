#!/bin/bash
#
# system management

#######################################
# creates user
#######################################
system_create_user() {
  print_banner
  printf "${WHITE} 💻 Agora, vamos criar (ou atualizar) o usuário deploy...${GRAY_LIGHT}\n\n"
  sleep 1

  if ! id -u deploy >/dev/null 2>&1; then
    local password_hash
    password_hash="$(openssl passwd -6 "${deploy_password}")"

    useradd -m -s /bin/bash -G sudo deploy
    echo "deploy:${password_hash}" | chpasswd -e
  else
    echo "deploy:${deploy_password}" | chpasswd
  fi

  usermod -aG sudo deploy
  usermod -aG docker deploy 2>/dev/null || true

  sleep 1
}

#######################################
# clones repositories using git
#######################################
system_git_clone() {
  print_banner
  printf "${WHITE} 💻 Fazendo download do código...${GRAY_LIGHT}\n\n"
  sleep 1

  local deploy_home="/home/deploy"
  ensure_directory "${deploy_home}"

  local target_dir="${deploy_home}/${instancia_add}"
  if [[ -d "${target_dir}" ]]; then
    rm -rf "${target_dir}"
  fi

  run_as_deploy "git clone '${link_git}' '${target_dir}'"
  sleep 1
}

#######################################
# updates system packages
#######################################
system_update() {
  print_banner
  printf "${WHITE} 💻 Atualizando pacotes do sistema...${GRAY_LIGHT}\n\n"
  sleep 1

  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get upgrade -y
  apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    unzip \
    wget \
    fontconfig \
    locales \
    libasound2 \
    libatk1.0-0 \
    libc6 \
    libcairo2 \
    libcups2 \
    libdbus-1-3 \
    libexpat1 \
    libfontconfig1 \
    libgbm-dev \
    libgdk-pixbuf2.0-0 \
    libglib2.0-0 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libstdc++6 \
    libx11-6 \
    libx11-xcb1 \
    libxcb1 \
    libxcomposite1 \
    libxcursor1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxi6 \
    libxrandr2 \
    libxrender1 \
    libxss1 \
    libxtst6 \
    fonts-liberation \
    xdg-utils \
    software-properties-common \
    git

  locale-gen pt_BR.UTF-8 en_US.UTF-8 >/dev/null
  sleep 1
}

#######################################
# delete system
#######################################
deletar_tudo() {
  print_banner
  printf "${WHITE} 💻 Removendo a instância selecionada...${GRAY_LIGHT}\n\n"
  sleep 1

  docker container rm "redis-${empresa_delete}" --force >/dev/null 2>&1 || true

  rm -f "/etc/nginx/sites-enabled/${empresa_delete}-frontend"
  rm -f "/etc/nginx/sites-enabled/${empresa_delete}-backend"
  rm -f "/etc/nginx/sites-available/${empresa_delete}-frontend"
  rm -f "/etc/nginx/sites-available/${empresa_delete}-backend"

  if command -v systemctl >/dev/null; then
    systemctl reload nginx >/dev/null 2>&1 || true
  else
    service nginx reload >/dev/null 2>&1 || true
  fi

  sudo -u postgres psql -v ON_ERROR_STOP=1 <<SQL >/dev/null 2>&1
DO \$\$ BEGIN
  PERFORM 1 FROM pg_database WHERE datname = '${empresa_delete}';
  IF FOUND THEN
    PERFORM pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${empresa_delete}';
    EXECUTE 'DROP DATABASE ' || quote_ident('${empresa_delete}');
  END IF;

  PERFORM 1 FROM pg_roles WHERE rolname = '${empresa_delete}';
  IF FOUND THEN
    EXECUTE 'DROP ROLE ' || quote_ident('${empresa_delete}');
  END IF;
END \$\$;
SQL

  run_as_deploy "pm2 delete '${empresa_delete}-frontend' '${empresa_delete}-backend' >/dev/null 2>&1 || true"
  run_as_deploy "pm2 save >/dev/null 2>&1 || true"
  rm -rf "/home/deploy/${empresa_delete}"

  sleep 1
  print_banner
  printf "${WHITE} 💻 Instância ${empresa_delete} removida com sucesso.${GRAY_LIGHT}\n\n"
  sleep 1
}

#######################################
# bloquear system
#######################################
configurar_bloqueio() {
  print_banner
  printf "${WHITE} 💻 Bloqueando a instância selecionada...${GRAY_LIGHT}\n\n"
  sleep 1

  run_as_deploy "pm2 stop '${empresa_bloquear}-backend' >/dev/null 2>&1 || true"
  run_as_deploy "pm2 save >/dev/null 2>&1 || true"

  sleep 1
  print_banner
  printf "${WHITE} 💻 Instância ${empresa_bloquear} bloqueada com sucesso.${GRAY_LIGHT}\n\n"
  sleep 1
}

#######################################
# desbloquear system
#######################################
configurar_desbloqueio() {
  print_banner
  printf "${WHITE} 💻 Desbloqueando a instância selecionada...${GRAY_LIGHT}\n\n"
  sleep 1

  run_as_deploy "pm2 start '${empresa_desbloquear}-backend' >/dev/null 2>&1 || true"
  run_as_deploy "pm2 save >/dev/null 2>&1 || true"

  sleep 1
  print_banner
  printf "${WHITE} 💻 Instância ${empresa_desbloquear} desbloqueada com sucesso.${GRAY_LIGHT}\n\n"
  sleep 1
}

#######################################
# alter domain system
#######################################
configurar_dominio() {
  print_banner
  printf "${WHITE} 💻 Atualizando domínios da instância...${GRAY_LIGHT}\n\n"
  sleep 1

  rm -f "/etc/nginx/sites-enabled/${empresa_dominio}-frontend"
  rm -f "/etc/nginx/sites-enabled/${empresa_dominio}-backend"
  rm -f "/etc/nginx/sites-available/${empresa_dominio}-frontend"
  rm -f "/etc/nginx/sites-available/${empresa_dominio}-backend"

  run_as_deploy "
    cd '/home/deploy/${empresa_dominio}/frontend' && \
    sed -i \"s#^REACT_APP_BACKEND_URL=.*#REACT_APP_BACKEND_URL=${alter_backend_url}#\" .env
  "

  run_as_deploy "
    cd '/home/deploy/${empresa_dominio}/backend' && \
    sed -i \"s#^BACKEND_URL=.*#BACKEND_URL=${alter_backend_url}#\" .env && \
    sed -i \"s#^FRONTEND_URL=.*#FRONTEND_URL=${alter_frontend_url}#\" .env
  "

  local backend_hostname="${alter_backend_url#https://}"
  backend_hostname="${backend_hostname#http://}"
  local frontend_hostname="${alter_frontend_url#https://}"
  frontend_hostname="${frontend_hostname#http://}"

  cat <<EOF >/etc/nginx/sites-available/${empresa_dominio}-backend
server {
  server_name ${backend_hostname};
  location / {
    proxy_pass http://127.0.0.1:${alter_backend_port};
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

  ln -sf "/etc/nginx/sites-available/${empresa_dominio}-backend" "/etc/nginx/sites-enabled/${empresa_dominio}-backend"

  cat <<EOF >/etc/nginx/sites-available/${empresa_dominio}-frontend
server {
  server_name ${frontend_hostname};
  location / {
    proxy_pass http://127.0.0.1:${alter_frontend_port};
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

  ln -sf "/etc/nginx/sites-available/${empresa_dominio}-frontend" "/etc/nginx/sites-enabled/${empresa_dominio}-frontend"

  if command -v systemctl >/dev/null; then
    systemctl reload nginx
  else
    service nginx reload
  fi

  local backend_domain="${backend_url#https://}"
  backend_domain="${backend_domain#http://}"
  local frontend_domain="${frontend_url#https://}"
  frontend_domain="${frontend_domain#http://}"

  certbot -m "${deploy_email}" \
    --nginx \
    --agree-tos \
    --non-interactive \
    --domains "${backend_domain},${frontend_domain}"

  sleep 1
  print_banner
  printf "${WHITE} 💻 Domínios da instância ${empresa_dominio} atualizados com sucesso.${GRAY_LIGHT}\n\n"
  sleep 1
}

#######################################
# installs node
#######################################
system_node_install() {
  print_banner
  printf "${WHITE} 💻 Verificando instalação do Node.js 20...${GRAY_LIGHT}\n\n"
  sleep 1

  local need_install=1
  if command -v node >/dev/null 2>&1; then
    local current_version
    current_version="$(node -v | cut -c2-)"
    if dpkg --compare-versions "${current_version}" ge "20.0.0"; then
      need_install=0
    fi
  fi

  if (( need_install )); then
    local keyring="/usr/share/keyrings/nodesource.gpg"
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o "${keyring}"
    echo "deb [signed-by=${keyring}] https://deb.nodesource.com/node_20.x $(lsb_release -cs) main" >/etc/apt/sources.list.d/nodesource.list
    apt-get update -y
    apt-get install -y nodejs
  fi

  npm install --global npm@latest
  sleep 1
}

#######################################
# installs postgres
#######################################
system_postgres_install() {
  print_banner
  printf "${WHITE} 💻 Instalando Postgres...${GRAY_LIGHT}\n\n"
  sleep 1

  apt-get install -y postgresql postgresql-contrib
  systemctl enable --now postgresql

  sleep 1
}

#######################################
# installs fail2ban
#######################################
system_fail2ban_install() {
  print_banner
  printf "${WHITE} 💻 Instalando fail2ban...${GRAY_LIGHT}\n\n"
  sleep 1

  apt-get install -y fail2ban
  cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
  systemctl enable --now fail2ban

  sleep 1
}

#######################################
# configure firewall
#######################################
system_firewall_conf() {
  print_banner
  printf "${WHITE} 💻 Configurando firewall (UFW)...${GRAY_LIGHT}\n\n"
  sleep 1

  apt-get install -y ufw
  ufw --force disable >/dev/null 2>&1 || true
  ufw default allow outgoing
  ufw default deny incoming
  ufw allow OpenSSH
  ufw allow 22
  ufw allow 80
  ufw allow 443
  yes | ufw enable

  sleep 1
}

#######################################
# installs docker
#######################################
system_docker_install() {
  print_banner
  printf "${WHITE} 🐋 Instalando Docker Engine...${GRAY_LIGHT}\n\n"
  sleep 1

  if ! command -v docker >/dev/null 2>&1; then
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    local arch
    arch="$(dpkg --print-architecture)"
    local codename
    codename="$(lsb_release -cs)"

    echo \
      "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${codename} stable" \
      >/etc/apt/sources.list.d/docker.list

    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  fi

  systemctl enable --now docker
  usermod -aG docker deploy 2>/dev/null || true
  sleep 1
}

#######################################
# installs pm2
#######################################
system_pm2_install() {
  print_banner
  printf "${WHITE} 💻 Instalando PM2...${GRAY_LIGHT}\n\n"
  sleep 1

  npm install --global pm2
  sleep 1
}

#######################################
# set timezone
#######################################
system_set_timezone() {
  print_banner
  printf "${WHITE} 💻 Configurando timezone (America/Sao_Paulo)...${GRAY_LIGHT}\n\n"
  sleep 1

  timedatectl set-timezone America/Sao_Paulo
  sleep 1
}

#######################################
# installs snapd
#######################################
system_snapd_install() {
  print_banner
  printf "${WHITE} 💻 Garantindo snapd atualizado...${GRAY_LIGHT}\n\n"
  sleep 1

  apt-get install -y snapd
  snap install core
  snap refresh core

  sleep 1
}

#######################################
# installs certbot
#######################################
system_certbot_install() {
  print_banner
  printf "${WHITE} 💻 Instalando Certbot via Snap...${GRAY_LIGHT}\n\n"
  sleep 1

  snap install --classic certbot
  ln -sf /snap/bin/certbot /usr/bin/certbot

  sleep 1
}

#######################################
# installs nginx
#######################################
system_nginx_install() {
  print_banner
  printf "${WHITE} 💻 Instalando Nginx...${GRAY_LIGHT}\n\n"
  sleep 1

  apt-get install -y nginx
  rm -f /etc/nginx/sites-enabled/default

  sleep 1
}

#######################################
# restarts nginx
#######################################
system_nginx_restart() {
  print_banner
  printf "${WHITE} 💻 Recarregando Nginx...${GRAY_LIGHT}\n\n"
  sleep 1

  if command -v systemctl >/dev/null; then
    systemctl reload nginx
  else
    service nginx reload
  fi

  sleep 1
}

#######################################
# setup for nginx.conf
#######################################
system_nginx_conf() {
  print_banner
  printf "${WHITE} 💻 Ajustando parâmetros globais do Nginx...${GRAY_LIGHT}\n\n"
  sleep 1

  cat <<'EOF' >/etc/nginx/conf.d/deploy.conf
client_max_body_size 100M;
EOF

  sleep 1
}

#######################################
# runs certbot
#######################################
system_certbot_setup() {
  print_banner
  printf "${WHITE} 💻 Emitindo certificados SSL com Certbot...${GRAY_LIGHT}\n\n"
  sleep 1

  local backend_domain="${backend_url#https://}"
  backend_domain="${backend_domain#http://}"
  local frontend_domain="${frontend_url#https://}"
  frontend_domain="${frontend_domain#http://}"

  certbot -m "${deploy_email}" \
    --nginx \
    --agree-tos \
    --non-interactive \
    --domains "${backend_domain},${frontend_domain}"

  sleep 1
}

