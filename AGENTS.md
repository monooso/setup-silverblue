# Agent Guidelines

This repository contains automated setup scripts and Distrobox container configurations for Fedora Silverblue development environments.

## Build and Validation

### Running the Setup Script
```bash
./setup.sh
```

The setup script runs in two phases:
1. **Pre-reboot**: Layers system packages (ZSH, Stow) and changes default shell
2. **Post-reboot**: Installs dotfiles, user-space tools, containers, and Flatpaks

### Script Behaviour
- Script automatically detects post-reboot phase (checks if Stow is available)
- Each step requires user confirmation before proceeding
- Fails immediately on errors (set -euo pipefail)
- Logs progress with [STEP], [INFO], and [ERROR] prefixes

### Validation
No automated tests exist. Validate setup manually:
- Ensure all containers are created: `distrobox list`
- Verify dotfiles are symlinked: `ls -la ~ | grep .zshrc`
- Check user-space tools are installed: `ls -la ~/.local/bin/`

## Code Style Guidelines

### Bash Scripting (setup.sh)

#### Shell Directives
```bash
#!/usr/bin/env bash
set -euo pipefail
```
- Use strict mode for error handling
- Fail on unset variables, pipeline errors, and non-zero exit codes

#### Structure
- Section dividers using 77-character lines: `# -----------------------------------------------------------------------------`
- Group related functionality with clear section headers
- Helper functions at top of file, before main logic
- Use blank lines between logical sections

#### Functions
- Snake_case function names: `step_confirm`, `check_command`, `check_ssh_keys`
- Helper functions first, then main logic
- Functions should return 0 for success, 1 for failure
- Use descriptive names that indicate purpose

#### Error Handling
- Use `error()` function for fatal errors (calls exit 1)
- Use `info()` for informational messages
- Prefix all messages with [STEP], [INFO], or [ERROR] for visibility
- Always validate prerequisites before proceeding
- Provide clear error messages that explain what went wrong and why

#### User Interaction
- Require confirmation before destructive operations: `step_confirm()`
- Use [y/N] prompts for confirmation (N is default)
- Present clear step descriptions in confirmation prompts
- Cancel setup if user declines confirmation

#### Variables and Quoting
- Always quote variable expansions: `"$1"`, `"$HOME"`, etc.
- Use uppercase for constants: `POST_REBOOT=false`
- Use lowercase for local variables: `script_dir`, `ini_file`
- Prefer `$HOME` over `~` in paths (more reliable in scripts)

#### Command Execution
- Check command existence before use: `check_command distrobox`
- Use `command -v` for checking (POSIX compliant)
- Silence stderr/stdout where appropriate: `2>/dev/null`
- Chain commands with `&&` for dependencies
- Use arrays for lists: `apps=("app1" "app2")`

#### Conditionals
- Use `[ "$VAR" = "value" ]` for string comparison
- Use `[ "$BOOL" = false ]` for boolean checks
- Prefer `[[ ]]` over `[ ]` for complex conditions (bashism)
- Use `if ! command; then` for negation

#### Git Operations
- Use `-c user.name` and `-c user.email` for bootstrap clones
- Clone to specific directories with explicit paths
- Validate clone succeeded before proceeding

### Distrobox Configuration (distrobox.ini)

#### Section Headers
- Use descriptive section names in square brackets: `[dev]`, `[build-neovim]`
- Group related containers together (main vs build containers)
- Add blank line between section groups

#### Annotations
- Use `@note` for important implementation details
- Use `@see` for external documentation references
- Keep annotations concise and relevant

#### Configuration
- Specify base image: `image=fedora:latest`
- List packages in a single string: `additional_packages="pkg1 pkg2 pkg3"`
- Alphabetically order packages for readability
- Document special requirements inline

## Conventions

### Language and Locale
- British English for user-facing messages: "cloned", "cancelled"
- American English for code and technical terms: "dev", "build"
- Write code comments in American English

### Naming
- Container names: kebab-case (dev, build-neovim, build-mise-erlang)
- Files: kebab-case (distrobox.ini, setup.sh)
- Use descriptive names that indicate purpose

### Documentation
- README.md in the repository root
- Inline comments explain why, not what (code is self-documenting)
- Document non-obvious requirements and workflows
- Include decision log for architectural choices

### Security
- Never run setup script as root (explicit check)
- Require SSH keys before cloning dotfiles
- Validate commands exist before execution
- Use `curl` with verification for downloads (HTTPS only)
