# Omarchy setup scripts

Omarchy is an Arch Linux-based distribution built on customized Hyprland and QuickShell.
Website: https://omarchy.org
Repo: https://github.com/basecamp/omarchy

## Project details

This project modifies a fresh Omarchy install for necessary customizations including both removing unwanted pre-installed software/webapps, installing additional software/webapps and applying configuration files.

`install-applications.nu` performs idempotent installation of software.

`deploy-configuration.nu` performs the deployment of configurations to customize various tools, UI and environment.

The point of two separate scripts is such that deployment of configurations can happen independently of installation.

## Installed tools

- Bootstrap tools: Nushell, Charm, Glow, Gum, and VHS.
- Herdr: terminal workspace manager for AI coding agents, with a Cursor skill generated from `herdr --skill`.
- Development tools: Ansible linting and language-server support, Git, Python, Node.js/npm, SQLite, and curl.
- PowerShell and PowerShell Editor Services.
- MCP services: UniFi, Warehouse Explorer, Microsoft Graph, Nushell, and Playwright.
- OneDrive: the abraunegg client is built from source with a monitor wrapper that exposes client status and synchronization events to the custom Omarchy OneDrive plugin.
- `initdev`: a custom command for creating and modifying Cursor MCP-server settings and devcontainer configuration from the templates installed in `~/.config/initdev`.
