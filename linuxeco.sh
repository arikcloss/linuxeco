#!/bin/bash

# -----------------------------------------------------------------------------
# Script de Instalação Automática - Linuxeco
# -----------------------------------------------------------------------------

# 1. Configuração Inicial e Segurança
# -----------------------------------------------------------------------------
# Termina o script imediatamente se qualquer comando falhar
set -e

# Verifica se está rodando como root
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, rode este script como root (sudo ./script.sh)"
  exit 1
fi

# Define variáveis de ambiente não-interativas
export DEBIAN_FRONTEND=noninteractive

# Identifica o usuário real (quem invocou o sudo) e seu home
REAL_USER="${SUDO_USER:-$USER}"
if [ "$REAL_USER" = "root" ]; then
    echo "AVISO: Rodando diretamente como root. Algumas ferramentas (Homebrew/Rust) podem não funcionar como esperado para usuários normais."
    USER_HOME="/root"
else
    USER_HOME=$(eval echo "~$REAL_USER")
fi

echo "-------------------------------------------"
echo " Iniciando Instalação Linuxeco "
echo " Usuário Alvo: $REAL_USER"
echo " Home Alvo: $USER_HOME"
echo "-------------------------------------------"

# 2. Atualização do Sistema e Instalação de Dependências Base
# -----------------------------------------------------------------------------
echo "-> Atualizando repositórios e sistema..."
apt-get update -y
apt-get upgrade -y

echo "-> Instalando ferramentas essenciais e o Flatpak..."
# Nota: Adicionei 'flatpak', 'ca-certificates' e 'gnupg' que eram necessários
apt-get install -y build-essential gcc g++ make cmake autoconf automake \
libtool git git-lfs subversion colordiff python3 python3-venv python3-dev \
default-jdk jq yq curl wget ssh rsync tmux screen strace ltrace net-tools \
dnsutils iputils-ping sqlite3 shellcheck cloc tree ncdu flatpak audacious \
ca-certificates gnupg software-properties-common

# 3. Configuração Flatpak e Flathub
# -----------------------------------------------------------------------------
echo "-> Configurando Flathub..."
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Lista de aplicativos Flatpak
FLATPAK_APPS=(
    "com.vscodium.codium"
    "io.dbeaver.DBeaverCommunity"
    "org.strawberrymusicplayer.strawberry"
    "org.audacityteam.Audacity"
    "org.ardour.Ardour"
    "org.gimp.GIMP"
    "org.kde.krita"
    "com.github.PintaProject.Pinta"
    "org.inkscape.Inkscape"
    "org.darktable.Darktable"
    "org.kde.kdenlive"
    "org.flameshot.Flameshot"
    "com.obsproject.Studio"
    "md.obsidian.Obsidian"
)

echo "-> Instalando aplicativos Flatpak..."
for app in "${FLATPAK_APPS[@]}"; do
    flatpak install -y flathub "$app"
done

# 4. Instalação Node.js (LTS via Nodesource)
# -----------------------------------------------------------------------------
if ! command -v node &> /dev/null; then
    echo "-> Instalando Node.js (LTS)..."
    # Usamos -sSf para modo silencioso e seguir redirecionamentos
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    apt-get install -y nodejs
else
    echo "-> Node.js já instalado. Pulando..."
fi

# 5. Instalação Rust (Como usuário real)
# -----------------------------------------------------------------------------
# Verifica se o cargo já existe no contexto do usuário real
if [ ! -f "$USER_HOME/.cargo/env" ]; then
    echo "-> Instalando Rust para o usuário $REAL_USER..."
    # Usamos 'su' para rodar como o usuário real, pois Rust não deve ser rodado como root
    su - "$REAL_USER" -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'
else
    echo "-> Rust já instalado para o usuário $REAL_USER. Pulando..."
fi

# 6. Instalação e Configuração do Starship Prompt
# -----------------------------------------------------------------------------
if ! command -v starship &> /dev/null; then
    echo "-> Instalando Starship Prompt..."
    curl -sS https://starship.rs/install.sh | sh -s -- --yes
else
    echo "-> Starship já instalado. Pulando..."
fi

# Configuração do .bashrc
TARGET_BASHRC="$USER_HOME/.bashrc"
if [ -f "$TARGET_BASHRC" ]; then
    # Backup
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    cp "$TARGET_BASHRC" "$TARGET_BASHRC.bak_$TIMESTAMP"
    
    # Adiciona init do Starship se não existir
    if ! grep -q "starship init bash" "$TARGET_BASHRC"; then
        echo 'eval "$(starship init bash)"' >> "$TARGET_BASHRC"
    fi

    # Adiciona Rust path se não existir (necessário se o login não for interativo)
    if ! grep -q ".cargo/env" "$TARGET_BASHRC"; then
        echo 'source "$HOME/.cargo/env"' >> "$TARGET_BASHRC"
    fi

    # Cria config do Starship
    mkdir -p "$USER_HOME/.config"
    /usr/local/bin/starship preset plain-text-symbols -o "$USER_HOME/.config/starship.toml"
    
    # Corrige permissões
    chown -R "$REAL_USER:$REAL_USER" "$USER_HOME/.config"
fi

# 7. Instalação Homebrew (Como usuário real)
# -----------------------------------------------------------------------------
if ! command -v /home/linuxbrew/.linuxbrew/bin/brew &> /dev/null; then
    echo "-> Instalando Homebrew para o usuário $REAL_USER..."
    # Executa a instalação como o usuário real
    su - "$REAL_USER" -c 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    
    # Adiciona ao .bashrc se não existir
    BREW_ENV='eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
    if ! grep -q "linuxbrew" "$TARGET_BASHRC"; then
        su - "$REAL_USER" -c "echo '$BREW_ENV' >> ~/.bashrc"
    fi
else
    echo "-> Homebrew já instalado. Pulando..."
fi

# 8. Limpeza
# -----------------------------------------------------------------------------
echo "-> Limpando pacotes desnecessários..."
apt-get autoremove -y
apt-get clean

echo "-------------------------------------------"
echo " Instalação concluída com sucesso! "
echo "-------------------------------------------"
echo " Para aplicar as mudanças, reinicie o terminal"
echo " ou execute: source ~/.bashrc"
echo "-------------------------------------------"
