#!/usr/bin/env nu

const repository_directory = (path self | path dirname)
const powershell_release_api = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
const powershell_editor_services_release_api = "https://api.github.com/repos/PowerShell/PowerShellEditorServices/releases/latest"
const neovim_nightly_release_api = "https://api.github.com/repos/neovim/neovim/releases/tags/nightly"
const topiary_release_api = "https://api.github.com/repos/topiary/topiary/releases/latest"
const md_viewer_release_api = "https://api.github.com/repos/aydiler/md-viewer/releases/latest"
const microsandbox_release_api = "https://api.github.com/repos/superradcompany/microsandbox/releases/latest"
const topiary_nushell_repository_url = "https://github.com/blindFS/topiary-nushell.git"
const onedrive_repository_url = "https://github.com/abraunegg/onedrive.git"
const onedrive_service_name = "onedrive-eag-erolleman.service"
const dashboard_icons_png = "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png"

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

        [($release | insert installed_version $display_version)]
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

def neovim-architecture [] {
    match (^uname -m | str trim) {
        "x86_64" => "x86_64"
        "aarch64" => "arm64"
        $architecture => (error make {msg: $"Unsupported Neovim architecture: ($architecture)"})
    }
}

def neovim-current-directory [] {
    "/opt/neovim/current"
}

def neovim-binary [] {
    "/usr/local/bin/nvim"
}

def pacman-packages-to-drop [] {
    [
        "neovim"
        "omarchy-nvim"
        "bash-language-server"
        "yaml-language-server"
    ]
}

def installed-packages-to-drop [installed_packages] {
    pacman-packages-to-drop | where {|package| $package in $installed_packages}
}

def latest-neovim-nightly-release [] {
    let release = (http get $neovim_nightly_release_api)
    let revision = $release.target_commitish
    let asset_name = $"nvim-linux-(neovim-architecture).tar.gz"
    let matching_assets = ($release.assets | where name == $asset_name)

    if ($matching_assets | is-empty) {
        error make {msg: $"Neovim nightly release asset not found: ($asset_name)"}
    }

    let asset = ($matching_assets | first)
    {
        revision: $revision
        asset_url: $asset.browser_download_url
        sha256: ($asset.digest | str replace "sha256:" "")
        archive_directory: ($asset_name | str replace ".tar.gz" "")
    }
}

def installed-neovim-revision [] {
    let current_directory = (neovim-current-directory)
    if ($current_directory | path exists) {
        ^readlink --canonicalize $current_directory | path basename
    } else {
        ""
    }
}

def pending-neovim-nightly-updates [] {
    let release = (latest-neovim-nightly-release)
    let installed_revision = (installed-neovim-revision)
    let binary_exists = (neovim-binary | path exists)

    if ((not $binary_exists) or ($installed_revision != $release.revision)) {
        let display_revision = if ($installed_revision | is-empty) {
            "not installed"
        } else {
            $installed_revision
        }

        [($release | insert installed_revision $display_revision)]
    } else {
        []
    }
}

def install-neovim-nightly [release] {
    let install_directory = $"/opt/neovim/($release.revision)"
    let current_directory = (neovim-current-directory)

    if not ($install_directory | path exists) {
        let temporary_directory = (^mktemp --directory | str trim)
        let archive_path = ($temporary_directory | path join "neovim.tar.gz")
        let extracted_directory = ($temporary_directory | path join "neovim")

        http get $release.asset_url | save --raw $archive_path

        let actual_sha256 = (open $archive_path | hash sha256)
        if $actual_sha256 != $release.sha256 {
            error make {
                msg: $"Neovim archive checksum mismatch: expected ($release.sha256), got ($actual_sha256)"
            }
        }

        mkdir $extracted_directory
        ^tar --extract --gzip --file $archive_path --directory $extracted_directory
        ^sudo install --directory --mode=0755 $install_directory
        ^sudo cp --archive $"($extracted_directory)/($release.archive_directory)/." $install_directory
        rm -r $temporary_directory
    }

    ^sudo ln --symbolic --force --no-target-directory $install_directory $current_directory
    ^sudo ln --symbolic --force --no-target-directory $"($current_directory)/bin/nvim" (neovim-binary)

    let installed_directory = (^readlink --canonicalize $current_directory | str trim)
    if $installed_directory != $install_directory {
        error make {msg: $"Neovim installation verification failed: expected ($install_directory), got ($installed_directory)"}
    }

    if not (neovim-binary | path exists) {
        error make {msg: "Neovim installation verification failed: /usr/local/bin/nvim is missing."}
    }
}

def topiary-architecture [] {
    match (^uname -m | str trim) {
        "x86_64" => "x86_64-unknown-linux-gnu"
        "aarch64" => "aarch64-unknown-linux-gnu"
        $architecture => (error make {msg: $"Unsupported Topiary architecture: ($architecture)"})
    }
}

def topiary-install-root [] {
    $env.HOME | path join ".local" "share" "topiary"
}

def topiary-current-directory [] {
    (topiary-install-root) | path join "current"
}

def topiary-binary [] {
    $env.HOME | path join ".local" "bin" "topiary"
}

def latest-topiary-release [] {
    let release = (http get $topiary_release_api)
    let version = ($release.tag_name | str replace -r "^v" "" | into semver)
    let asset_name = $"topiary-cli-(topiary-architecture).tar.xz"
    let matching_assets = ($release.assets | where name == $asset_name)

    if ($matching_assets | is-empty) {
        error make {msg: $"Topiary release asset not found: ($asset_name)"}
    }

    let asset = ($matching_assets | first)
    {
        version: $version
        asset_url: $asset.browser_download_url
        sha256: ($asset.digest | str replace "sha256:" "")
    }
}

def installed-topiary-version [] {
    let current_directory = (topiary-current-directory)
    if ($current_directory | path exists) {
        ^readlink --canonicalize $current_directory | path basename | into semver
    } else {
        "0.0.0" | into semver
    }
}

def pending-topiary-updates [] {
    let release = (latest-topiary-release)
    let is_installed = (topiary-binary | path exists)
    let installed_version = if $is_installed {
        installed-topiary-version
    } else {
        "0.0.0" | into semver
    }

    if ((not $is_installed) or ($release.version > $installed_version)) {
        let display_version = if $is_installed {
            $installed_version
        } else {
            "not installed"
        }

        [($release | insert installed_version $display_version)]
    } else {
        []
    }
}

def install-topiary [release] {
    let install_directory = ((topiary-install-root) | path join $"($release.version)")
    let current_directory = (topiary-current-directory)
    let binary = (topiary-binary)

    if not ($install_directory | path exists) {
        let temporary_directory = (^mktemp --directory | str trim)
        let archive_path = ($temporary_directory | path join "topiary.tar.xz")
        let extracted_directory = ($temporary_directory | path join "topiary")

        http get $release.asset_url | save --raw $archive_path

        let actual_sha256 = (open $archive_path | hash sha256)
        if $actual_sha256 != $release.sha256 {
            error make {
                msg: $"Topiary archive checksum mismatch: expected ($release.sha256), got ($actual_sha256)"
            }
        }

        mkdir $extracted_directory
        ^tar --extract --xz --file $archive_path --directory $extracted_directory
        mkdir $install_directory
        ^cp --archive $"($extracted_directory)/." $install_directory
        rm -r $temporary_directory
    }

    let installed_binaries = (
        glob $"($install_directory)/**/*"
        | where {|path|
            ($path | path type) == "file" and (($path | path basename) in ["topiary", "topiary-cli"])
        }
    )
    if ($installed_binaries | is-empty) {
        error make {msg: $"Topiary binary not found in ($install_directory)"}
    }

    mkdir ($binary | path dirname)
    ^ln --symbolic --force --no-target-directory $install_directory $current_directory
    ^ln --symbolic --force --no-target-directory ($installed_binaries | first) $binary

    if not ($binary | path exists) {
        error make {msg: $"Topiary installation verification failed: ($binary) is missing."}
    }
}

def md-viewer-architecture [] {
    match (^uname -m | str trim) {
        "x86_64" => "linux-x86_64"
        $architecture => (error make {msg: $"Unsupported md-viewer architecture: ($architecture)"})
    }
}

def md-viewer-install-root [] {
    $env.HOME | path join ".local" "share" "md-viewer"
}

def md-viewer-current-directory [] {
    (md-viewer-install-root) | path join "current"
}

def md-viewer-binary [] {
    $env.HOME | path join ".local" "bin" "md-viewer"
}

def md-viewer-desktop-file [] {
    $env.HOME | path join ".local" "share" "applications" "md-viewer.desktop"
}

def latest-md-viewer-release [] {
    let release = (http get $md_viewer_release_api)
    let version = ($release.tag_name | str replace -r "^v" "" | into semver)
    let asset_name = $"md-viewer-($version)-(md-viewer-architecture).tar.gz"
    let matching_assets = ($release.assets | where name == $asset_name)

    if ($matching_assets | is-empty) {
        error make {msg: $"md-viewer release asset not found: ($asset_name)"}
    }

    let asset = ($matching_assets | first)
    {
        version: $version
        asset_url: $asset.browser_download_url
        sha256: ($asset.digest | str replace "sha256:" "")
    }
}

def installed-md-viewer-version [] {
    let current_directory = (md-viewer-current-directory)
    if ($current_directory | path exists) {
        ^readlink --canonicalize $current_directory | path basename | into semver
    } else {
        "0.0.0" | into semver
    }
}

def pending-md-viewer-updates [] {
    let release = (latest-md-viewer-release)
    let is_installed = (md-viewer-binary | path exists)
    let installed_version = if $is_installed {
        installed-md-viewer-version
    } else {
        "0.0.0" | into semver
    }

    if ((not $is_installed) or ($release.version > $installed_version)) {
        let display_version = if $is_installed {
            $installed_version
        } else {
            "not installed"
        }

        [($release | insert installed_version $display_version)]
    } else {
        []
    }
}

def install-md-viewer-desktop-file [] {
    let desktop_file = (md-viewer-desktop-file)
    mkdir ($desktop_file | path dirname)
    [
        "[Desktop Entry]"
        "Name=Markdown Viewer"
        "Comment=View markdown files with live reload"
        "Exec=md-viewer %f"
        "Icon=text-markdown"
        "Terminal=false"
        "Type=Application"
        "Categories=Utility;TextEditor;Viewer;"
        "MimeType=text/markdown;text/x-markdown;"
        "StartupNotify=false"
        "StartupWMClass=md-viewer"
        ""
    ] | str join (char newline) | save --force $desktop_file
}

def install-md-viewer [release] {
    let install_directory = ((md-viewer-install-root) | path join $"($release.version)")
    let current_directory = (md-viewer-current-directory)
    let binary = (md-viewer-binary)

    if not ($install_directory | path exists) {
        let temporary_directory = (^mktemp --directory | str trim)
        let archive_path = ($temporary_directory | path join "md-viewer.tar.gz")
        let extracted_directory = ($temporary_directory | path join "md-viewer")

        http get $release.asset_url | save --raw $archive_path

        let actual_sha256 = (open $archive_path | hash sha256)
        if $actual_sha256 != $release.sha256 {
            error make {
                msg: $"md-viewer archive checksum mismatch: expected ($release.sha256), got ($actual_sha256)"
            }
        }

        mkdir $extracted_directory
        ^tar --extract --gzip --file $archive_path --directory $extracted_directory
        mkdir $install_directory
        ^cp --archive $"($extracted_directory)/." $install_directory
        rm -r $temporary_directory
    }

    let installed_binary = ($install_directory | path join "md-viewer")
    if not ($installed_binary | path exists) {
        error make {msg: $"md-viewer binary not found in ($install_directory)"}
    }

    mkdir ($binary | path dirname)
    ^ln --symbolic --force --no-target-directory $install_directory $current_directory
    ^ln --symbolic --force --no-target-directory $installed_binary $binary
    install-md-viewer-desktop-file

    if not ($binary | path exists) {
        error make {msg: $"md-viewer installation verification failed: ($binary) is missing."}
    }
}

def microsandbox-target [] {
    match (^uname -m | str trim) {
        "x86_64" => "linux-x86_64"
        "aarch64" => "linux-aarch64"
        $architecture => (error make {msg: $"Unsupported microsandbox architecture: ($architecture)"})
    }
}

def microsandbox-home [] {
    $env.HOME | path join ".microsandbox"
}

def microsandbox-binary [] {
    (microsandbox-home) | path join "bin" "msb"
}

def microsandbox-command [name] {
    $env.HOME | path join ".local" "bin" $name
}

def latest-microsandbox-release [] {
    let release = (http get $microsandbox_release_api)
    let version = ($release.tag_name | str replace -r "^v" "" | into semver)
    let asset_name = $"microsandbox-(microsandbox-target).tar.gz"
    let matching_assets = ($release.assets | where name == $asset_name)

    if ($matching_assets | is-empty) {
        error make {msg: $"Microsandbox release asset not found: ($asset_name)"}
    }

    let asset = ($matching_assets | first)
    {
        version: $version
        asset_url: $asset.browser_download_url
        sha256: ($asset.digest | str replace "sha256:" "")
    }
}

def installed-microsandbox-version [] {
    try {
        let binary = (microsandbox-binary)
        let output = (^$binary --version | str trim)
        $output | str replace -r '.*?(\d+\.\d+\.\d+).*' '${1}' | into semver
    } catch {
        "0.0.0" | into semver
    }
}

def microsandbox-library-files [] {
    let lib_directory = ((microsandbox-home) | path join "lib")
    if not ($lib_directory | path exists) {
        []
    } else {
        ls $lib_directory
        | where {|entry|
            (
                ($entry.type == "file")
                and (($entry.name | path basename) | str starts-with "libkrunfw.so.")
            )
        }
        | get name
    }
}

def microsandbox-files-ready [version] {
    if not (microsandbox-binary | path exists) {
        false
    } else {
        (
            (not (microsandbox-library-files | is-empty))
            and ((installed-microsandbox-version) >= $version)
        )
    }
}

def microsandbox-command-targets-match [] {
    let binary = (microsandbox-binary)
    let msb_link = (microsandbox-command "msb")
    let alias_link = (microsandbox-command "microsandbox")

    if (not ($binary | path exists)) or (not ($msb_link | path exists)) or (not ($alias_link | path exists)) {
        false
    } else {
        let binary_target = (^readlink --canonicalize $binary | str trim)
        let msb_target = (^readlink --canonicalize $msb_link | str trim)
        let alias_target = (^readlink --canonicalize $alias_link | str trim)
        ($msb_target == $binary_target) and ($alias_target == $binary_target)
    }
}

def pending-microsandbox-updates [] {
    let release = (latest-microsandbox-release)
    let binary_exists = (microsandbox-binary | path exists)
    let ready = if not (microsandbox-files-ready $release.version) {
        false
    } else {
        microsandbox-command-targets-match
    }

    if not $ready {
        let display_version = if $binary_exists {
            installed-microsandbox-version
        } else {
            "not installed"
        }

        [($release | insert installed_version $display_version)]
    } else {
        []
    }
}

def microsandbox-library-abi [library_name] {
    let version = ($library_name | str replace "libkrunfw.so." "")
    if ($version == $library_name) or (not ($version | str contains ".")) {
        error make {msg: $"Unexpected libkrunfw filename: ($library_name)"}
    }

    $version | split row "." | first
}

def link-microsandbox-commands [] {
    let bin_directory = ((microsandbox-home) | path join "bin")
    let binary = ($bin_directory | path join "msb")
    let bundled_alias = ($bin_directory | path join "microsandbox")

    ^ln --symbolic --force --no-target-directory "msb" $bundled_alias
    mkdir ($env.HOME | path join ".local" "bin")
    ^ln --symbolic --force --no-target-directory $binary (microsandbox-command "msb")
    ^ln --symbolic --force --no-target-directory $bundled_alias (microsandbox-command "microsandbox")
}

def install-microsandbox-files [release] {
    let temporary_directory = (^mktemp --directory | str trim)
    let archive_path = ($temporary_directory | path join "microsandbox.tar.gz")
    let extracted_directory = ($temporary_directory | path join "microsandbox")

    http get $release.asset_url | save --raw $archive_path

    let actual_sha256 = (open $archive_path | hash sha256)
    if $actual_sha256 != $release.sha256 {
        error make {
            msg: $"Microsandbox archive checksum mismatch: expected ($release.sha256), got ($actual_sha256)"
        }
    }

    mkdir $extracted_directory
    ^tar --extract --gzip --file $archive_path --directory $extracted_directory

    let extracted_binary = ($extracted_directory | path join "msb")
    if not ($extracted_binary | path exists) {
        error make {msg: "Microsandbox archive does not contain msb."}
    }

    let extracted_libraries = (
        ls $extracted_directory
        | where {|entry|
            (
                ($entry.type == "file")
                and (($entry.name | path basename) | str starts-with "libkrunfw.so.")
            )
        }
    )
    if ($extracted_libraries | length) != 1 {
        error make {msg: $"Expected one libkrunfw library in the microsandbox archive, found ($extracted_libraries | length)."}
    }

    let library_path = ($extracted_libraries | first | get name)
    let library_name = ($library_path | path basename)
    let abi = (microsandbox-library-abi $library_name)
    let home = (microsandbox-home)
    let bin_directory = ($home | path join "bin")
    let lib_directory = ($home | path join "lib")

    mkdir $bin_directory
    mkdir $lib_directory
    ^install --mode=755 $extracted_binary ($bin_directory | path join "msb")
    ^install --mode=644 $library_path ($lib_directory | path join $library_name)

    let stale_libraries = (
        ls $lib_directory
        | where {|entry|
            (
                (($entry.name | path basename) | str starts-with "libkrunfw")
                and (($entry.name | path basename) != $library_name)
            )
        }
    )
    for stale in $stale_libraries {
        rm --force $stale.name
    }

    ^ln --symbolic --force --no-target-directory $library_name ($lib_directory | path join $"libkrunfw.so.($abi)")
    ^ln --symbolic --force --no-target-directory $"libkrunfw.so.($abi)" ($lib_directory | path join "libkrunfw.so")
    rm -r $temporary_directory
}

def install-microsandbox [release] {
    if not (microsandbox-files-ready $release.version) {
        install-microsandbox-files $release
    }

    link-microsandbox-commands

    let installed_version = (installed-microsandbox-version)
    if $installed_version < $release.version {
        error make {msg: $"Microsandbox installation verification failed: expected ($release.version), got ($installed_version)"}
    }

    if not (microsandbox-command-targets-match) {
        error make {msg: "Microsandbox command link verification failed."}
    }
}

def topiary-nushell-source-directory [] {
    $env.HOME | path join ".local" "share" "topiary-nushell"
}

def update-topiary-nushell-source [] {
    update-git-source (topiary-nushell-source-directory) $topiary_nushell_repository_url "main"
}

def powershell-user-module-directory [] {
    $env.HOME | path join ".local" "share" "powershell" "Modules"
}

def installed-powershell-gallery-modules [] {
    let directory = (powershell-user-module-directory)
    if not ($directory | path exists) {
        []
    } else {
        ls $directory | get name | path basename
    }
}

def install-powershell-gallery-modules [modules] {
    let module_names = ($modules | each {|module| $"'($module)'"} | str join ", ")
    let command = (
        [
            '$ErrorActionPreference = "Stop"'
            '$ProgressPreference = "SilentlyContinue"'
            "Set-PSRepository -Name PSGallery -InstallationPolicy Trusted"
            $"Install-Module -Name ($module_names) -Repository PSGallery -Scope CurrentUser -Force -AllowClobber"
        ]
        | str join "; "
    )

    ^/usr/local/bin/pwsh --noprofile --noninteractive --command $command
}

def onedrive-source-directory [] {
    $env.HOME | path join ".local" "share" "onedrive-abraunegg"
}

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

def update-onedrive-source [] {
    update-git-source (onedrive-source-directory) $onedrive_repository_url "master"
}

def onedrive-fallback-version [source_directory] {
    let short_hash = (^git -C $source_directory rev-parse --short HEAD | str trim)
    let tags = (
        ^git -C $source_directory ls-remote --tags --refs origin
        | lines
        | parse "{sha}\trefs/tags/{tag}"
        | where {|row| $row.tag =~ '^v[0-9]'}
        | each {|row|
            try {
                $row | insert version ($row.tag | str replace -r '^v' '' | into semver)
            } catch {
                null
            }
        }
        | where {|row| $row != null}
    )

    if ($tags | is-empty) {
        $"g($short_hash)"
    } else {
        let latest = ($tags | sort-by version | last)
        let head = (^git -C $source_directory rev-parse HEAD | str trim)
        if $latest.sha == $head {
            $latest.tag
        } else {
            $"($latest.tag)-g($short_hash)"
        }
    }
}

def ensure-onedrive-git-describe [source_directory] {
    let described = (^git -C $source_directory describe --tags | complete)
    if $described.exit_code == 0 {
        return
    }

    let version = (onedrive-fallback-version $source_directory)
    ^git -C $source_directory tag --force $version
}

def build-and-install-onedrive [] {
    let source_directory = (onedrive-source-directory)
    cd $source_directory
    ensure-onedrive-git-describe $source_directory
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

def deploy-pgadmin-scripts [] {
    let destination = ($env.HOME | path join ".local" "bin" "pgadminc")
    mkdir ($destination | path dirname)
    ^install --mode=0755 ($repository_directory | path join "bin" "pgadminc") $destination
}

def deploy-mvm [] {
    let destination = ($env.HOME | path join ".local" "bin" "mvm")
    mkdir ($destination | path dirname)
    ^install --mode=0755 ($repository_directory | path join "bin" "mvm") $destination
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

def applications-directory [] {
    $env.HOME | path join ".local" "share" "applications"
}

def chromium-personal-profile-directory [] {
    $env.HOME | path join ".local" "share" "chromium-profiles" "personal"
}

def dashboard-icon [name] {
    $"($dashboard_icons_png)/($name).png"
}

def webapp-launcher-names [name] {
    [
        $name
        $"($name) WebApp"
    ]
}

def installed-webapp-launcher-names [name] {
    let applications = (applications-directory)

    webapp-launcher-names $name
    | where {|launcher| ($applications | path join $"($launcher).desktop") | path exists}
}

def webapp-is-installed [name] {
    not (installed-webapp-launcher-names $name | is-empty)
}

def webapp-remove-plan [] {
    ["Discord"]
}

def webapp-install-plan [] {
    let personal_profile = (chromium-personal-profile-directory)

    [
        {
            name: "Copilot (Work)"
            url: "https://m365.cloud.microsoft/chat"
            icon: (dashboard-icon "microsoft-copilot")
            exec: ""
        }
        {
            name: "OneDrive (Work)"
            url: "https://www.office.com/launch/onedrive"
            icon: (dashboard-icon "microsoft-onedrive")
            exec: ""
        }
        {
            name: "Outlook"
            url: "https://outlook.office.com/mail/"
            icon: (dashboard-icon "microsoft-outlook")
            exec: ""
        }
        {
            name: "Outlook (Personal)"
            url: "https://outlook.office.com/mail/"
            icon: (dashboard-icon "microsoft-outlook")
            exec: $"omarchy-launch-webapp https://outlook.office.com/mail/ --user-data-dir=($personal_profile)"
        }
        {
            name: "To Do (Work)"
            url: "https://to-do.office.com/tasks/"
            icon: (dashboard-icon "microsoft-to-do")
            exec: ""
        }
        {
            name: "YouTube"
            url: "https://youtube.com/"
            icon: "youtube"
            exec: $"omarchy-launch-webapp https://youtube.com/ --user-data-dir=($personal_profile)"
        }
        {
            name: "YouTube Music"
            url: "https://music.youtube.com/"
            icon: (dashboard-icon "youtube-music")
            exec: $"omarchy-launch-webapp https://music.youtube.com/ --user-data-dir=($personal_profile)"
        }
        {
            name: "Twitch"
            url: "https://twitch.tv/"
            icon: (dashboard-icon "twitch")
            exec: $"omarchy-launch-webapp https://twitch.tv/ --user-data-dir=($personal_profile)"
        }
    ]
}

def install-webapp [webapp] {
    if ($webapp.exec | is-empty) {
        ^omarchy webapp install $webapp.name $webapp.url $webapp.icon
    } else {
        ^omarchy webapp install $webapp.name $webapp.url $webapp.icon $webapp.exec
    }
}

def install-webapps [webapps] {
    if ($webapps | any {|webapp| $webapp.exec | is-not-empty}) {
        mkdir (chromium-personal-profile-directory)
    }

    for webapp in $webapps {
        install-webapp $webapp
    }
}

def main [--yes] {
    let install_plan = [
        { package: "ansible-lint", source: "pkg" }
        { package: "ansible-language-server", source: "AUR" }
        { package: "curl", source: "pkg" }
        { package: "dbus", source: "pkg" }
        { package: "discord", source: "pkg" }
        { package: "git", source: "pkg" }
        { package: "gtk3", source: "pkg" }
        { package: "herdr", source: "pkg" }
        { package: "jdk-openjdk", source: "pkg" }
        { package: "jq", source: "pkg" }
        { package: "ldc", source: "pkg" }
        { package: "libnotify", source: "pkg" }
        { package: "lua-language-server", source: "pkg" }
        { package: "make", source: "pkg" }
        { package: "marksman", source: "pkg" }
        { package: "mdformat", source: "pkg" }
        { package: "mdformat-tables", source: "pkg" }
        { package: "nodejs", source: "pkg" }
        { package: "npm", source: "pkg" }
        { package: "odin", source: "pkg" }
        { package: "odinfmt", source: "pkg" }
        { package: "ols", source: "pkg" }
        { package: "pkgconf", source: "pkg" }
        { package: "pyright", source: "pkg" }
        { package: "python", source: "pkg" }
        { package: "rust", source: "pkg" }
        { package: "rust-analyzer", source: "pkg" }
        { package: "rust-src", source: "pkg" }
        { package: "shellcheck", source: "pkg" }
        { package: "sqlite", source: "pkg" }
        { package: "tree-sitter-cli", source: "pkg" }
        { package: "yamlfmt", source: "pkg" }
        { package: "yamllint", source: "pkg" }
        { package: "Microsoft.Graph", source: "PSGallery" }
        { package: "Microsoft.Entra", source: "PSGallery" }
        { package: "Microsoft.Graph.Intune", source: "PSGallery" }
    ]

    let installed_pacman_packages = (^pacman -Qq | lines)
    let installed_flatpak_packages = if (which flatpak | is-empty) {
        []
    } else {
        ^flatpak list --app --columns=application | lines
    }
    let installed_powershell_modules = (installed-powershell-gallery-modules)
    let powershell_updates = (pending-powershell-updates)
    let powershell_editor_services_updates = (pending-powershell-editor-services-updates)
    let neovim_nightly_updates = (pending-neovim-nightly-updates)
    let topiary_updates = (pending-topiary-updates)
    let md_viewer_updates = (pending-md-viewer-updates)
    let microsandbox_updates = (pending-microsandbox-updates)
    let packages_to_drop = (installed-packages-to-drop $installed_pacman_packages)
    let missing_webapps = (
        webapp-install-plan
        | where {|webapp| not (webapp-is-installed $webapp.name)}
    )
    let webapps_to_remove = (
        webapp-remove-plan
        | each {|name| installed-webapp-launcher-names $name}
        | flatten
    )

    let missing_packages = (
        $install_plan
        | where {|item|
            match $item.source {
                "pkg" | "AUR" => (($item.package) not-in $installed_pacman_packages)
                "Flatpak" => (($item.package) not-in $installed_flatpak_packages)
                "PSGallery" => (($item.package) not-in $installed_powershell_modules)
                _ => (error make {msg: $"Unsupported package source: ($item.source)"})
            }
        }
    )

    if not ($missing_packages | is-empty) {
        print "The following software will be installed:"
        $missing_packages | print-table
    }

    if not ($missing_webapps | is-empty) {
        print "The following web apps will be installed:"
        $missing_webapps | select name url | print-table
    }

    if not ($webapps_to_remove | is-empty) {
        print "The following web apps will be removed:"
        $webapps_to_remove | wrap name | print-table
    }

    if not ($powershell_updates | is-empty) {
        let powershell_update = ($powershell_updates | first)
        print $"PowerShell will be updated from ($powershell_update.installed_version) to ($powershell_update.version)."
    }

    if not ($powershell_editor_services_updates | is-empty) {
        let powershell_editor_services_update = ($powershell_editor_services_updates | first)
        print $"PowerShell Editor Services will be installed at version ($powershell_editor_services_update.version)."
    }

    if not ($packages_to_drop | is-empty) {
        print "The following pacman packages will be removed:"
        $packages_to_drop | wrap package | print-table
    }

    if not ($neovim_nightly_updates | is-empty) {
        let neovim_update = ($neovim_nightly_updates | first)
        print $"Neovim nightly will be installed from ($neovim_update.installed_revision) to ($neovim_update.revision)."
    }

    if not ($topiary_updates | is-empty) {
        let topiary_update = ($topiary_updates | first)
        print $"Topiary will be installed from ($topiary_update.installed_version) to ($topiary_update.version)."
    }

    if not ($md_viewer_updates | is-empty) {
        let md_viewer_update = ($md_viewer_updates | first)
        print $"md-viewer will be installed from ($md_viewer_update.installed_version) to ($md_viewer_update.version)."
    }

    if not ($microsandbox_updates | is-empty) {
        let microsandbox_update = ($microsandbox_updates | first)
        print $"Microsandbox will be installed from ($microsandbox_update.installed_version) to ($microsandbox_update.version)."
    }

    print "The pgAdmin command will be installed."
    print "The mvm command will be installed."
    print "The OneDrive client will be checked for updates."
    print "The topiary-nushell queries will be checked for updates."

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

    if not ($neovim_nightly_updates | is-empty) {
        install-neovim-nightly ($neovim_nightly_updates | first)
    }

    if not ($topiary_updates | is-empty) {
        install-topiary ($topiary_updates | first)
    }

    if not ($md_viewer_updates | is-empty) {
        install-md-viewer ($md_viewer_updates | first)
    }

    if not ($microsandbox_updates | is-empty) {
        install-microsandbox ($microsandbox_updates | first)
    }

    if not ($packages_to_drop | is-empty) {
        ^omarchy pkg drop ...$packages_to_drop
    }

    let powershell_gallery_modules = ($missing_packages | where source == "PSGallery" | get package)
    if not ($powershell_gallery_modules | is-empty) {
        install-powershell-gallery-modules $powershell_gallery_modules
    }

    if not ($missing_webapps | is-empty) {
        install-webapps $missing_webapps
    }

    for webapp_name in $webapps_to_remove {
        with-env {OMARCHY_REMOVE_NOTIFY: "false"} {
            ^omarchy webapp remove $webapp_name
        }
    }

    deploy-pgadmin-scripts
    deploy-mvm

    let onedrive_source_changed = (update-onedrive-source)
    if ($onedrive_source_changed or not ("/usr/local/bin/onedrive" | path exists)) {
        build-and-install-onedrive
    }

    deploy-onedrive-wrapper
    deploy-onedrive-plugin
    deploy-onedrive-service
    deploy-initdev
    update-topiary-nushell-source | ignore
}
