# SSH Easy Setup 🔑

Scripts para facilitar a criação e gerenciamento de chaves SSH para conexão com o Raspberry Pi.

## Visão Geral

- **Gere chaves SSH** no seu PC (Windows, Linux ou Mac) com um único comando
- **Configure o Pi** para aceitar conexões por chave e desabilitar senha
- **Gerencie chaves** com aliases simples no Pi

## Quick Start

### 1. No seu PC — Gerar a chave SSH

**Windows (PowerShell):**
```powershell
irm https://raw.githubusercontent.com/dudushy/ssh-easy-setup/main/client/setup-ssh.ps1 | iex
```

**Linux/Mac (Bash):**
```bash
curl -sSL https://raw.githubusercontent.com/dudushy/ssh-easy-setup/main/client/setup-ssh.sh | bash
```

O script irá:
- Detectar seu **usuário**, **nome da máquina** e **sistema operacional**
- Gerar uma chave `ed25519` salva em `~/.ssh/raspberrypi`
- Criar o comentário no formato: `usuario@MAQUINA-OS`
- Perguntar se deseja definir uma passphrase (opcional)
- Exibir a chave pública e copiar para a área de transferência

**Exemplo de comentário gerado:**
- Windows: `dudushy@BB1337-Windows`
- Ubuntu: `dudushy@desktop-Ubuntu`
- macOS: `dudushy@MacBook-macOS`

### 2. No Raspberry Pi — Configuração inicial (1ª vez)

```bash
curl -sSL https://raw.githubusercontent.com/dudushy/ssh-easy-setup/main/server/setup-pi.sh | bash
```

O script irá:
1. Detectar o shell do Pi (zsh ou bash) e instalar aliases no arquivo correto
2. Habilitar `PubkeyAuthentication yes`
3. Pedir que você cole/adicione sua chave pública
4. Pedir confirmação de que **testou a conexão** em outro terminal
5. Somente após confirmação: desabilitar `PasswordAuthentication no`
6. Reiniciar o serviço SSH
7. Instalar aliases (`ssh-list-keys`, `ssh-add-key`)

### 3. Adicionando novos dispositivos (após setup)

No Pi, use o alias:
```bash
ssh-add-key "ssh-ed25519 AAAA... usuario@MAQUINA-OS"
```

Ou no modo interativo:
```bash
ssh-add-key
```

### 4. Listando dispositivos autorizados

```bash
ssh-list-keys
```

Saída:
```
  #    TIPO           NOME                      OS         ADICIONADA
  ---  -----------    ----------------------    --------   ----------
  1    ssh-ed25519    dudushy@BB1337            Windows    2026-08-02
  2    ssh-ed25519    dudushy@NOTEBOOK          Ubuntu     2026-08-03
  3    ssh-ed25519    maria@MacBook             macOS      2026-08-05
```

## Parâmetros do script do servidor

O `setup-pi.sh` aceita parâmetros para adicionar a chave sem modo interativo:

```bash
# Via arquivo
curl -sSL .../server/setup-pi.sh | bash -s -- --file-path=/tmp/chave.pub

# Via texto direto
curl -sSL .../server/setup-pi.sh | bash -s -- --raw-data="ssh-ed25519 AAAA... usuario@MAQUINA-OS"

# Modo interativo (o script pede para colar a chave)
curl -sSL .../server/setup-pi.sh | bash
```

> **Nota:** Quando executado via `curl | bash`, o modo interativo lê input do `/dev/tty` (seu teclado), então funciona normalmente mesmo com o pipe.

## Estrutura

```
├── client/
│   ├── setup-ssh.ps1    # Gerador de chaves (Windows PowerShell)
│   └── setup-ssh.sh     # Gerador de chaves (Linux/Mac Bash)
└── server/
    └── setup-pi.sh      # Configuração do Pi (executar 1x)
```

## Decisões Técnicas

| Item | Valor |
|------|-------|
| Tipo de chave | ed25519 |
| Nome do arquivo | `~/.ssh/raspberrypi` |
| Comentário da chave | `usuario@MAQUINA-OS` |
| Passphrase | Opcional (pergunta ao usuário) |
| Usuário no Pi | `pi` |
| Shell suportado | zsh e bash (detecção automática) |
| Input via pipe | Lê de `/dev/tty` (funciona com `curl \| bash`) |

## Segurança

O script do servidor segue uma ordem segura para evitar lock-out:
1. ✅ Habilita autenticação por chave
2. ✅ Adiciona pelo menos 1 chave
3. ✅ Usuário confirma que testou a conexão
4. ✅ Só então desabilita login por senha

Se você não confirmar o teste, o login por senha **não** será desabilitado.

## Licença

MIT
