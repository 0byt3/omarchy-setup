# Omarchy setup scripts

Omarchy is an Arch Linux-based distribution built on customized Hyprland and QuickShell.
Website: https://omarchy.org
Repo: https://github.com/basecamp/omarchy

## Project details

This project modifies a fresh Omarchy install for necessary customizations including both removing unwanted pre-installed software/webapps, installing additional software/webapps and applying configuration files.

`install-applications.nu` performs idempotent installation of software.

`deploy-configuration.nu` performs the deployment of configurations to customize various tools, UI and environment.

Neovim configuration lives in `neovim/` and is deployed to `~/.config/nvim`. Plugins listed in `neovim/plugins.nuon` are cloned into `~/.local/share/nvim/plugins/<name>` and copied to `~/.config/nvim/pack/external/start/<name>` when the upstream revision changes. Treesitter parsers cover Bash, JSON, JSONL (via JSON), TOML, YAML, Markdown, Nushell, Odin, and Rust. Formatting uses Topiary for Nushell, Bash, JSON, and TOML, yamlfmt for YAML, mdformat for Markdown, jq for JSONL, odinfmt for Odin, and rustfmt for Rust. rust-analyzer provides Rust language-server support and runs Clippy for diagnostics.

Shell aliases live in `bash/aliases.bash`, deployed to `~/.config/basic-cli/aliases.bash` and sourced from `~/.bashrc`, and in `nushell/autoload/aliases.nu`, deployed to `~/.config/nushell/autoload`. Both define `mdv` for `md-view` and `nv` for `nvim`.

The point of two separate scripts is such that deployment of configurations can happen independently of installation.

## Installed tools

- Bootstrap tools: Nushell, Charm, Glow, Gum, and VHS.
- Herdr: terminal workspace manager for AI coding agents, with a Cursor skill generated from `herdr --skill`.
- Development tools: Ansible linting and language-server support, Git, Python, Node.js/npm, SQLite, Tree-sitter CLI, jq, yamlfmt, mdformat, yamllint, shellcheck, Marksman, Odin, OLS, odinfmt, Rust, rust-analyzer, rust-src, and curl.
- Neovim: the pacman `neovim` and `omarchy-nvim` packages are removed, and the official GitHub nightly tarball is installed to `/opt/neovim`.
- Topiary: the official GitHub release is installed to `~/.local/share/topiary`, with `topiary-nushell` queries cloned to `~/.local/share/topiary-nushell` and deployed to `~/.config/topiary`. It formats Nushell, Bash, JSON, and TOML.
- Microsandbox: the official GitHub release is installed to `~/.microsandbox`, with `msb` and `microsandbox` linked in `~/.local/bin`. Local sandboxes require KVM.
- `mvm`: a custom command that starts a microsandbox VM from the YAML config files in the current path's `.mvm` directory. `sandbox.yaml` and other files load with `--conf`; `resources`, `runtime`, `fs`, `network`, `secrets`, and `scripts` files load with the matching scoped flag. An existing sandbox is started, `mvm --replace` recreates it, and `mvm --dry-run` prints the `msb` commands. Scripts named `setup` and `setup-*` run once after the sandbox is created, and `start-*` scripts run each time `mvm` boots it.
- PowerShell and PowerShell Editor Services.
- MCP services: UniFi, Warehouse Explorer, Microsoft Graph, Nushell, and Playwright.
- OneDrive: the abraunegg client is built from source with a monitor wrapper that exposes client status and synchronization events to the custom Omarchy OneDrive plugin.
- `initdev`: a custom command for creating and modifying Cursor MCP-server settings, devcontainer configuration, and `mvm` microVM configuration from the templates installed in `~/.config/initdev`. `initdev mvm` scaffolds `.mvm` from an Ubuntu 24.04 template and adds the setup scripts, environment variables, and `PATH` entries for the selected features: Docker, .NET, Go, Java, Node.js, Nushell, PowerShell, Python, and Rust.
- Discord: the official Arch package, replacing Omarchy's default Discord web app.
- Web apps: Copilot, OneDrive, Outlook, Outlook (Personal), To Do, YouTube, YouTube Music, and Twitch. Personal-profile apps use `~/.local/share/chromium-profiles/personal`.
- pgAdmin: `pgadminc start` and `pgadminc stop` manage the official `dpage/pgadmin4` container, listening on `https://127.0.0.1:5050`. The first start prompts for the default password.
