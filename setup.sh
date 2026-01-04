#!/usr/bin/env bash

set -euo pipefail

# -----------------------------------------------------------------------------
# Helper functions
# -----------------------------------------------------------------------------

step_confirm() {
    printf "\n[STEP] %s\n" "$1"
    printf "Proceed? [y/N] "
    read -r response
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

info() {
    printf "[INFO] %s\n" "$1"
}

error() {
    printf "[ERROR] %s\n" "$1" >&2
    exit 1
}

check_command() {
    command -v "$1" >/dev/null 2>&1
}

check_ssh_keys() {
    [ -f "$HOME/.ssh/keys.d/default" ] && [ -f "$HOME/.ssh/keys.d/default.pub" ]
}

check_stow_available() {
    check_command stow
}

# -----------------------------------------------------------------------------
# Pre-flight checks
# -----------------------------------------------------------------------------

info "Running pre-flight checks..."

if [ "$(id -u)" = "0" ]; then
    error "This script must not be run as root"
fi

if ! check_ssh_keys; then
    error "SSH keys not found. Please copy them to ~/.ssh/keys.d/default[.pub] before running this script"
fi

mkdir -p "$HOME/.local/bin"
info "Pre-flight checks passed"

# -----------------------------------------------------------------------------
# Detect if we're in post-reboot phase
# -----------------------------------------------------------------------------

POST_REBOOT=false
if check_stow_available; then
    POST_REBOOT=true
    info "Post-reboot phase detected (Stow is available)"
    info "Skipping rpm-ostree and shell change steps"
fi

# -----------------------------------------------------------------------------
# Step 1: Layer system packages
# -----------------------------------------------------------------------------

if [ "$POST_REBOOT" = false ]; then
    step_description="Layer ZSH, GNU Stow, and 1Password via rpm-ostree (requires reboot to take effect)"
    if step_confirm "$step_description"; then
        zsh_installed="no"
        if rpm -q zsh &>/dev/null; then zsh_installed="yes"; fi

        stow_installed="no"
        if rpm -q stow &>/dev/null; then stow_installed="yes"; fi

        onepassword_installed="no"
        if rpm -q 1password &>/dev/null; then onepassword_installed="yes"; fi

        if [ "$zsh_installed" = "no" ] || [ "$stow_installed" = "no" ] || [ "$onepassword_installed" = "no" ]; then
            info "Installing ZSH, Stow, and 1Password..."
            rpm-ostree install zsh stow https://downloads.1password.com/linux/rpm/stable/x86_64/1password-latest.rpm
            info "ZSH, Stow, and 1Password installed successfully"
            info "NOTE: These packages will not be available until you reboot"
        else
            info "ZSH, Stow, and 1Password already layered, skipping"
        fi
    else
        error "Setup cancelled by user"
    fi
else
    info "Skipping Step 1 (post-reboot phase)"
fi

# -----------------------------------------------------------------------------
# Step 2: Clone dotfiles
# -----------------------------------------------------------------------------

step_description="Clone dotfiles repository"
if step_confirm "$step_description"; then
    if [ ! -d "$HOME/code/dotfiles" ]; then
        info "Creating ~/code directory..."
        mkdir -p "$HOME/code"

        info "Cloning dotfiles..."
        git -c user.name="Bootstrap" -c user.email="bootstrap@example.com" \
            clone https://github.com/monooso/dotfiles.git "$HOME/code/dotfiles"

        if [ ! -d "$HOME/code/dotfiles" ]; then
            error "Failed to clone dotfiles repository"
        fi
        info "Dotfiles cloned successfully"
    else
        info "Dotfiles already exist, skipping"
    fi
else
    error "Setup cancelled by user"
fi

# -----------------------------------------------------------------------------
# Step 3: Install dotfiles with Stow
# -----------------------------------------------------------------------------

step_description="Install dotfiles using GNU Stow"
if step_confirm "$step_description"; then
    if [ ! -L "$HOME/.zshrc" ]; then
        info "Installing dotfiles..."
        cd "$HOME/code/dotfiles" || error "Failed to change to dotfiles directory"
        stow -t "$HOME" .

        if [ ! -L "$HOME/.zshrc" ]; then
            error "Failed to install dotfiles (symlinks not created)"
        fi
        info "Dotfiles installed successfully"

        info "Refreshing font cache..."
        fc-cache --really-force
        info "Font cache refreshed successfully"
    else
        info "Dotfiles already installed, skipping"
    fi
else
    error "Setup cancelled by user"
fi

# -----------------------------------------------------------------------------
# Step 4: Install Mise
# -----------------------------------------------------------------------------

step_description="Install Mise (version manager)"
if step_confirm "$step_description"; then
    if [ ! -f "$HOME/.local/bin/mise" ]; then
        info "Installing Mise..."
        curl https://mise.run | sh

        if [ ! -f "$HOME/.local/bin/mise" ]; then
            error "Failed to install Mise"
        fi
        info "Mise installed successfully"
    else
        info "Mise already installed, skipping"
    fi
else
    error "Setup cancelled by user"
fi

# -----------------------------------------------------------------------------
# Step 5: Install Starship
# -----------------------------------------------------------------------------

step_description="Install Starship prompt"
if step_confirm "$step_description"; then
    if [ ! -f "$HOME/.local/bin/starship" ]; then
        info "Installing Starship..."
        curl -sS https://starship.rs/install.sh | sh -s -- -b "$HOME/.local/bin"

        if [ ! -f "$HOME/.local/bin/starship" ]; then
            error "Failed to install Starship"
        fi
        info "Starship installed successfully"
    else
        info "Starship already installed, skipping"
    fi
else
    error "Setup cancelled by user"
fi

# -----------------------------------------------------------------------------
# Step 6: Install rclone
# -----------------------------------------------------------------------------

step_description="Install rclone"
if step_confirm "$step_description"; then
    if [ ! -f "$HOME/.local/bin/rclone" ]; then
        info "Installing rclone..."
        tmp_dir=$(mktemp -d)
        curl -sL https://downloads.rclone.org/rclone-current-linux-amd64.zip -o "$tmp_dir/rclone.zip"
        unzip -j "$tmp_dir/rclone.zip" "*/rclone" -d "$HOME/.local/bin"
        chmod +x "$HOME/.local/bin/rclone"
        rm -rf "$tmp_dir"

        if [ ! -f "$HOME/.local/bin/rclone" ]; then
            error "Failed to install rclone"
        fi
        info "rclone version: $("$HOME/.local/bin/rclone" version | head -1)"
        info "rclone installed successfully"
    else
        info "rclone already installed, skipping"
    fi
else
    error "Setup cancelled by user"
fi

# -----------------------------------------------------------------------------
# Step 7: Install LazyGit
# -----------------------------------------------------------------------------

step_description="Install LazyGit"
if step_confirm "$step_description"; then
    if [ ! -f "$HOME/.local/bin/lazygit" ]; then
        info "Installing LazyGit..."
        tmp_dir=$(mktemp -d)
        latest_url=$(curl -s https://api.github.com/repos/jesseduffield/lazygit/releases/latest | \
            grep -o '"browser_download_url":"[^"]*linux_amd64.tar.gz"' | \
            head -1 | \
            sed 's/"browser_download_url":"\([^"]*\)"/\1/')

        if [ -z "$latest_url" ]; then
            error "Failed to extract LazyGit download URL from GitHub API"
        fi

        curl -sL "$latest_url" -o "$tmp_dir/lazygit.tar.gz"
        tar -xzf "$tmp_dir/lazygit.tar.gz" -C "$tmp_dir" --strip-components=1 lazygit
        mv "$tmp_dir/lazygit" "$HOME/.local/bin/"
        chmod +x "$HOME/.local/bin/lazygit"
        rm -rf "$tmp_dir"

        if [ ! -f "$HOME/.local/bin/lazygit" ]; then
            error "Failed to install LazyGit"
        fi
        info "LazyGit installed successfully"
    else
        info "LazyGit already installed, skipping"
    fi
else
    error "Setup cancelled by user"
fi

# -----------------------------------------------------------------------------
# Step 8: Install Distrobox
# -----------------------------------------------------------------------------

step_description="Install Distrobox"
if step_confirm "$step_description"; then
    if ! check_command distrobox; then
        info "Installing Distrobox..."
        curl -s https://raw.githubusercontent.com/89luca89/distrobox/main/install | sh -s -- --prefix "$HOME/.local"

        if ! check_command distrobox; then
            error "Failed to install Distrobox"
        fi

        info "Distrobox version: $(distrobox --version)"
        info "Distrobox installed successfully"
    else
        info "Distrobox already installed, skipping"
    fi
else
    error "Setup cancelled by user"
fi

# -----------------------------------------------------------------------------
# Step 9: Create Distrobox containers
# -----------------------------------------------------------------------------

step_description="Create Distrobox containers (dev, build-neovim, build-mise-erlang)"
if step_confirm "$step_description"; then
    script_dir="$(cd "$(dirname "$0")" && pwd)"
    ini_file="$script_dir/distrobox.ini"

    if [ ! -f "$ini_file" ]; then
        error "distrobox.ini not found in script directory: $script_dir"
    fi

    existing_containers=$(distrobox list 2>/dev/null | grep -cE 'dev|build-neovim|build-mise-erlang' || echo "0")

    if [ "$existing_containers" -lt 3 ]; then
        info "Creating Distrobox containers from $ini_file..."
        cd "$script_dir" || error "Failed to change to script directory"
        distrobox-assemble create

        if distrobox list | grep -qE 'dev|build-neovim|build-mise-erlang'; then
            info "Containers created successfully"
        else
            error "Failed to create containers"
        fi
    else
        info "All containers already exist, skipping"
    fi
else
    error "Setup cancelled by user"
fi

# -----------------------------------------------------------------------------
# Step 10: Install Flatpak applications
# -----------------------------------------------------------------------------

step_description="Install Flatpak applications"
if step_confirm "$step_description"; then
    apps=(
        "com.brave.Browser"
        "com.discordapp.Discord"
        "com.fastmail.Fastmail"
        "com.github.marhkb.Pods"
        "com.github.tchx84.Flatseal"
        "com.google.Chrome"
        "com.mattjakeman.ExtensionManager"
        "com.spotify.Client"
        "com.todoist.Todoist"
        "com.usebruno.Bruno"
        "dev.mufeed.Wordbook"
        "dev.zed.Zed"
        "io.github.pieterdd.RcloneShuttle"
        "it.mijorus.gearlever"
        "md.obsidian.Obsidian"
        "org.gnome.Solanum"
        "org.gnome.gitlab.somas.Apostrophe"
        "org.mozilla.firefox"
        "page.tesk.Refine"
    )

    if ! flatpak remote-list | grep -q flathub; then
        info "Adding Flathub remote..."
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    fi

    info "Installing Flatpak applications..."

    failed_apps=()
    for app in "${apps[@]}"; do
        if ! flatpak install "$app" --noninteractive --or-update; then
            failed_apps+=("$app")
        fi
    done

    if [ ${#failed_apps[@]} -gt 0 ]; then
        error "Failed to install Flatpak applications: ${failed_apps[*]}"
    fi

    info "${#apps[@]} Flatpak applications installed successfully"
else
    error "Setup cancelled by user"
fi

# -----------------------------------------------------------------------------
# Step 11: Change default shell to ZSH
# -----------------------------------------------------------------------------

if [ "$POST_REBOOT" = false ]; then
    step_description="Change default shell to ZSH (requires reboot to take effect)"
    if step_confirm "$step_description"; then
        if [ "$SHELL" != "/bin/zsh" ]; then
            info "Changing default shell to ZSH..."
            chsh -s /bin/zsh
            info "Shell changed to ZSH successfully (will take effect after reboot)"
        else
            info "Shell is already ZSH, skipping"
        fi
    else
        error "Setup cancelled by user"
    fi
else
    info "Skipping Step 11 (post-reboot phase)"
fi

# -----------------------------------------------------------------------------
# Step 12: Completion message
# -----------------------------------------------------------------------------

if [ "$POST_REBOOT" = false ]; then
    cat <<EOF

========================================
Pre-reboot phase completed!
========================================

The following items were configured:
- ZSH, GNU Stow, and 1Password (layered via rpm-ostree)
- Default shell changed to ZSH

IMPORTANT: You MUST reboot for following changes to take effect:
- rpm-ostree layered packages (ZSH, Stow, 1Password)
- Default shell change

After reboot, run this script again to continue setup.

Would you like to reboot now? [y/N]
EOF

    read -r reboot_response
    case "$reboot_response" in
        [yY][eE][sS]|[yY])
            info "Rebooting system..."
            sudo reboot
            ;;
        *)
            info "Pre-reboot phase complete. Please reboot when ready, then re-run this script."
            ;;
    esac
else
    cat <<EOF

========================================
Setup completed successfully!
========================================

The following items were installed:
- Dotfiles (cloned and symlinked)
- Mise (version manager)
- Starship prompt
- rclone
- LazyGit
- 1Password
- Distrobox and containers (dev, build-neovim, build-mise-erlang)
- Flatpak applications

Your development environment is ready to use!

EOF
fi
