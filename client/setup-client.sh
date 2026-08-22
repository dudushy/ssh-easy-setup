#!/usr/bin/env bash
# =============================================================================
# SSH Easy Setup - Client Script (Linux/Mac Bash)
# Gera um par de chaves SSH ed25519 para conexão com qualquer servidor SSH
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

    # Perguntar alias SSH
    echo -e "${CYAN}=============================================${NC}"
    echo -e "${CYAN}   CONFIGURACAO DA CHAVE${NC}"
    echo -e "${CYAN}=============================================${NC}"
    echo ""
    step "Qual alias deseja usar para conectar via SSH?"
    info "Exemplo: 'ssh server', 'ssh prod', 'ssh homelab'"
    echo ""
    echo -n "    Alias [padrao: server]: " > /dev/tty
    read -r HOST_ALIAS < /dev/tty
    [ -z "${HOST_ALIAS}" ] && HOST_ALIAS="server"
    echo ""

    # Perguntar nome do arquivo da chave
    step "Qual nome para o arquivo da chave?"
    info "Sera salvo em: ~/.ssh/<nome>"
    echo ""
    echo -n "    Nome do arquivo [padrao: ${HOST_ALIAS}]: " > /dev/tty
    read -r KEY_NAME < /dev/tty
    [ -z "${KEY_NAME}" ] && KEY_NAME="${HOST_ALIAS}"
    echo ""

    # Definir caminho da chave
    SSH_DIR="${HOME}/.ssh"
    KEY_PATH="${SSH_DIR}/${KEY_NAME}"
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
    echo -e "${CYAN}   SUA CHAVE PUBLICA (copie e adicione no servidor)${NC}"
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
    info "No servidor, use o alias para adicionar esta chave:"
    echo ""
    echo -e "    ${YELLOW}ssh-add-key \"${GREEN}${PUBLIC_KEY}${YELLOW}\"${NC}"
    echo ""
    info "Ou, se for a primeira vez configurando o servidor:"
    echo -e "    ${YELLOW}curl -sSL https://raw.githubusercontent.com/dudushy/ssh-easy-setup/main/server/setup-server.sh | bash${NC}"
    echo ""

    # Configurar ~/.ssh/config
    echo ""
    echo -e "${CYAN}=============================================${NC}"
    echo -e "${CYAN}   CONFIGURAR SSH CONFIG${NC}"
    echo -e "${CYAN}=============================================${NC}"
    echo ""
    step "Deseja configurar o ~/.ssh/config para conectar facilmente ao servidor?"
    info "Isso permite usar 'ssh ${HOST_ALIAS}' ao inves de 'ssh -i ~/.ssh/${KEY_NAME} user@host'"
    echo ""
    echo -n "    Configurar? (S/n) " > /dev/tty
    read -r config_choice < /dev/tty

    if [ "${config_choice}" != "n" ] && [ "${config_choice}" != "N" ]; then
        echo ""
        echo -n "    Digite o hostname ou IP do servidor (ex: 192.168.1.100 ou server.exemplo.com): " > /dev/tty
        read -r server_host < /dev/tty

        if [ -z "${server_host}" ]; then
            error "Hostname vazio. Pulando configuracao do SSH config."
        else
            echo -n "    Digite o usuario do servidor: " > /dev/tty
            read -r server_user < /dev/tty

            if [ -z "${server_user}" ]; then
                error "Usuario obrigatorio. Pulando configuracao do SSH config."
            else
                echo -n "    Digite a porta SSH [padrao: 22]: " > /dev/tty
                read -r server_port < /dev/tty
                [ -z "${server_port}" ] && server_port="22"

                SSH_CONFIG="${SSH_DIR}/config"

                # Montar bloco com Port apenas se diferente de 22
                if [ "${server_port}" = "22" ]; then
                    NEW_BLOCK="
Host ${HOST_ALIAS}
    HostName ${server_host}
    User ${server_user}
    IdentityFile ~/.ssh/${KEY_NAME}"
                else
                    NEW_BLOCK="
Host ${HOST_ALIAS}
    HostName ${server_host}
    User ${server_user}
    Port ${server_port}
    IdentityFile ~/.ssh/${KEY_NAME}"
                fi

                # Verificar se já existe um bloco com esse alias no config
                if [ -f "${SSH_CONFIG}" ] && grep -q "^Host ${HOST_ALIAS}$" "${SSH_CONFIG}"; then
                    info "Ja existe um bloco 'Host ${HOST_ALIAS}' no config."
                    echo -n "    Deseja sobrescrever? (s/N) " > /dev/tty
                    read -r overwrite_config < /dev/tty

                    if [ "${overwrite_config}" = "s" ] || [ "${overwrite_config}" = "S" ]; then
                        # Remover bloco antigo (do "Host alias" até o próximo "Host " ou fim do arquivo)
                        sed -i "/^Host ${HOST_ALIAS}$/,/^Host /{/^Host ${HOST_ALIAS}$/d;/^Host /!d}" "${SSH_CONFIG}"
                        # Remover linhas vazias consecutivas no final
                        sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "${SSH_CONFIG}"
                        echo "${NEW_BLOCK}" >> "${SSH_CONFIG}"
                        success "SSH config atualizado!"
                    else
                        info "Config mantido sem alteracoes."
                    fi
                else
                    # Criar arquivo se não existir
                    touch "${SSH_CONFIG}"
                    chmod 600 "${SSH_CONFIG}"
                    echo "${NEW_BLOCK}" >> "${SSH_CONFIG}"
                    success "SSH config configurado!"
                fi

                echo ""
                success "Agora voce pode conectar com: ssh ${HOST_ALIAS}"
            fi
        fi
    fi
    echo ""
}

# Executar
main
