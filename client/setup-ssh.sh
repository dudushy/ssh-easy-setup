#!/usr/bin/env bash
# =============================================================================
# SSH Easy Setup - Client Script (Linux/Mac Bash)
# Gera um par de chaves SSH ed25519 para conexão com o Raspberry Pi
# =============================================================================

set -e

# --- Cores ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# --- Funções de output ---
header() {
    echo ""
    echo -e "${CYAN}=============================================${NC}"
    echo -e "${CYAN}   SSH Easy Setup - Gerador de Chave SSH${NC}"
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

# --- Detecção de informações do sistema ---
detect_system_info() {
    USERNAME=$(whoami)
    HOSTNAME_DETECTED=$(hostname)

    # Detectar OS
    case "$(uname -s)" in
        Linux*)
            if [ -f /etc/os-release ]; then
                OS_NAME=$(. /etc/os-release && echo "${ID^}")
                # Capitalizar primeira letra
                OS_NAME=$(echo "${OS_NAME}" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')
            else
                OS_NAME="Linux"
            fi
            ;;
        Darwin*)
            OS_NAME="macOS"
            ;;
        *)
            OS_NAME="Unknown"
            ;;
    esac

    COMMENT="${USERNAME}@${HOSTNAME_DETECTED}-${OS_NAME}"
}

# --- Main ---
main() {
    header

    # Detectar informações do sistema
    detect_system_info
    step "Informacoes detectadas:"
    info "Usuario:  ${USERNAME}"
    info "Maquina:  ${HOSTNAME_DETECTED}"
    info "Sistema:  ${OS_NAME}"
    info "Comentario da chave: ${COMMENT}"
    echo ""

    # Definir caminho da chave
    SSH_DIR="${HOME}/.ssh"
    KEY_PATH="${SSH_DIR}/raspberrypi"
    KEY_PATH_PUB="${KEY_PATH}.pub"

    # Criar diretório .ssh se não existir
    if [ ! -d "${SSH_DIR}" ]; then
        step "Criando diretorio ~/.ssh..."
        mkdir -p "${SSH_DIR}"
        chmod 700 "${SSH_DIR}"
    fi

    # Verificar se a chave já existe
    if [ -f "${KEY_PATH}" ]; then
        error "A chave ja existe em: ${KEY_PATH}"
        echo ""
        echo -n "    Deseja sobrescrever? (s/N) " > /dev/tty
        read -r overwrite < /dev/tty
        if [ "${overwrite}" != "s" ] && [ "${overwrite}" != "S" ]; then
            echo ""
            step "Operacao cancelada."
            echo ""
            step "Sua chave publica existente:"
            echo ""
            echo -e "    ${GREEN}$(cat "${KEY_PATH_PUB}")${NC}"
            echo ""
            return
        fi
        # Remover chaves existentes para sobrescrever
        rm -f "${KEY_PATH}" "${KEY_PATH_PUB}"
    fi

    # Perguntar sobre passphrase
    echo ""
    step "Passphrase (senha para proteger a chave):"
    info "Pressione ENTER para deixar sem senha (menos seguro, mais pratico)"
    echo ""
    echo -n "    Digite a passphrase (ou ENTER para vazio): " > /dev/tty
    read -r -s PASSPHRASE < /dev/tty
    echo ""

    # Gerar a chave
    echo ""
    step "Gerando chave SSH ed25519..."

    ssh-keygen -t ed25519 -C "${COMMENT}" -f "${KEY_PATH}" -N "${PASSPHRASE}"

    # Verificar se a chave foi criada
    if [ ! -f "${KEY_PATH_PUB}" ]; then
        error "Erro: chave publica nao encontrada em ${KEY_PATH_PUB}"
        return 1
    fi

    # Ajustar permissões
    chmod 600 "${KEY_PATH}"
    chmod 644 "${KEY_PATH_PUB}"

    success "Chave gerada com sucesso!"
    echo ""
    step "Arquivos criados:"
    info "Chave privada: ${KEY_PATH}"
    info "Chave publica: ${KEY_PATH_PUB}"

    # Exibir a chave pública
    PUBLIC_KEY=$(cat "${KEY_PATH_PUB}")
    echo ""
    echo -e "${CYAN}=============================================${NC}"
    echo -e "${CYAN}   SUA CHAVE PUBLICA (copie e adicione no Pi)${NC}"
    echo -e "${CYAN}=============================================${NC}"
    echo ""
    echo -e "    ${GREEN}${PUBLIC_KEY}${NC}"
    echo ""
    echo -e "${CYAN}=============================================${NC}"

    # Copiar para clipboard se possível
    if command -v xclip &> /dev/null; then
        echo "${PUBLIC_KEY}" | xclip -selection clipboard
        success "Chave copiada para a area de transferencia! (xclip)"
    elif command -v xsel &> /dev/null; then
        echo "${PUBLIC_KEY}" | xsel --clipboard
        success "Chave copiada para a area de transferencia! (xsel)"
    elif command -v pbcopy &> /dev/null; then
        echo "${PUBLIC_KEY}" | pbcopy
        success "Chave copiada para a area de transferencia! (pbcopy)"
    elif command -v wl-copy &> /dev/null; then
        echo "${PUBLIC_KEY}" | wl-copy
        success "Chave copiada para a area de transferencia! (wl-copy)"
    else
        info "(Nao foi possivel copiar automaticamente - instale xclip, xsel ou wl-copy)"
    fi

    # Instruções do próximo passo
    echo ""
    step "Proximo passo:"
    info "No Raspberry Pi, use o alias para adicionar esta chave:"
    echo ""
    echo -e "    ${YELLOW}ssh-add-key \"${GREEN}${PUBLIC_KEY}${YELLOW}\"${NC}"
    echo ""
    info "Ou, se for a primeira vez configurando o Pi:"
    echo -e "    ${YELLOW}curl -sSL https://raw.githubusercontent.com/dudushy/ssh-easy-setup/main/server/setup-pi.sh | bash${NC}"
    echo ""
}

# Executar
main
