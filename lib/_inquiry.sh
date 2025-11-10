#!/bin/bash

readonly __ALNUM_REGEX='^[A-Za-z0-9]+$'
readonly __SLUG_REGEX='^[a-z0-9]+([_-]?[a-z0-9]+)*$'
readonly __PORT_REGEX='^[0-9]{2,5}$'
readonly __DOMAIN_REGEX='^([A-Za-z0-9-]+\.)+[A-Za-z]{2,}$'
readonly __GIT_URL_REGEX='^(git@|https:\/\/)([^[:space:]]+)$'

print_validation_error() {
  printf "\n${RED} ⚠️ Entrada inválida. Tente novamente seguindo as orientações exibidas.${GRAY_LIGHT}\n"
  sleep 2
}

get_mysql_root_password() {
  while true; do
    print_banner
    printf "${WHITE} 💻 Insira uma senha (mín. 8 caracteres alfanuméricos) para o usuário Deploy e Banco de Dados:${GRAY_LIGHT}"
    printf "\n\n"
    read -r -p "> " mysql_root_password

    if [[ ${#mysql_root_password} -ge 8 && "${mysql_root_password}" =~ ${__ALNUM_REGEX} ]]; then
      deploy_password="${mysql_root_password}"
      break
    fi
    print_validation_error
  done
}

get_link_git() {
  while true; do
    print_banner
    printf "${WHITE} 💻 Informe o link Git (HTTPS ou SSH) do projeto que será instalado:${GRAY_LIGHT}"
    printf "\n\n"
    read -r -p "> " link_git

    if [[ -n "${link_git}" && "${link_git}" =~ ${__GIT_URL_REGEX} ]]; then
      break
    fi
    print_validation_error
  done
}

get_instancia_add() {
  while true; do
    print_banner
    printf "${WHITE} 💻 Informe o identificador da Instância/Empresa (minúsculas, números, '-' ou '_'):${GRAY_LIGHT}"
    printf "\n\n"
    read -r -p "> " instancia_add

    if [[ -n "${instancia_add}" && "${instancia_add}" =~ ${__SLUG_REGEX} ]]; then
      break
    fi
    print_validation_error
  done
}

get_max_whats() {
  while true; do
    print_banner
    printf "${WHITE} 💻 Informe a quantidade máxima de conexões WhatsApp para ${instancia_add}:${GRAY_LIGHT}"
    printf "\n\n"
    read -r -p "> " max_whats

    if [[ "${max_whats}" =~ ^[0-9]+$ ]]; then
      break
    fi
    print_validation_error
  done
}

get_max_user() {
  while true; do
    print_banner
    printf "${WHITE} 💻 Informe a quantidade máxima de usuários/atendentes para ${instancia_add}:${GRAY_LIGHT}"
    printf "\n\n"
    read -r -p "> " max_user

    if [[ "${max_user}" =~ ^[0-9]+$ ]]; then
      break
    fi
    print_validation_error
  done
}

get_frontend_url() {
  while true; do
    print_banner
    printf "${WHITE} 💻 Informe o domínio público do FRONTEND/PAINEL (ex.: app.exemplo.com):${GRAY_LIGHT}"
    printf "\n\n"
    read -r -p "> " frontend_url

    if [[ -n "${frontend_url}" ]]; then
      frontend_url=$(normalize_domain "${frontend_url}")
      if [[ "${frontend_url}" =~ ${__DOMAIN_REGEX} ]]; then
        frontend_url="https://${frontend_url}"
        break
      fi
    fi
    print_validation_error
  done
}

get_backend_url() {
  while true; do
    print_banner
    printf "${WHITE} 💻 Informe o domínio público do BACKEND/API (ex.: api.exemplo.com):${GRAY_LIGHT}"
    printf "\n\n"
    read -r -p "> " backend_url

    if [[ -n "${backend_url}" ]]; then
      backend_url=$(normalize_domain "${backend_url}")
      if [[ "${backend_url}" =~ ${__DOMAIN_REGEX} ]]; then
        backend_url="https://${backend_url}"
        break
      fi
    fi
    print_validation_error
  done
}

get_frontend_port() {
  while true; do
    print_banner
    printf "${WHITE} 💻 Informe a porta do FRONTEND para ${instancia_add} (3000-3999 recomendado):${GRAY_LIGHT}"
    printf "\n\n"
    read -r -p "> " frontend_port

    if validate_port "${frontend_port}" 3000 3999; then
      break
    fi
    print_validation_error
  done
}

get_backend_port() {
  while true; do
    print_banner
    printf "${WHITE} 💻 Informe a porta do BACKEND para ${instancia_add} (4000-4999 recomendado):${GRAY_LIGHT}"
    printf "\n\n"
    read -r -p "> " backend_port

    if validate_port "${backend_port}" 4000 4999; then
      break
    fi
    print_validation_error
  done
}

get_redis_port() {
  while true; do
    print_banner
    printf "${WHITE} 💻 Informe a porta do Redis/Agendamento para ${instancia_add} (5000-5999 recomendado):${GRAY_LIGHT}"
    printf "\n\n"
    read -r -p "> " redis_port

    if validate_port "${redis_port}" 5000 5999; then
      break
    fi
    print_validation_error
  done
}

get_empresa_delete() {
  while true; do
    print_banner
    printf "${WHITE} 💻 Informe o identificador da Instância/Empresa a ser deletada:${GRAY_LIGHT}"
    printf "\n\n"
    read -r -p "> " empresa_delete

    if [[ -n "${empresa_delete}" && "${empresa_delete}" =~ ${__SLUG_REGEX} ]]; then
      break
    fi
    print_validation_error
  done
}

get_empresa_atualizar() {
  while true; do
    print_banner
    printf "${WHITE} 💻 Informe o identificador da Instância/Empresa que deseja atualizar:${GRAY_LIGHT}"
    printf "\n\n"
    read -r -p "> " empresa_atualizar

    if [[ -n "${empresa_atualizar}" && "${empresa_atualizar}" =~ ${__SLUG_REGEX} ]]; then
      break
    fi
    print_validation_error
  done
}

get_empresa_bloquear() {
  while true; do
    print_banner
    printf "${WHITE} 💻 Informe o identificador da Instância/Empresa que deseja bloquear:${GRAY_LIGHT}"
    printf "\n\n"
    read -r -p "> " empresa_bloquear

    if [[ -n "${empresa_bloquear}" && "${empresa_bloquear}" =~ ${__SLUG_REGEX} ]]; then
      break
    fi
    print_validation_error
  done
}

get_empresa_desbloquear() {
  while true; do
    print_banner
    printf "${WHITE} 💻 Informe o identificador da Instância/Empresa que deseja desbloquear:${GRAY_LIGHT}"
    printf "\n\n"
    read -r -p "> " empresa_desbloquear

    if [[ -n "${empresa_desbloquear}" && "${empresa_desbloquear}" =~ ${__SLUG_REGEX} ]]; then
      break
    fi
    print_validation_error
  done
}

get_empresa_dominio() {
  while true; do
    print_banner
    printf "${WHITE} 💻 Informe o identificador da Instância/Empresa para alterar domínios:${GRAY_LIGHT}"
    printf "\n\n"
    read -r -p "> " empresa_dominio

    if [[ -n "${empresa_dominio}" && "${empresa_dominio}" =~ ${__SLUG_REGEX} ]]; then
      break
    fi
    print_validation_error
  done
}

get_alter_frontend_url() {
  while true; do
    print_banner
    printf "${WHITE} 💻 Informe o NOVO domínio do FRONTEND/PAINEL para ${empresa_dominio}:${GRAY_LIGHT}"
    printf "\n\n"
    read -r -p "> " alter_frontend_url

    if [[ -n "${alter_frontend_url}" ]]; then
      alter_frontend_url=$(normalize_domain "${alter_frontend_url}")
      if [[ "${alter_frontend_url}" =~ ${__DOMAIN_REGEX} ]]; then
        alter_frontend_url="https://${alter_frontend_url}"
        break
      fi
    fi
    print_validation_error
  done
}

get_alter_backend_url() {
  while true; do
    print_banner
    printf "${WHITE} 💻 Informe o NOVO domínio do BACKEND/API para ${empresa_dominio}:${GRAY_LIGHT}"
    printf "\n\n"
    read -r -p "> " alter_backend_url

    if [[ -n "${alter_backend_url}" ]]; then
      alter_backend_url=$(normalize_domain "${alter_backend_url}")
      if [[ "${alter_backend_url}" =~ ${__DOMAIN_REGEX} ]]; then
        alter_backend_url="https://${alter_backend_url}"
        break
      fi
    fi
    print_validation_error
  done
}

get_alter_frontend_port() {
  while true; do
    print_banner
    printf "${WHITE} 💻 Informe a porta do FRONTEND da Instância/Empresa ${empresa_dominio}:${GRAY_LIGHT}"
    printf "\n\n"
    read -r -p "> " alter_frontend_port

    if validate_port "${alter_frontend_port}" 1024 65535; then
      break
    fi
    print_validation_error
  done
}

get_alter_backend_port() {
  while true; do
    print_banner
    printf "${WHITE} 💻 Informe a porta do BACKEND da Instância/Empresa ${empresa_dominio}:${GRAY_LIGHT}"
    printf "\n\n"
    read -r -p "> " alter_backend_port

    if validate_port "${alter_backend_port}" 1024 65535; then
      break
    fi
    print_validation_error
  done
}

normalize_domain() {
  local input="$1"
  input="${input#http://}"
  input="${input#https://}"
  input="${input#/}"
  printf "%s" "${input%/}"
}

validate_port() {
  local port="$1"
  local min="$2"
  local max="$3"

  if [[ -z "${port}" || ! "${port}" =~ ${__PORT_REGEX} ]]; then
    return 1
  fi

  if (( port < min || port > max )); then
    return 1
  fi

  return 0
}

get_urls() {
  get_mysql_root_password
  get_link_git
  get_instancia_add
  get_max_whats
  get_max_user
  get_frontend_url
  get_backend_url
  get_frontend_port
  get_backend_port
  get_redis_port
}

software_update() {
  get_empresa_atualizar
  frontend_update
  backend_update
}

software_delete() {
  get_empresa_delete
  deletar_tudo
}

software_bloquear() {
  get_empresa_bloquear
  configurar_bloqueio
}

software_desbloquear() {
  get_empresa_desbloquear
  configurar_desbloqueio
}

software_dominio() {
  get_empresa_dominio
  get_alter_frontend_url
  get_alter_backend_url
  get_alter_frontend_port
  get_alter_backend_port
  configurar_dominio
}

backup() {
  executar_backup
}

inquiry_options() {
  print_banner
  printf "${WHITE} 💻 Bem vindo(a), selecione abaixo a próxima ação!${GRAY_LIGHT}"
  printf "\n\n"
  printf "   [0] ☕ Instalar Sistema\n"
  printf "   [1] 🔂 Atualizar Sistema\n"
  printf "   [2] ❌ Deletar Sistema\n"
  printf "   [3] 🆔 Bloquear Sistema\n"
  printf "   [4] 🔀 Desbloquear Sistema\n"
  printf "   [5] 🔓 Alterar domínio do Sistema\n"
  printf "   [6] 💾 Backup Banco Sistema\n"
  printf "\n"
  read -r -p "> " option

  case "${option}" in
    0) get_urls ;;
    1)
      software_update
      exit
      ;;
    2)
      software_delete
      exit
      ;;
    3)
      software_bloquear
      exit
      ;;
    4)
      software_desbloquear
      exit
      ;;
    5)
      software_dominio
      exit
      ;;
    6)
      backup
      exit
      ;;
    *) exit ;;
  esac
}


