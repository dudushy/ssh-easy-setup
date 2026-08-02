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
- Detectar seu usuário e nome da máquina
- Gerar uma chave `ed25519` salva em `~/.ssh/raspberrypi`
- Exibir a chave pública para você copiar

### 2. No Raspberry Pi — Configuração inicial (1ª vez)

```bash
curl -sSL https://raw.githubusercontent.com/dudushy/ssh-easy-setup/main/server/setup-pi.sh | bash
```

O script irá:
1. Habilitar autenticação por chave pública
2. Pedir que você adicione sua chave
3. Pedir confirmação de que testou a conexão
4. Desabilitar login por senha (somente após confirmação)
5. Instalar aliases úteis (`ssh-list-keys`, `ssh-add-key`)

### 3. Adicionando novos dispositivos (após setup)

No Pi, use o alias:
```bash
ssh-add-key "ssh-ed25519 AAAA... usuario@MAQUINA"
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
  #    TIPO           NOME                      ADICIONADA
  ---  -----------    ----------------------    ----------
  1    ssh-ed25519    dudushy@BLACKAO           2026-08-02
  2    ssh-ed25519    dudushy@NOTEBOOK          2026-08-03
```

## Parâmetros do script do servidor

O `setup-pi.sh` aceita parâmetros para adicionar a chave sem modo interativo:

```bash
# Via arquivo
curl -sSL .../server/setup-pi.sh | bash -s -- --file-path=/tmp/chave.pub

# Via texto direto
curl -sSL .../server/setup-pi.sh | bash -s -- --raw-data="ssh-ed25519 AAAA... usuario@MAQUINA"

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

| Item            | Valor                     |
| --------------- | ------------------------- |
| Tipo de chave   | ed25519                   |
| Nome do arquivo | `~/.ssh/raspberrypi`      |
| Identificação   | `usuario@NOME_DA_MAQUINA` |
| Passphrase      | Opcional                  |
| Usuário no Pi   | `pi`                      |

## Segurança

O script do servidor segue uma ordem segura para evitar lock-out:
1. ✅ Habilita autenticação por chave
2. ✅ Adiciona pelo menos 1 chave
3. ✅ Usuário confirma que testou a conexão
4. ✅ Só então desabilita login por senha

Se você não confirmar o teste, o login por senha **não** será desabilitado.

## Licença

MIT
