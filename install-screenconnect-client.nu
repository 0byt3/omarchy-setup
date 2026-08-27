#!/usr/bin/env nu

# Install the ScreenConnect Host client from a vendor ScreenConnect.ClientSetup.sh
# by extracting the embedded tar.gz bundle. Does not unpack the .deb or .rpm Access agent.
# Does not launch the client after install. Uninstall with the vendor ClientUninstaller.sh
# in the install directory.

const MARKER_SUFFIX_COMMENCEMENT = "__commencement"
const MARKER_SUFFIX_COMPLETION = "__completion"
const GZIP_MAGIC_BYTES = 0x[1F 8B]
const DEFAULT_CLIENT_INSTALLER = "ClientInstaller.sh"
const VENDOR_LAUNCH_LINE = 'sh "$clientInstallationDirectory/$clientLauncherShellScriptFileName"'

def command-on-path [name: string] {
    not (which $name | is-empty)
}

def require-command [name: string, message: string] {
    if not (command-on-path $name) {
        error make {msg: $message}
    }
}

def warn-if-missing [name: string] {
    if not (command-on-path $name) {
        print --stderr $"warning: ($name) not found; the vendor installer may fail when registering the desktop entry"
    }
}

def remove-if-present [path: any] {
    if $path == null or $path == "" or not ($path | path exists) {
        return
    }

    if ($path | path type) == "dir" {
        rm --recursive --force $path
    } else {
        rm --force $path
    }
}

def parse-shell-assignment [text: string, variable: string] {
    let pattern = $"($variable)='"
    if not ($text | str contains $pattern) {
        return null
    }

    $text | split row $pattern | last | split row "'" | get 0?
}

def marker-offset [setup_bytes: binary, marker: string] {
    $setup_bytes | bytes index-of ($marker | into binary)
}

def require-marker-offset [setup_bytes: binary, marker: string, message: string] {
    let offset = (marker-offset $setup_bytes $marker)
    if $offset < 0 {
        error make {msg: $message}
    }
    $offset
}

def extract-embedded-payload [setup_bytes: binary, package_type: string] {
    let start_marker = $"($package_type)($MARKER_SUFFIX_COMMENCEMENT)"
    let end_marker = $"($package_type)($MARKER_SUFFIX_COMPLETION)"
    let missing_message = "Setup file is not a Host-capable ScreenConnect installer (or the file is truncated)."

    let start_offset = (require-marker-offset $setup_bytes $start_marker $missing_message)
    let end_offset = (require-marker-offset $setup_bytes $end_marker $missing_message)
    let payload_start = ($start_offset + ($start_marker | str length) + 1)
    let raw_payload = ($setup_bytes | bytes at $payload_start..<$end_offset)

    if ($raw_payload | bytes ends-with 0x[0A]) {
        $raw_payload | bytes at ..<-1
    } else {
        $raw_payload
    }
}

def parse-host-metadata [setup_bytes: binary] {
    let app_start = (marker-offset $setup_bytes $"app($MARKER_SUFFIX_COMMENCEMENT)")
    let tar_start = (marker-offset $setup_bytes $"tar.gz($MARKER_SUFFIX_COMMENCEMENT)")

    if $app_start < 0 or $tar_start < 0 {
        return {
            package_name: null
            client_installer: $DEFAULT_CLIENT_INSTALLER
        }
    }

    let app_marker = $"app($MARKER_SUFFIX_COMMENCEMENT)"
    let payload_start = ($app_start + ($app_marker | str length) + 1)
    let app_text = ($setup_bytes | bytes at $payload_start..<$tar_start | decode iso-8859-1)
    let entry_block = if ($app_text | str contains "### Base Script End ###") {
        $app_text | split row "### Base Script End ###" | last
    } else {
        $app_text
    }

    {
        package_name: (parse-shell-assignment $entry_block "packageName")
        client_installer: (
            parse-shell-assignment $entry_block "clientInstallerShellScriptFileName"
            | default $DEFAULT_CLIENT_INSTALLER
        )
    }
}

def package-name-from-archive [archive_path: string] {
    let listed = (^tar --list --gzip --file $archive_path | complete)
    if $listed.exit_code != 0 {
        error make {msg: $"Failed to list the Host archive: ($listed.stderr | str trim)"}
    }

    let names = (
        $listed.stdout
        | lines
        | compact
        | each {|member| $member | path split | get 0?}
        | compact
        | uniq
    )

    if ($names | is-empty) {
        error make {msg: "Could not determine the Host package name from the archive."}
    }

    $names | first
}

def resolve-package-name [parsed_name: any, archive_path: string] {
    let archive_name = (package-name-from-archive $archive_path)
    if $parsed_name == null {
        $archive_name
    } else if $parsed_name == $archive_name {
        $parsed_name
    } else {
        error make {msg: $"Package name mismatch: installer metadata has ($parsed_name), archive has ($archive_name)"}
    }
}

def write-installer-without-launch [installer_path: string] {
    let original = (open --raw $installer_path | decode utf-8)
    if not ($original | str contains $VENDOR_LAUNCH_LINE) {
        print --stderr "warning: could not find the vendor launch line; the client may still start"
        return null
    }

    let modified_path = (mktemp --tmpdir)
    (
        $original
        | str replace $VENDOR_LAUNCH_LINE ': # skipped: this installer does not launch the client'
        | save --force $modified_path
    )
    $modified_path
}

def run-vendor-installer [installer_path: string] {
    let result = (^sh $installer_path | complete)

    if not ($result.stdout | is-empty) {
        print ($result.stdout | str trim)
    }
    if not ($result.stderr | is-empty) {
        print --stderr ($result.stderr | str trim)
    }

    $result.exit_code
}

def unpack-and-install [
    archive_path: string
    package_name: string
    client_installer: string
] {
    let package_dir = ("/tmp" | path join $package_name)
    let installer_path = ($package_dir | path join $client_installer)
    let client_dir = ($env.HOME | path join ".local" "share" "applications" $package_name)

    remove-if-present $package_dir

    let extract_result = (
        ^tar --extract --gzip --file $archive_path --directory /tmp
        | complete
    )
    if $extract_result.exit_code != 0 {
        remove-if-present $package_dir
        error make {msg: $"Failed to unpack the Host archive: ($extract_result.stderr | str trim)"}
    }

    if not ($installer_path | path exists) {
        remove-if-present $package_dir
        error make {msg: $"Client installer not found: ($installer_path)"}
    }

    let skip_launch_script = (write-installer-without-launch $installer_path)
    let installer_to_run = ($skip_launch_script | default $installer_path)

    let exit_code = (try {
        run-vendor-installer $installer_to_run
    } catch {|err|
        remove-if-present $skip_launch_script
        remove-if-present $package_dir
        error make {msg: $err.msg}
    })

    remove-if-present $skip_launch_script
    remove-if-present $package_dir

    {
        exit_code: $exit_code
        client_dir: $client_dir
    }
}

def install-host-client [setup_bytes: binary] {
    let metadata = (parse-host-metadata $setup_bytes)
    let payload = (extract-embedded-payload $setup_bytes "tar.gz")

    if not ($payload | bytes starts-with $GZIP_MAGIC_BYTES) {
        error make {msg: "Extracted tar.gz payload is corrupt (missing gzip magic bytes)."}
    }

    let archive_path = (mktemp --tmpdir --suffix .tar.gz)
    let outcome = (try {
        $payload | save --raw --force $archive_path
        let package_name = (resolve-package-name $metadata.package_name $archive_path)
        unpack-and-install $archive_path $package_name $metadata.client_installer
    } catch {|err|
        {failed: true, msg: $err.msg}
    })

    remove-if-present $archive_path

    if "failed" in ($outcome | columns) {
        error make {msg: $outcome.msg}
    }

    $outcome
}

def main [
    setup_file?: string  # path to ScreenConnect.ClientSetup.sh
] {
    require-command "java" "Java is required to install the ScreenConnect Host client. Add a working java executable to PATH."
    require-command "tar" "tar is required to unpack the ScreenConnect Host bundle."
    warn-if-missing "update-desktop-database"
    warn-if-missing "xdg-mime"

    let setup_path = (
        $setup_file
        | default ($env.HOME | path join "Downloads" "ScreenConnect.ClientSetup.sh")
        | path expand
    )

    if not ($setup_path | path exists) {
        error make {msg: $"Setup file not found: ($setup_path)"}
    }

    let setup_bytes = (open --raw $setup_path | into binary)
    let result = (install-host-client $setup_bytes)

    if $result.exit_code != 0 {
        print --stderr $"ScreenConnect ClientInstaller.sh failed with exit code ($result.exit_code)"
        exit $result.exit_code
    }

    print $"Installed ScreenConnect Host client to ($result.client_dir)"
    print $"Uninstall with: sh ($result.client_dir | path join 'ClientUninstaller.sh')"
}
