#!/usr/bin/env nu

const unifi_mcp_repository_url = "https://github.com/emilandersongroup/unifi-mcp.git"
const warehouse_mcp_repository_url = "https://github.com/emilandersongroup/warehouse-mcp-agent.git"
const ms_graph_mcp_repository_url = "https://github.com/emilandersongroup/ms-graph-mcp.git"

def update-git-source [source_directory repository_url branch] {
    if not ($source_directory | path exists) {
        mkdir ($source_directory | path dirname)
        ^git clone --depth 1 --branch $branch $repository_url $source_directory
        return true
    }

    let current_revision = (^git -C $source_directory rev-parse HEAD | str trim)
    ^git -C $source_directory fetch --force --depth 1 origin $branch
    let upstream_revision = (^git -C $source_directory rev-parse $"origin/($branch)" | str trim)

    if $current_revision == $upstream_revision {
        false
    } else {
        ^git -C $source_directory reset --hard $upstream_revision
        true
    }
}

def mcp-source-directory [server_name] {
    $env.HOME | path join ".local" "mcp" $server_name
}

def update-mcp-source [server_name repository_url] {
    update-git-source (mcp-source-directory $server_name) $repository_url "main"
}

def install-unifi-mcp [] {
    let source_directory = (mcp-source-directory "unifi-mcp")

    ^npm --ignore-scripts --prefix $source_directory ci
    ^npm --ignore-scripts --prefix $source_directory run build
}

def install-python-mcp [server_name extras] {
    let source_directory = (mcp-source-directory $server_name)
    let virtual_environment = ($source_directory | path join ".venv")
    let python = ($virtual_environment | path join "bin" "python")

    if not ($virtual_environment | path exists) {
        ^python -m venv $virtual_environment
    }

    run-external $python "-m" "pip" "install" "--disable-pip-version-check" "--editable" $"($source_directory)($extras)"
}

def ensure-mcp-configuration [server_name template_name] {
    let source_directory = (mcp-source-directory $server_name)
    let configuration_path = ($source_directory | path join ".env")

    if ($configuration_path | path exists) {
        true
    } else {
        ^cp ($source_directory | path join $template_name) $configuration_path
        print $"Configure ($configuration_path) before enabling the ($server_name) MCP service."
        false
    }
}

def deploy-mcp-service [service_name service_contents configuration_path configuration_is_ready] {
    let service_directory = ($env.HOME | path join ".config" "systemd" "user")
    let service_path = ($service_directory | path join $service_name)
    let service_existed = ($service_path | path exists)
    let service_was_active = if $service_existed {
        let status = (^systemctl --user is-active --quiet $service_name | complete)
        $status.exit_code == 0
    } else {
        false
    }

    mkdir $service_directory
    ($service_contents + (char newline)) | save --force $service_path
    ^systemctl --user daemon-reload

    if not $configuration_is_ready {
        print $"The ($service_name) service was not enabled because ($configuration_path) needs configuration."
    } else if $service_was_active {
        ^systemctl --user restart $service_name
    } else if not $service_existed {
        ^systemctl --user enable $service_name
    }
}

def deploy-mcp-services [unifi_configured warehouse_configured ms_graph_configured] {
    let unifi_service_contents = (
        [
            "[Unit]"
            "Description=UniFi MCP Server"
            "Documentation=file:%h/.local/mcp/unifi-mcp/README.md"
            "After=network-online.target"
            "Wants=network-online.target"
            ""
            "[Service]"
            "Type=simple"
            "WorkingDirectory=%h/.local/mcp/unifi-mcp"
            "Environment=MCP_TRANSPORT=http"
            "Environment=MCP_HOST=127.0.0.1"
            "Environment=MCP_PORT=8102"
            "ExecStart=/usr/bin/node %h/.local/mcp/unifi-mcp/dist/index.js"
            "Restart=on-failure"
            "RestartSec=5"
            ""
            "[Install]"
            "WantedBy=default.target"
        ]
        | str join (char newline)
    )
    let warehouse_service_contents = (
        [
            "[Unit]"
            "Description=Warehouse Explorer MCP Server"
            "Documentation=file:%h/.local/mcp/warehouse-mcp-agent/README.md"
            "After=network-online.target"
            "Wants=network-online.target"
            ""
            "[Service]"
            "Type=simple"
            "WorkingDirectory=%h/.local/mcp/warehouse-mcp-agent"
            "EnvironmentFile=%h/.local/mcp/warehouse-mcp-agent/.env"
            "ExecStart=%h/.local/mcp/warehouse-mcp-agent/.venv/bin/python %h/.local/mcp/warehouse-mcp-agent/mcp_server/server.py"
            "Restart=on-failure"
            "RestartSec=5"
            ""
            "[Install]"
            "WantedBy=default.target"
        ]
        | str join (char newline)
    )
    let ms_graph_service_contents = (
        [
            "[Unit]"
            "Description=Microsoft Graph MCP Server"
            "Documentation=file:%h/.local/mcp/ms-graph-mcp/README.md"
            "After=network-online.target"
            "Wants=network-online.target"
            ""
            "[Service]"
            "Type=simple"
            "WorkingDirectory=%h/.local/mcp/ms-graph-mcp"
            "ExecStart=%h/.local/mcp/ms-graph-mcp/scripts/run-service.sh"
            "Restart=on-failure"
            "RestartSec=5"
            ""
            "[Install]"
            "WantedBy=default.target"
        ]
        | str join (char newline)
    )
    let nushell_service_contents = (
        [
            "[Unit]"
            "Description=Nushell MCP Server"
            ""
            "[Service]"
            "Type=simple"
            "ExecStart=/usr/bin/nu --mcp --mcp-transport http --mcp-port 8202"
            "Restart=on-failure"
            "RestartSec=5"
            ""
            "[Install]"
            "WantedBy=default.target"
        ]
        | str join (char newline)
    )
    let playwright_service_contents = (
        [
            "[Unit]"
            "Description=Playwright MCP Server"
            ""
            "[Service]"
            "Type=simple"
            "ExecStart=/usr/bin/npx --yes --ignore-scripts @playwright/mcp@latest --host 127.0.0.1 --port 8203 --allowed-hosts localhost 127.0.0.1"
            "Restart=on-failure"
            "RestartSec=5"
            ""
            "[Install]"
            "WantedBy=default.target"
        ]
        | str join (char newline)
    )

    let unifi_configuration_path = ((mcp-source-directory "unifi-mcp") | path join ".env")
    let warehouse_configuration_path = ((mcp-source-directory "warehouse-mcp-agent") | path join ".env")
    let ms_graph_configuration_path = ((mcp-source-directory "ms-graph-mcp") | path join ".env")

    deploy-mcp-service "unifi-mcp.service" $unifi_service_contents $unifi_configuration_path $unifi_configured
    deploy-mcp-service "warehouse-mcp.service" $warehouse_service_contents $warehouse_configuration_path $warehouse_configured
    deploy-mcp-service "ms-graph-mcp.service" $ms_graph_service_contents $ms_graph_configuration_path $ms_graph_configured
    deploy-mcp-service "nushell-mcp.service" $nushell_service_contents "" true
    deploy-mcp-service "playwright-mcp.service" $playwright_service_contents "" true
}

def main [] {
    let missing_commands = (["git" "node" "npm" "npx" "python"] | where {|command| which $command | is-empty })
    if not ($missing_commands | is-empty) {
        error make {msg: $"Missing ($missing_commands | str join ', '); run install-applications.nu first."}
    }

    let unifi_mcp_source_changed = (update-mcp-source "unifi-mcp" $unifi_mcp_repository_url)
    let unifi_mcp_needs_install = (
        $unifi_mcp_source_changed
        or not ((mcp-source-directory "unifi-mcp" | path join "node_modules") | path exists)
        or not ((mcp-source-directory "unifi-mcp" | path join "dist" "index.js") | path exists)
    )
    if $unifi_mcp_needs_install {
        install-unifi-mcp
    }

    let warehouse_mcp_source_changed = (update-mcp-source "warehouse-mcp-agent" $warehouse_mcp_repository_url)
    if ($warehouse_mcp_source_changed or not ((mcp-source-directory "warehouse-mcp-agent" | path join ".venv") | path exists)) {
        install-python-mcp "warehouse-mcp-agent" "[mcp]"
    }

    let ms_graph_mcp_source_changed = (update-mcp-source "ms-graph-mcp" $ms_graph_mcp_repository_url)
    if ($ms_graph_mcp_source_changed or not ((mcp-source-directory "ms-graph-mcp" | path join ".venv") | path exists)) {
        install-python-mcp "ms-graph-mcp" ""
    }

    let unifi_mcp_configured = (ensure-mcp-configuration "unifi-mcp" "example.env")
    let warehouse_mcp_configured = (ensure-mcp-configuration "warehouse-mcp-agent" "template.env")
    let ms_graph_mcp_configured = (ensure-mcp-configuration "ms-graph-mcp" "template.env")
    deploy-mcp-services $unifi_mcp_configured $warehouse_mcp_configured $ms_graph_mcp_configured
}
