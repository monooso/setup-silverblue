# Distroboxes

A collection of Distrobox containers for development on Fedora Silverblue (or other atomic desktops).

## Philosophy

On an immutable operating system like Fedora Silverblue, you cannot install packages directly. You must "layer" them using `rpm-ostree`, which can be cumbersome and introduces system-level changes.

This project takes a different approach: live and work primarily inside containers. By using Distrobox, I get:

- Complete OS isolation for development tools and dependencies
- Access to my home directory, SSH keys, and dotfiles (no copying or mounting)
- The ability to run binaries and GUI applications on the host regardless of container OS

### Key Principles

- **Avoid package managers on the host** - minimise what needs to be layered with `rpm-ostree`
- **Isolate build dependencies** - use dedicated containers for building binaries from source
- **Manage languages with Mise** - handle Go, Node, Erlang, etc. via a single tool
- **Install minimal packages** - prefer scripts and user-space installations over full package manager installations

## Architecture

### Containers

This repository defines three containers using `distrobox-assemble`:

#### `dev`

The main development environment. All development work happens here.

Contains essential CLI tools:
- `bat` - improved `cat`
- `fd-find` - improved `find`
- `fzf` - fuzzy finder
- `gcc` - required for Treesitter in Neovim
- `ripgrep` - fast grep
- `stow` - symlink farm manager
- `tmux` - terminal multiplexer
- `wl-clipboard` - Wayland clipboard utilities
- `zsh` - shell (will be removed when layered on host)

#### `build-neovim`

Isolates the build dependencies required to compile Neovim from source.

Dependencies: `cmake`, `curl`, `gcc`, `gettext`, `git`, `glibc-gconv-extra`, `make`, `ninja-build`

**Workflow**:
1. Enter container: `distrobox enter build-neovim`
2. Run build script from dotfiles (installs to `~/.local/bin`)
3. Neovim becomes available to host and `dev` container via shared home directory

#### `build-mise-erlang`

Isolates the build dependencies required for Mise to compile Erlang/OTP from source.

Dependencies: `autoconf`, `automake`, `g++`, `ncurses-devel`, `openssl-devel`

**Workflow**:
1. Enter container: `distrobox enter build-mise-erlang`
2. Run `mise install erlang@<version>`
3. Erlang becomes available to host and `dev` container via `~/.local/share/mise`

**Note**: Erlang is singled out because it is particularly difficult to compile on Fedora and requires many dependencies. Other languages (Go, Node, etc.) are typically easier for Mise to handle directly.

## Prerequisites

### Host System

- Fedora Silverblue (or another atomic desktop)
- A terminal emulator (I use [Ghostty](https://ghostty.org))

### Host Packages

Install these on the host system (layered via `rpm-ostree`):

- Distrobox: use the [official install script](https://distrobox.it/#installation)
- ZSH: `rpm-ostree install zsh`
- Optional: Ghostty (available as [Flatpak](https://flathub.org/apps/details/com.mitchellh.ghostty) or [AppImage](https://ghostty.org/docs/install/binary#universal-appimage))

## Setup

1. Clone this repository
2. Run `distrobox-assemble create` to build all containers
3. Clone your dotfiles repository
4. Install user-space tools (Mise, Starship, etc.) via their official scripts to `~/.local/bin`
5. Configure your terminal emulator to automatically enter the `dev` container on new sessions

**Ghostty configuration**:
```ini
command = distrobox enter dev
```

## Workflows

### Daily Development

- All development work happens inside the `dev` container
- Your terminal automatically enters `dev` on launch
- All tools are available via `~/.local/bin` (shared with host)
- Language versions are managed via Mise

### Building Neovim

1. Enter `build-neovim` container
2. Run build script from dotfiles
3. Binary is installed to `~/.local/bin` and available everywhere

### Installing a New Erlang Version

1. Enter `build-mise-erlang` container
2. Run `mise install erlang@<version>`
3. Erlang is installed to `~/.local/share/mise` and available everywhere

### Installing Other Languages

1. Enter `dev` container (or use it directly)
2. Run `mise install <tool>@<version>`
3. Tool is installed to `~/.local/share/mise` and available everywhere

## Decision Log

### Why not use Distrobox export?

Distrobox can export binaries and GUI applications from containers, allowing them to run on the host without manually entering the container. This works well for self-contained tools like LazyGit, but fails for tools that need to interact with Unix pipes (e.g. `ls | fzf`).

Living inside the `dev` container provides a more consistent experience and avoids these limitations.

### Why avoid `dnf install` in containers?

Package managers handle security updates and dependency resolution automatically. Installing tools via scripts requires manual updates and introduces potential version drift.

However, in some cases, `dnf install` brings unwanted dependencies. For example, `dnf install neovim` also installs Node.js, which could interfere with project-specific Node versions managed by Mise.

This is a trade-off I'm still evaluating. The current approach favours avoiding unwanted dependencies, at the cost of manual update workflows.

### Why separate build containers?

Building tools from source requires dependencies that you don't need at runtime. For example, compiling Neovim requires CMake, Ninja, and build tools that serve no purpose once the binary is built.

By using dedicated build containers, these dependencies are isolated and don't pollute your main development environment.

### Why Erlang gets special treatment?

Erlang/OTP is particularly finicky to compile on Fedora, requiring many development packages. Other languages (Go, Node, etc.) are typically easier for Mise to handle directly without needing a separate container.

If you find other languages causing similar issues, you can create additional `build-*` containers following the same pattern.

## Future Improvements

- Automate build workflows with scripts in this repository
- Consolidate setup steps into a single script
- Consider automating updates for user-space tools
