#!/bin/bash

# Ensure the script is run as root (required for apt)
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root (sudo ./script.sh)"
  exit 1
fi

# Set non-interactive mode for apt (prevents configuration prompts)
export DEBIAN_FRONTEND=noninteractive

echo " Starting Automated Linuxeco Installation "
# 1. System Update
echo "-> Updating the system..."
apt-get update -y && apt-get upgrade -y

# 2. Development Tools & Utilities (APT)
echo "-> Installing essential development tools and utilities..."
apt-get install -y build-essential gcc g++ make cmake autoconf automake \
libtool git git-lfs subversion colordiff python3 python3-venv python3-dev \
default-jdk jq yq curl wget ssh rsync tmux screen strace ltrace net-tools \
dnsutils iputils-ping sqlite3 shellcheck cloc tree ncdu flatpak audacious

# 3. Flatpak Configuration (Adds Flathub repository if missing)
echo "-> Configuring Flatpak and Flathub..."
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# 4. Flatpak Applications Installation (-y ensures automation)
echo "-> Installing Flatpak applications..."
flatpak install -y flathub com.vscodium.codium
flatpak install -y flathub io.dbeaver.DBeaverCommunity
flatpak install -y flathub org.strawberrymusicplayer.strawberry
flatpak install -y flathub org.audacityteam.Audacity
flatpak install -y flathub org.ardour.Ardour
flatpak install -y flathub org.gimp.GIMP
flatpak install -y flathub org.kde.krita
flatpak install -y flathub com.github.PintaProject.Pinta
flatpak install -y flathub org.inkscape.Inkscape
flatpak install -y flathub org.darktable.Darktable
flatpak install -y flathub org.kde.kdenlive
flatpak install -y flathub org.flameshot.Flameshot
flatpak install -y flathub com.obsproject.Studio
flatpak install -y md.obsidian.Obsidian

# 5. Node.js Installation (via Official Nodesource LTS Repository)
echo "-> Installing Node.js (LTS)..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs

# 6. Rust Installation (Non-interactive mode)
echo "-> Installing Rust..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
# Make 'cargo' and 'rustc' commands immediately available in the current session
source "$HOME/.cargo/env"

# 7. Starship Prompt Installation & Bash Configuration
echo "-> Installing Starship Prompt..."
curl -sS https://starship.rs/install.sh | sh -s -- --yes

# Identify the real user and their home directory
REAL_USER="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$REAL_USER")
TARGET_BASHRC="$USER_HOME/.bashrc"

if [ -f "$TARGET_BASHRC" ]; then
    # Create a timestamped backup of .bashrc inside the user's home directory
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_BASHRC="$TARGET_BASHRC.bak_$TIMESTAMP"
    echo "-> Backing up $TARGET_BASHRC to $BACKUP_BASHRC..."
    cp "$TARGET_BASHRC" "$BACKUP_BASHRC"
    chown "$REAL_USER:$REAL_USER" "$BACKUP_BASHRC"

    # Append Starship initialization to .bashrc if not already present
    if ! grep -q "starship init bash" "$TARGET_BASHRC"; then
        echo 'eval "$(starship init bash)"' >> "$TARGET_BASHRC"
    fi
    
    # Create configuration folder if it doesn't exist and set the preset
    TARGET_CONFIG="$USER_HOME/.config"
    mkdir -p "$TARGET_CONFIG"
    /usr/local/bin/starship preset plain-text-symbols -o "$TARGET_CONFIG/starship.toml"
    
    # Adjust file permissions for the configuration directory
    chown -R "$REAL_USER:$REAL_USER" "$TARGET_CONFIG"
fi

# 8. Homebrew Installation (Must run as a standard user, not root)
if [ -n "$SUDO_USER" ]; then
    echo "-> Installing Homebrew for user $REAL_USER..."
    # Executes Linuxbrew installation silently using the NONINTERACTIVE flag
    su - "$REAL_USER" -c 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    
    # Configure Homebrew environment variables in the user profile for immediate use
    BREW_ENV='eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
    su - "$REAL_USER" -c "echo '$BREW_ENV' >> ~/.bash_profile"
fi

# Housekeeping: Clean up unnecessary packages
apt-get autoremove -y && apt-get clean

echo " Installation completed successfully!     "
echo " Restart your terminal to apply Starship  "
echo " and Homebrew changes.                    "
