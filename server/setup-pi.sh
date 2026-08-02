#!/usr/bin/env bash
# =============================================================================
# SSH Easy Setup - Server Script (Raspberry Pi)
# Configura o Pi para aceitar conexões SSH via chave pública,
# instala aliases úteis e desabilita login por senha (com segurança).
# Executar apenas 1 vez.
# =============================================================================

set -e

# --- Cores ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

# --- Funções de output ---
header() {
    echo ""
    echo -e "${CYAN}=============================================${NC}"
    echo -e "${CYAN}   SSH Easy Setup - Configuracao do Pi${NC}"
    echo -e "${CYAN}=============================================${NC}"
    echo ""
}

step() {
    echo -e "${YELLOW}[*]${NC} $1"
}

success() {
    echo -e "${GREEN}[+]${NC} $1"
}

error() {
    echo -e "${RED}[!]${NC} $1"
}

info() {
    echo -e "    ${GRAY}$1${NC}"
}

warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# --- Variáveis globais ---
SSH_DIR="${HOME}/.ssh"
AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"
SSHD_CONFIG="/etc/ssh/sshd_config"
METADATA_FILE="${SSH_DIR}/.keys_metadata"

# Detectar o shell do usuário e definir o RC file correto
detect_shell_rc() {
    local user_shell
    user_shell=$(basename "${SHELL:-/bin/bash}")

    case "${user_shell}" in
        zsh)
            SHELL_RC="${HOME}/.zshrc"
            SHELL_NAME="zsh"
            ;;
        bash)
            SHELL_RC="${HOME}/.bashrc"
            SHELL_NAME="bash"
            ;;
        *)
            # Fallback: verificar se .zshrc existe (pode estar usando zsh sem $SHELL atualizado)
            if [ -f "${HOME}/.zshrc" ]; then
                SHELL_RC="${HOME}/.zshrc"
                SHELL_NAME="zsh"
            else
                SHELL_RC="${HOME}/.bashrc"
                SHELL_NAME="bash"
            fi
            ;;
    esac
}

# --- Funções auxiliares ---

ensure_ssh_dir() {
    if [ ! -d "${SSH_DIR}" ]; then
        step "Criando diretorio ~/.ssh..."
        mkdir -p "${SSH_DIR}"
        chmod 700 "${SSH_DIR}"
    fi

    if [ ! -f "${AUTHORIZED_KEYS}" ]; then
        touch "${AUTHORIZED_KEYS}"
        chmod 600 "${AUTHORIZED_KEYS}"
    fi

    if [ ! -f "${METADATA_FILE}" ]; then
        touch "${METADATA_FILE}"
    fi
}

# Extrair o comentário de uma chave pública
get_key_comment() {
    local key="$1"
    echo "${key}" | awk '{print $3}'
}

# Extrair o tipo de uma chave pública
get_key_type() {
    local key="$1"
    echo "${key}" | awk '{print $1}'
}

# Validar formato da chave pública
validate_key() {
    local key="$1"
    if echo "${key}" | grep -qE "^ssh-(ed25519|rsa|ecdsa|dsa) [A-Za-z0-9+/=]+ .+$"; then
        return 0
    fi
    # Tentar sem comentário
    if echo "${key}" | grep -qE "^ssh-(ed25519|rsa|ecdsa|dsa) [A-Za-z0-9+/=]+$"; then
        return 0
    fi
    return 1
}

# Verificar se a chave já existe no authorized_keys
key_exists() {
    local key="$1"
    local key_data
    key_data=$(echo "${key}" | awk '{print $2}')
    grep -qF "${key_data}" "${AUTHORIZED_KEYS}" 2>/dev/null
}

# Adicionar chave ao authorized_keys
add_key_to_file() {
    local key="$1"
    local date_added
    date_added=$(date +%Y-%m-%d)
    local comment
    comment=$(get_key_comment "${key}")

    if key_exists "${key}"; then
        warn "Chave ja existe no authorized_keys: ${comment}"
        return 1
    fi

    echo "${key}" >> "${AUTHORIZED_KEYS}"
    echo "${date_added}|${comment}" >> "${METADATA_FILE}"
    success "Chave adicionada: ${comment} (${date_added})"
    return 0
}

# Ler chave de arquivo
read_key_from_file() {
    local file_path="$1"
    if [ ! -f "${file_path}" ]; then
        error "Arquivo nao encontrado: ${file_path}"
        return 1
    fi
    cat "${file_path}"
}

# Pedir chave interativamente (lê do /dev/tty para funcionar via pipe)
read_key_interactive() {
    local key=""
    while true; do
        echo "" > /dev/tty
        echo -e "${YELLOW}[*]${NC} Cole a chave publica abaixo e pressione ENTER:" > /dev/tty
        echo -e "    ${GRAY}Exemplo: ssh-ed25519 AAAA...dados... usuario@MAQUINA-OS${NC}" > /dev/tty
        echo -e "    ${GRAY}(Digite 'q' para cancelar)${NC}" > /dev/tty
        echo "" > /dev/tty
        echo -n "  > " > /dev/tty
        read -r key < /dev/tty

        # Permitir sair
        if [ "${key}" = "q" ] || [ "${key}" = "Q" ]; then
            echo "" > /dev/tty
            echo -e "${RED}[!]${NC} Operacao cancelada pelo usuario." > /dev/tty
            echo ""
            return 1
        fi

        # Validar antes de retornar
        if validate_key "${key}"; then
            echo "${key}"
            return 0
        fi

        echo "" > /dev/tty
        echo -e "${RED}[!]${NC} Formato invalido. A chave deve comecar com:" > /dev/tty
        echo -e "    ${GRAY}ssh-ed25519, ssh-rsa, ssh-ecdsa ou ssh-dsa${NC}" > /dev/tty
        echo -e "    ${GRAY}Seguido dos dados da chave e o comentario.${NC}" > /dev/tty
    done
}

# Pedir confirmação (lê do /dev/tty para funcionar via pipe)
read_confirm() {
    local prompt="$1"
    local response
    read -r -p "${prompt}" response < /dev/tty
    echo "${response}"
}

# --- Configuração do sshd_config ---

configure_sshd_pubkey() {
    step "Configurando PubkeyAuthentication..."

    if grep -q "^PubkeyAuthentication yes" "${SSHD_CONFIG}"; then
        info "PubkeyAuthentication ja esta habilitado."
    else
        sudo sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' "${SSHD_CONFIG}"
        # Se a linha não existia, adicionar
        if ! grep -q "^PubkeyAuthentication yes" "${SSHD_CONFIG}"; then
            echo "PubkeyAuthentication yes" | sudo tee -a "${SSHD_CONFIG}" > /dev/null
        fi
        success "PubkeyAuthentication habilitado."
    fi
}

disable_password_auth() {
    step "Desabilitando autenticacao por senha..."

    sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "${SSHD_CONFIG}"
    # Se a linha não existia, adicionar
    if ! grep -q "^PasswordAuthentication no" "${SSHD_CONFIG}"; then
        echo "PasswordAuthentication no" | sudo tee -a "${SSHD_CONFIG}" > /dev/null
    fi
    success "PasswordAuthentication desabilitado."
}

restart_ssh() {
    step "Reiniciando servico SSH..."
    sudo systemctl restart ssh 2>/dev/null || sudo systemctl restart sshd 2>/dev/null
    success "Servico SSH reiniciado."
}

# --- Instalação dos aliases ---

install_aliases() {
    step "Instalando aliases no ${SHELL_RC} (${SHELL_NAME})..."

    # Verificar se os aliases já existem
    if grep -q "# --- SSH Easy Setup Aliases ---" "${SHELL_RC}" 2>/dev/null; then
        warn "Aliases ja estao instalados. Atualizando..."
        # Remover aliases antigos
        sed -i '/# --- SSH Easy Setup Aliases ---/,/# --- End SSH Easy Setup Aliases ---/d' "${SHELL_RC}"
    fi

    cat >> "${SHELL_RC}" << 'ALIASES'

# --- SSH Easy Setup Aliases ---

# Lista todas as chaves SSH autorizadas
ssh-list-keys() {
    local authorized_keys="${HOME}/.ssh/authorized_keys"
    local metadata_file="${HOME}/.ssh/.keys_metadata"

    if [ ! -f "${authorized_keys}" ] || [ ! -s "${authorized_keys}" ]; then
        echo "Nenhuma chave encontrada em ${authorized_keys}"
        return
    fi

    echo ""
    printf "  %-4s %-14s %-25s %-10s %-12s\n" "#" "TIPO" "NOME" "OS" "ADICIONADA"
    printf "  %-4s %-14s %-25s %-10s %-12s\n" "---" "-----------" "----------------------" "--------" "----------"

    local i=1
    while IFS= read -r line; do
        [ -z "${line}" ] && continue
        local key_type key_comment date_added os_name user_host
        key_type=$(echo "${line}" | awk '{print $1}')
        key_comment=$(echo "${line}" | awk '{print $3}')
        [ -z "${key_comment}" ] && key_comment="(sem nome)"

        # Extrair OS do comentário (formato: usuario@MAQUINA-OS)
        os_name=""
        if echo "${key_comment}" | grep -q ".*@.*-"; then
            os_name=$(echo "${key_comment}" | sed 's/.*-//')
            user_host=$(echo "${key_comment}" | sed 's/-[^-]*$//')
        else
            os_name="--"
            user_host="${key_comment}"
        fi

        # Tentar buscar data do metadata
        date_added=""
        if [ -f "${metadata_file}" ]; then
            date_added=$(grep "|${key_comment}$" "${metadata_file}" | tail -1 | cut -d'|' -f1)
        fi
        [ -z "${date_added}" ] && date_added="desconhecida"

        printf "  %-4s %-14s %-25s %-10s %-12s\n" "${i}" "${key_type}" "${user_host}" "${os_name}" "${date_added}"
        i=$((i + 1))
    done < "${authorized_keys}"
    echo ""
}

# Adiciona uma nova chave SSH ao authorized_keys
ssh-add-key() {
    local key="$1"
    local metadata_file="${HOME}/.ssh/.keys_metadata"
    local authorized_keys="${HOME}/.ssh/authorized_keys"

    # Se não recebeu argumento, modo interativo
    if [ -z "${key}" ]; then
        echo ""
        echo "[*] Cole a chave publica abaixo e pressione ENTER:"
        echo ""
        read -r key
    fi

    # Validar
    if ! echo "${key}" | grep -qE "^ssh-(ed25519|rsa|ecdsa|dsa) [A-Za-z0-9+/=]+"; then
        echo "[!] Formato de chave invalido."
        echo "    Formato esperado: ssh-ed25519 AAAA... usuario@maquina"
        return 1
    fi

    # Verificar duplicata
    local key_data
    key_data=$(echo "${key}" | awk '{print $2}')
    if grep -qF "${key_data}" "${authorized_keys}" 2>/dev/null; then
        echo "[!] Esta chave ja esta autorizada."
        return 1
    fi

    # Adicionar
    echo "${key}" >> "${authorized_keys}"
    local comment date_added
    comment=$(echo "${key}" | awk '{print $3}')
    date_added=$(date +%Y-%m-%d)
    echo "${date_added}|${comment}" >> "${metadata_file}"

    echo "[+] Chave adicionada com sucesso: ${comment} (${date_added})"
}

# Remove uma chave SSH do authorized_keys pelo número
ssh-remove-key() {
    local key_number="$1"
    local metadata_file="${HOME}/.ssh/.keys_metadata"
    local authorized_keys="${HOME}/.ssh/authorized_keys"

    if [ ! -f "${authorized_keys}" ] || [ ! -s "${authorized_keys}" ]; then
        echo "[!] Nenhuma chave encontrada."
        return 1
    fi

    # Se não recebeu argumento, mostrar lista e pedir número
    if [ -z "${key_number}" ]; then
        ssh-list-keys
        echo ""
        echo -n "[*] Digite o numero da chave para remover (ou 'q' para cancelar): "
        read -r key_number
    fi

    # Cancelar
    if [ "${key_number}" = "q" ] || [ "${key_number}" = "Q" ]; then
        echo "[*] Operacao cancelada."
        return 0
    fi

    # Validar número
    if ! echo "${key_number}" | grep -qE "^[0-9]+$"; then
        echo "[!] Numero invalido."
        return 1
    fi

    # Contar chaves válidas
    local total_keys
    total_keys=$(grep -c "^ssh-" "${authorized_keys}" 2>/dev/null || echo "0")

    if [ "${key_number}" -lt 1 ] || [ "${key_number}" -gt "${total_keys}" ]; then
        echo "[!] Numero fora do intervalo (1-${total_keys})."
        return 1
    fi

    # Obter a chave pela posição
    local key_line key_comment
    key_line=$(grep "^ssh-" "${authorized_keys}" | sed -n "${key_number}p")
    key_comment=$(echo "${key_line}" | awk '{print $3}')
    [ -z "${key_comment}" ] && key_comment="(sem nome)"

    # Confirmar remoção
    echo ""
    echo "[!] Remover chave #${key_number}: ${key_comment}?"
    echo -n "    Confirma? (s/N): "
    read -r confirm

    if [ "${confirm}" != "s" ] && [ "${confirm}" != "S" ]; then
        echo "[*] Operacao cancelada."
        return 0
    fi

    # Remover a linha do authorized_keys
    local key_data
    key_data=$(echo "${key_line}" | awk '{print $2}')
    sed -i "\|${key_data}|d" "${authorized_keys}"

    # Remover do metadata
    if [ -f "${metadata_file}" ] && [ -n "${key_comment}" ] && [ "${key_comment}" != "(sem nome)" ]; then
        sed -i "\|${key_comment}$|d" "${metadata_file}"
    fi

    echo "[+] Chave removida: ${key_comment}"
}

# --- End SSH Easy Setup Aliases ---
ALIASES

    success "Aliases instalados: ssh-list-keys, ssh-add-key, ssh-remove-key"
}

# --- Fluxo principal ---

main() {
    header

    # Verificar se está no Pi (ou pelo menos Linux)
    if [ "$(uname)" != "Linux" ]; then
        error "Este script deve ser executado no Raspberry Pi (Linux)."
        exit 1
    fi

    # Detectar shell do usuário
    detect_shell_rc

    step "Iniciando configuracao do Raspberry Pi..."
    info "Shell detectado: ${SHELL_NAME} (${SHELL_RC})"
    echo ""

    # 1. Garantir diretório SSH
    ensure_ssh_dir

    # 2. Configurar PubkeyAuthentication
    configure_sshd_pubkey

    # 3. Adicionar pelo menos uma chave
    echo ""
    echo -e "${CYAN}=============================================${NC}"
    echo -e "${CYAN}   ADICIONAR CHAVE SSH${NC}"
    echo -e "${CYAN}=============================================${NC}"
    echo ""

    # Verificar se já existem chaves no authorized_keys
    local existing_keys=0
    if [ -f "${AUTHORIZED_KEYS}" ] && [ -s "${AUTHORIZED_KEYS}" ]; then
        existing_keys=$(grep -c "^ssh-" "${AUTHORIZED_KEYS}" 2>/dev/null || echo "0")
    fi

    local key=""
    local key_from_param=false
    local skip_add=false

    # Verificar se recebeu parâmetros
    for arg in "$@"; do
        case "${arg}" in
            --file-path=*)
                local file_path="${arg#*=}"
                key=$(read_key_from_file "${file_path}")
                key_from_param=true
                ;;
            --raw-data=*)
                key="${arg#*=}"
                key_from_param=true
                ;;
        esac
    done

    if [ -z "${key}" ] && [ "${existing_keys}" -gt 0 ]; then
        # Já existem chaves — oferecer opção de pular
        success "Ja existem ${existing_keys} chave(s) no authorized_keys."
        echo ""
        step "Deseja adicionar outra chave ou pular para a configuracao de seguranca?"
        echo ""
        info "a = Adicionar outra chave"
        info "p = Pular (ir direto para desabilitar senha)"
        echo ""
        local choice
        choice=$(read_confirm "    Escolha (a/p): ")

        if [ "${choice}" = "p" ] || [ "${choice}" = "P" ]; then
            skip_add=true
        fi
    fi

    if [ "${skip_add}" = false ]; then
        # Precisa adicionar uma chave
        if [ "${existing_keys}" -eq 0 ]; then
            step "Voce precisa adicionar pelo menos 1 chave antes de desabilitar o login por senha."
            echo ""
        fi

        # Se não recebeu parâmetros, modo interativo
        if [ -z "${key}" ]; then
            key=$(read_key_interactive)
            if [ $? -ne 0 ] || [ -z "${key}" ]; then
                # Usuário cancelou
                if [ "${existing_keys}" -eq 0 ]; then
                    error "Nenhuma chave adicionada. Abortando."
                    exit 1
                else
                    warn "Nenhuma chave nova adicionada. Continuando com as existentes..."
                fi
            else
                # Só valida se veio de parâmetro (interativo já validou)
                if [ "${key_from_param}" = true ]; then
                    if ! validate_key "${key}"; then
                        error "Formato de chave invalido."
                        info "Formato esperado: ssh-ed25519 AAAA... usuario@maquina-OS"
                        exit 1
                    fi
                fi
                add_key_to_file "${key}" || true
            fi
        else
            # Veio de parâmetro
            if [ "${key_from_param}" = true ]; then
                if ! validate_key "${key}"; then
                    error "Formato de chave invalido."
                    info "Formato esperado: ssh-ed25519 AAAA... usuario@maquina-OS"
                    exit 1
                fi
            fi
            add_key_to_file "${key}" || true
        fi
    fi

    # 4. Pedir confirmação de teste e desabilitar senha
    echo ""
    echo -e "${CYAN}=============================================${NC}"
    echo -e "${CYAN}   CONFIGURACAO DE SEGURANCA${NC}"
    echo -e "${CYAN}=============================================${NC}"
    echo ""

    # Verificar se senha já está desabilitada
    if grep -q "^PasswordAuthentication no" "${SSHD_CONFIG}"; then
        info "PasswordAuthentication ja esta desabilitado."
        echo ""
    else
        warn "IMPORTANTE: Antes de desabilitar o login por senha,"
        warn "teste a conexao SSH com a chave em OUTRO terminal:"
        echo ""
        echo -e "    ${YELLOW}ssh -i ~/.ssh/raspberrypi pi@<IP_DO_PI>${NC}"
        echo ""
        step "A conexao via chave funcionou corretamente?"
        echo ""
        confirm=$(read_confirm "    Digite 's' para confirmar ou 'n' para cancelar: ")

        if [ "${confirm}" != "s" ] && [ "${confirm}" != "S" ]; then
            echo ""
            warn "Operacao parcial: PubkeyAuthentication esta habilitado mas login por senha NAO foi desabilitado."
            info "Voce ainda pode acessar o Pi com senha."
            info "Quando testar a chave, rode novamente este script ou execute manualmente:"
            info "  sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config"
            info "  sudo systemctl restart ssh"
            echo ""

            # Instalar aliases mesmo sem desabilitar senha
            install_aliases
            echo ""
            success "Aliases instalados! Rode 'source ${SHELL_RC}' para ativar."
            echo ""
            exit 0
        fi

        # 5. Desabilitar login por senha
        echo ""
        disable_password_auth

        # 6. Reiniciar SSH
        restart_ssh
    fi

    # 7. Instalar aliases
    echo ""
    install_aliases

    # --- Finalização ---
    echo ""
    echo -e "${CYAN}=============================================${NC}"
    echo -e "${CYAN}   CONFIGURACAO CONCLUIDA!${NC}"
    echo -e "${CYAN}=============================================${NC}"
    echo ""
    success "Resumo:"
    info "- PubkeyAuthentication: habilitado"
    info "- PasswordAuthentication: desabilitado"
    info "- Aliases instalados em: ${SHELL_RC}"
    echo ""
    step "Rode 'source ${SHELL_RC}' para ativar os aliases nesta sessao."
    echo ""
    step "Comandos disponiveis:"
    info "ssh-list-keys         - Lista todas as chaves autorizadas"
    info "ssh-add-key           - Adiciona uma nova chave (interativo)"
    info "ssh-add-key \"chave\"   - Adiciona uma nova chave (direto)"
    info "ssh-remove-key        - Remove uma chave (interativo)"
    info "ssh-remove-key <num>  - Remove uma chave pelo numero"
    echo ""
}

# Executar com argumentos passados ao script
main "$@"
