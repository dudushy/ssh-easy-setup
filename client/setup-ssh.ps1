# =============================================================================
# SSH Easy Setup - Client Script (Windows PowerShell)
# Gera um par de chaves SSH ed25519 para conexão com o Raspberry Pi
# =============================================================================

$ErrorActionPreference = "Stop"

# --- Cores e formatação ---
function Write-Header {
    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "   SSH Easy Setup - Gerador de Chave SSH" -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([string]$Message)
    Write-Host "[*] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-Success {
    param([string]$Message)
    Write-Host "[+] " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "[!] " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

function Write-Info {
    param([string]$Message)
    Write-Host "    " -NoNewline
    Write-Host $Message -ForegroundColor Gray
}

# --- Detecção de informações do sistema ---
function Get-SystemInfo {
    $username = $env:USERNAME
    $hostname = $env:COMPUTERNAME

    # Detectar OS
    $os = "Windows"

    return @{
        Username = $username
        Hostname = $hostname
        OS       = $os
        Comment  = "$username@$hostname-$os"
    }
}

# --- Main ---
function Main {
    Write-Header

    # Detectar informações do sistema
    $sysInfo = Get-SystemInfo
    Write-Step "Informacoes detectadas:"
    Write-Info "Usuario:  $($sysInfo.Username)"
    Write-Info "Maquina:  $($sysInfo.Hostname)"
    Write-Info "Sistema:  $($sysInfo.OS)"
    Write-Info "Comentario da chave: $($sysInfo.Comment)"
    Write-Host ""

    # Definir caminho da chave
    $sshDir = Join-Path $env:USERPROFILE ".ssh"
    $keyPath = Join-Path $sshDir "raspberrypi"
    $keyPathPub = "$keyPath.pub"

    # Criar diretório .ssh se não existir
    if (-not (Test-Path $sshDir)) {
        Write-Step "Criando diretorio ~/.ssh..."
        New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
    }

    # Verificar se a chave já existe
    if (Test-Path $keyPath) {
        Write-Error-Custom "A chave ja existe em: $keyPath"
        Write-Host ""
        $overwrite = Read-Host "    Deseja sobrescrever? (s/N)"
        if ($overwrite -ne "s" -and $overwrite -ne "S") {
            Write-Host ""
            Write-Step "Operacao cancelada."
            Write-Host ""
            Write-Step "Sua chave publica existente:"
            Write-Host ""
            $existingKey = Get-Content $keyPathPub
            Write-Host "    $existingKey" -ForegroundColor Green
            Write-Host ""
            return
        }
        # Remover chaves existentes para sobrescrever
        Remove-Item $keyPath -Force
        Remove-Item $keyPathPub -Force
    }

    # Perguntar sobre passphrase
    Write-Host ""
    Write-Step "Passphrase (senha para proteger a chave):"
    Write-Info "Pressione ENTER para deixar sem senha (menos seguro, mais pratico)"
    Write-Host ""
    $passphrase = Read-Host "    Digite a passphrase (ou ENTER para vazio)"

    # Gerar a chave
    Write-Host ""
    Write-Step "Gerando chave SSH ed25519..."

    $sshKeygenArgs = @(
        "-t", "ed25519",
        "-C", $sysInfo.Comment,
        "-f", $keyPath,
        "-N", $passphrase
    )

    $process = Start-Process -FilePath "ssh-keygen" -ArgumentList $sshKeygenArgs -NoNewWindow -Wait -PassThru

    if ($process.ExitCode -ne 0) {
        Write-Error-Custom "Erro ao gerar a chave SSH."
        return
    }

    # Verificar se a chave foi criada
    if (-not (Test-Path $keyPathPub)) {
        Write-Error-Custom "Erro: chave publica nao encontrada em $keyPathPub"
        return
    }

    Write-Success "Chave gerada com sucesso!"
    Write-Host ""
    Write-Step "Arquivos criados:"
    Write-Info "Chave privada: $keyPath"
    Write-Info "Chave publica: $keyPathPub"

    # Exibir a chave pública
    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "   SUA CHAVE PUBLICA (copie e adicione no Pi)" -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
    $publicKey = Get-Content $keyPathPub
    Write-Host "    $publicKey" -ForegroundColor Green
    Write-Host ""
    Write-Host "=============================================" -ForegroundColor Cyan

    # Copiar para clipboard se possível
    try {
        $publicKey | Set-Clipboard
        Write-Success "Chave copiada para a area de transferencia!"
    } catch {
        Write-Info "(Nao foi possivel copiar automaticamente para o clipboard)"
    }

    # Instruções do próximo passo
    Write-Host ""
    Write-Step "Proximo passo:"
    Write-Info "No Raspberry Pi, use o alias para adicionar esta chave:"
    Write-Host ""
    Write-Host '    ssh-add-key "' -NoNewline -ForegroundColor Yellow
    Write-Host "$publicKey" -NoNewline -ForegroundColor Green
    Write-Host '"' -ForegroundColor Yellow
    Write-Host ""
    Write-Info "Ou, se for a primeira vez configurando o Pi:"
    Write-Host '    curl -sSL https://raw.githubusercontent.com/dudushy/ssh-easy-setup/main/server/setup-pi.sh | bash' -ForegroundColor Yellow
    Write-Host ""
}

# Executar
Main
