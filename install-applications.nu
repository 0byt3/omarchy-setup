#!/usr/bin/env nu

const repository_directory = (path self | path dirname)
const powershell_release_api = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
const powershell_editor_services_release_api = "https://api.github.com/repos/PowerShell/PowerShellEditorServices/releases/latest"
const onedrive_repository_url = "https://github.com/abraunegg/onedrive.git"
const onedrive_service_name = "onedrive-eag-erolleman.service"
const unifi_mcp_repository_url = "https://github.com/emilandersongroup/unifi-mcp.git"
const warehouse_mcp_repository_url = "https://github.com/emilandersongroup/warehouse-mcp-agent.git"
const ms_graph_mcp_repository_url = "https://github.com/emilandersongroup/ms-graph-mcp.git"

def print-table [] {
    $in | to csv | ^gum table --print
}

def powershell-architecture [] {
    match (^uname -m | str trim) {
        "x86_64" => "x64"
        "aarch64" => "arm64"
        $architecture => (error make {msg: $"Unsupported PowerShell architecture: ($architecture)"})
    }
}

def installed-powershell-version [] {
    (^/usr/local/bin/pwsh --version
        | str trim
        | str replace "PowerShell " ""
        | into semver)
}

def latest-powershell-release [] {
    let release = (http get $powershell_release_api)
    let version = ($release.tag_name | str replace -r "^v" "" | into semver)
    let asset_name = $"powershell-($version)-linux-(powershell-architecture).tar.gz"
    let matching_assets = ($release.assets | where name == $asset_name)

    if ($matching_assets | is-empty) {
        error make {msg: $"PowerShell release asset not found: ($asset_name)"}
    }

    let asset = ($matching_assets | first)
    {
        version: $version
        asset_url: $asset.browser_download_url
        sha256: ($asset.digest | str replace "sha256:" "")
    }
}

def pending-powershell-updates [] {
    let is_installed = ("/usr/local/bin/pwsh" | path exists)
    let installed_version = if $is_installed {
        installed-powershell-version
    } else {
        "0.0.0" | into semver
    }
    let release = (latest-powershell-release)

    if ((not $is_installed) or ($release.version > $installed_version)) {
        let display_version = if $is_installed {
            $installed_version
        } else {
            "not installed"
        }

        [$release | insert installed_version $display_version]
    } else {
        []
    }
}

def install-powershell [release] {
    let temporary_directory = (^mktemp --directory | str trim)
    let archive_path = ($temporary_directory | path join "powershell.tar.gz")
    let extracted_directory = ($temporary_directory | path join "powershell")
    let install_directory = ($"/opt/powershell/($release.version)")

    http get $release.asset_url | save --raw $archive_path

    let actual_sha256 = (open $archive_path | hash sha256)
    if $actual_sha256 != $release.sha256 {
        error make {
            msg: $"PowerShell archive checksum mismatch: expected ($release.sha256), got ($actual_sha256)"
        }
    }

    mkdir $extracted_directory
    ^tar --extract --gzip --file $archive_path --directory $extracted_directory

    if not ($install_directory | path exists) {
        ^sudo install --directory --mode=0755 $install_directory
        ^sudo cp --archive $"($extracted_directory)/." $install_directory
    }

    ^sudo ln --symbolic --force $"($install_directory)/pwsh" "/usr/local/bin/pwsh"
    rm -r $temporary_directory

    let installed_version = (installed-powershell-version)
    if $installed_version != $release.version {
        error make {msg: $"PowerShell installation verification failed: expected ($release.version), got ($installed_version)"}
    }
}

def latest-powershell-editor-services-release [] {
    let release = (http get $powershell_editor_services_release_api)
    let version = ($release.tag_name | str replace -r "^v" "" | into semver)
    let matching_assets = ($release.assets | where name == "PowerShellEditorServices.zip")

    if ($matching_assets | is-empty) {
        error make {msg: "PowerShell Editor Services release asset not found."}
    }

    let asset = ($matching_assets | first)
    {
        version: $version
        asset_url: $asset.browser_download_url
        sha256: ($asset.digest | str replace "sha256:" "")
    }
}

def pending-powershell-editor-services-updates [] {
    let release = (latest-powershell-editor-services-release)
    let current_directory = "/opt/powershell-editor-services/current"
    let expected_directory = $"/opt/powershell-editor-services/($release.version)"
    let installed_directory = if ($current_directory | path exists) {
        (^readlink --canonicalize $current_directory | str trim)
    } else {
        ""
    }

    if $installed_directory != $expected_directory {
        [$release]
    } else {
        []
    }
}

def install-powershell-editor-services [release] {
    let install_directory = $"/opt/powershell-editor-services/($release.version)"
    let current_directory = "/opt/powershell-editor-services/current"

    if not ($install_directory | path exists) {
        let temporary_directory = (^mktemp --directory | str trim)
        let archive_path = ($temporary_directory | path join "PowerShellEditorServices.zip")
        let extracted_directory = ($temporary_directory | path join "PowerShellEditorServices")

        http get $release.asset_url | save --raw $archive_path

        let actual_sha256 = (open $archive_path | hash sha256)
        if $actual_sha256 != $release.sha256 {
            error make {
                msg: $"PowerShell Editor Services archive checksum mismatch: expected ($release.sha256), got ($actual_sha256)"
            }
        }

        mkdir $extracted_directory
        ^unzip -q $archive_path -d $extracted_directory
        ^sudo install --directory --mode=0755 $install_directory
        ^sudo cp --archive $"($extracted_directory)/." $install_directory
        rm -r $temporary_directory
    }

    ^sudo ln --symbolic --force $install_directory $current_directory

    let installed_directory = (^readlink --canonicalize $current_directory | str trim)
    if $installed_directory != $install_directory {
        error make {msg: $"PowerShell Editor Services installation verification failed: expected ($install_directory), got ($installed_directory)"}
    }
}

def onedrive-source-directory [] {
    $env.HOME | path join ".local" "share" "onedrive-abraunegg"
}

def update-onedrive-source [] {
    let source_directory = (onedrive-source-directory)

    if not ($source_directory | path exists) {
        mkdir ($source_directory | path dirname)
        ^git clone --depth 1 --branch master $onedrive_repository_url $source_directory
        return true
    }

    let current_revision = (^git -C $source_directory rev-parse HEAD | str trim)
    ^git -C $source_directory fetch --depth 1 origin master
    let upstream_revision = (^git -C $source_directory rev-parse origin/master | str trim)

    if $current_revision == $upstream_revision {
        false
    } else {
        ^git -C $source_directory pull --ff-only --depth 1 origin master
        true
    }
}

def build-and-install-onedrive [] {
    let source_directory = (onedrive-source-directory)
    cd $source_directory
    ^./configure
    ^make
    ^sudo install --mode=0755 ($source_directory | path join "onedrive") "/usr/local/bin/onedrive"
}

def deploy-onedrive-wrapper [] {
    let wrapper_source = ($repository_directory | path join "onedrive" "onedrive-eag-erolleman-wrapper")
    let wrapper_destination = ($env.HOME | path join ".local" "bin" "onedrive-eag-erolleman-wrapper")

    mkdir ($wrapper_destination | path dirname)
    ^install --mode=0755 $wrapper_source $wrapper_destination
}

def deploy-initdev [] {
    let script_source = ($repository_directory | path join "bin" "initdev")
    let script_destination = ($env.HOME | path join ".local" "bin" "initdev")
    let configuration_source = ($repository_directory | path join "initdev")
    let configuration_destination = ($env.HOME | path join ".config" "initdev")

    mkdir ($script_destination | path dirname)
    ^install --mode=0755 $script_source $script_destination
    mkdir $configuration_destination
    ^cp --archive $"($configuration_source)/." $configuration_destination
}

def deploy-onedrive-plugin [] {
    let plugin_source = ($repository_directory | path join "omarchy" "plugins" "eag-erolleman.onedrive")
    let plugin_destination = ($env.HOME | path join ".config" "omarchy" "plugins" "eag-erolleman.onedrive")

    mkdir ($plugin_destination | path dirname)
    ^cp --archive --no-target-directory $plugin_source $plugin_destination
}

def deploy-onedrive-service [] {
    let service_directory = ($env.HOME | path join ".config" "systemd" "user")
    let service_path = ($service_directory | path join $onedrive_service_name)
    let configuration_directory = ($env.HOME | path join ".config" "onedrive" "eag-erolleman")
    let wrapper_config = ($configuration_directory | path join "monitor-wrapper.toml")
    let service_existed = ($service_path | path exists)
    let service_was_active = if $service_existed {
        let status = (^systemctl --user is-active --quiet $onedrive_service_name | complete)
        $status.exit_code == 0
    } else {
        false
    }
    let wrapper_config_contents = (
        [
            "[onedrive]"
            "# Copy this file for each OneDrive account, then point that account's wrapper"
            "# service at its copy. The wrapper always adds --monitor and this --confdir."
            "config_dir = \"~/.config/onedrive/eag-erolleman\""
            "binary = \"/usr/local/bin/onedrive\""
            "extra_args = []"
        ]
        | str join (char newline)
    )
    let service_contents = (
        [
            "[Unit]"
            "Description=OneDrive client for eag-erolleman"
            "After=network-online.target"
            "Wants=network-online.target"
            ""
            "[Service]"
            "Type=simple"
            "RuntimeDirectory=onedrive-eag-erolleman"
            "RuntimeDirectoryMode=0700"
            "KillMode=mixed"
            "ExecStart=%h/.local/bin/onedrive-eag-erolleman-wrapper --events-file %t/onedrive-eag-erolleman/events.jsonl --config %h/.config/onedrive/eag-erolleman/monitor-wrapper.toml"
            "Restart=on-failure"
            "RestartSec=5"
            ""
            "[Install]"
            "WantedBy=default.target"
        ]
        | str join (char newline)
    )

    mkdir $configuration_directory
    ($wrapper_config_contents + (char newline)) | save --force $wrapper_config
    mkdir $service_directory
    ($service_contents + (char newline)) | save --force $service_path
    ^systemctl --user daemon-reload

    if $service_was_active {
        ^systemctl --user restart $onedrive_service_name
    } else if not $service_existed {
        ^systemctl --user enable $onedrive_service_name
        print "Authenticate OneDrive before starting the service:"
        print "  /usr/local/bin/onedrive --confdir ~/.config/onedrive/eag-erolleman"
        print $"Then start it with: systemctl --user start ($onedrive_service_name)"
    }
}

def mcp-source-directory [server_name] {
    $env.HOME | path join ".local" "mcp" $server_name
}

def update-mcp-source [server_name repository_url] {
    let source_directory = (mcp-source-directory $server_name)

    if not ($source_directory | path exists) {
        mkdir ($source_directory | path dirname)
        ^git clone --depth 1 --branch main $repository_url $source_directory
        return true
    }

    let current_revision = (^git -C $source_directory rev-parse HEAD | str trim)
    ^git -C $source_directory fetch --depth 1 origin main
    let upstream_revision = (^git -C $source_directory rev-parse origin/main | str trim)

    if $current_revision == $upstream_revision {
        false
    } else {
        ^git -C $source_directory pull --ff-only --depth 1 origin main
        true
    }
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

def main [--yes] {
    let install_plan = [
        { package: "ansible-lint", source: "pkg" }
        { package: "ansible-language-server", source: "AUR" }
        { package: "curl", source: "pkg" }
        { package: "dbus", source: "pkg" }
        { package: "git", source: "pkg" }
        { package: "herdr", source: "pkg" }
        { package: "jdk-openjdk", source: "pkg" }
        { package: "ldc", source: "pkg" }
        { package: "libnotify", source: "pkg" }
        { package: "make", source: "pkg" }
        { package: "nodejs", source: "pkg" }
        { package: "npm", source: "pkg" }
        { package: "pkgconf", source: "pkg" }
        { package: "python", source: "pkg" }
        { package: "sqlite", source: "pkg" }
    ]

    let installed_pacman_packages = (^pacman -Qq | lines)
    let installed_flatpak_packages = (^flatpak list --app --columns=application | lines)
    let powershell_updates = (pending-powershell-updates)
    let powershell_editor_services_updates = (pending-powershell-editor-services-updates)

    let missing_packages = (
        $install_plan
        | where {|item|
            match $item.source {
                "pkg" | "AUR" => (($item.package) not-in $installed_pacman_packages)
                "Flatpak" => (($item.package) not-in $installed_flatpak_packages)
                _ => (error make {msg: $"Unsupported package source: ($item.source)"})
            }
        }
    )

    if not ($missing_packages | is-empty) {
        print "The following software will be installed:"
        $missing_packages | print-table
    }

    if not ($powershell_updates | is-empty) {
        let powershell_update = ($powershell_updates | first)
        print $"PowerShell will be updated from ($powershell_update.installed_version) to ($powershell_update.version)."
    }

    if not ($powershell_editor_services_updates | is-empty) {
        let powershell_editor_services_update = ($powershell_editor_services_updates | first)
        print $"PowerShell Editor Services will be installed at version ($powershell_editor_services_update.version)."
    }

    print "The OneDrive client will be checked for updates."
    print "The MCP servers will be checked for updates."

    if not $yes {
        let response = (input "Continue with installation? [y/N] " | str trim | str lowercase)

        if (($response != "y") and ($response != "yes")) {
            print "Installation cancelled."
            return
        }
    }

    let pkg_packages = ($missing_packages | where source == "pkg" | get package)
    if not ($pkg_packages | is-empty) {
        ^omarchy pkg add ...$pkg_packages
    }

    let aur_packages = ($missing_packages | where source == "AUR" | get package)
    if not ($aur_packages | is-empty) {
        ^omarchy pkg aur add ...$aur_packages
    }

    let flatpak_packages = ($missing_packages | where source == "Flatpak" | get package)
    if not ($flatpak_packages | is-empty) {
        ^flatpak install --assumeyes --noninteractive flathub ...$flatpak_packages
    }

    if not ($powershell_updates | is-empty) {
        install-powershell ($powershell_updates | first)
    }

    if not ($powershell_editor_services_updates | is-empty) {
        install-powershell-editor-services ($powershell_editor_services_updates | first)
    }

    let onedrive_source_changed = (update-onedrive-source)
    if ($onedrive_source_changed or not ("/usr/local/bin/onedrive" | path exists)) {
        build-and-install-onedrive
    }

    deploy-onedrive-wrapper
    deploy-onedrive-plugin
    deploy-onedrive-service
    deploy-initdev

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
