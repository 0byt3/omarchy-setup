#!/usr/bin/env nu

const repository_directory = (path self | path dirname)

def print-table [] {
    $in | to csv | ^gum table --print
}

def display-source [source] {
    try {
        $source | path relative-to $repository_directory
    } catch {
        display-destination $source
    }
}

def deploy-herdr-skill [] {
    if (which herdr | is-empty) {
        print "Skipped herdr skill deployment because herdr is not installed."
        return null
    }

    let destination = ($env.HOME | path join ".cursor" "skills" "herdr" "SKILL.md")
    mkdir ($destination | path dirname)
    let skill = (^herdr --skill | str trim --right)
    $"($skill)(char newline)(char newline)The default shell of herdr is bash.(char newline)" | save --force $destination

    {
        source: "herdr --skill"
        destination: $destination
    }
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

def neovim-plugin-source-directory [plugin_name] {
    $env.HOME | path join ".local" "share" "nvim" "plugins" $plugin_name
}

def neovim-plugin-destination-directory [plugin_name] {
    $env.HOME | path join ".config" "nvim" "pack" "external" "start" $plugin_name
}

def neovim-plugins [] {
    open ($repository_directory | path join "neovim" "plugins.nuon")
}

def replace-directory [source destination] {
    if ($destination | path exists) {
        rm -r $destination
    }

    mkdir ($destination | path dirname)
    ^cp --archive --no-target-directory $source $destination
}

def deploy-neovim-plugin [plugin --no-git] {
    let source_directory = (neovim-plugin-source-directory $plugin.name)
    let destination_directory = (neovim-plugin-destination-directory $plugin.name)
    let branch = ($plugin.branch? | default "main")
    let source_changed = if $no_git {
        false
    } else {
        update-git-source $source_directory $plugin.repository $branch
    }

    if not ($source_directory | path exists) {
        print $"Skipped ($plugin.name) plugin deployment because the source checkout is missing."
        return null
    }

    if ($source_changed or not ($destination_directory | path exists)) {
        replace-directory $source_directory $destination_directory
    }

    {
        source: $source_directory
        destination: $destination_directory
    }
}

def deploy-neovim-plugins [--no-git] {
    neovim-plugins
    | each {|plugin| deploy-neovim-plugin $plugin --no-git=$no_git }
    | compact
}

def display-destination [destination] {
    let relative_destination = (
        try {
            $destination | path relative-to $env.HOME
        } catch {
            null
        }
    )

    if $relative_destination == null {
        $destination
    } else if $relative_destination == "" {
        "~"
    } else {
        $"~/($relative_destination)"
    }
}

def tree-sitter-nu-revision [languages_source] {
    let matches = (open --raw $languages_source | parse --regex 'rev = "(?P<rev>[0-9a-f]{7,})"')
    if ($matches | is-empty) {
        error make {msg: $"Could not read tree-sitter-nu revision from ($languages_source)"}
    }

    $matches | first | get rev
}

def topiary-languages [nu_revision] {
    [
        "{"
        "  languages = {"
        "    nu = {"
        "      extensions = [\"nu\"],"
        "      indent = \"    \","
        "      grammar.source.git = {"
        "        git = \"https://github.com/nushell/tree-sitter-nu.git\","
        $"        rev = \"($nu_revision)\","
        "      },"
        "    },"
        "    bash = { indent | force = \"    \" },"
        "    json = { indent | force = \"    \" },"
        "    toml = { indent | force = \"    \" },"
        "  },"
        "}"
        ""
    ]
    | str join (char newline)
}

def deploy-topiary-nushell [] {
    let source_directory = ($env.HOME | path join ".local" "share" "topiary-nushell")
    let destination_directory = ($env.HOME | path join ".config" "topiary")
    let query_source = ($source_directory | path join "queries" "nu.scm")
    let languages_source = ($source_directory | path join "languages.ncl")

    if not (($query_source | path exists) and ($languages_source | path exists)) {
        print "Skipped topiary-nushell deployment because the source checkout is missing."
        return null
    }

    mkdir ($destination_directory | path join "queries")
    topiary-languages (tree-sitter-nu-revision $languages_source)
    | save --force ($destination_directory | path join "languages.ncl")
    ^cp --archive $query_source ($destination_directory | path join "queries" "nu.scm")

    {
        source: $source_directory
        destination: $destination_directory
    }
}

def append-bashrc-source [bashrc comment source_line] {
    let bashrc_text = (open --raw $bashrc)
    if not ($bashrc_text | str contains $source_line) {
        let prefix = if ($bashrc_text | str ends-with (char newline)) {
            $bashrc_text
        } else {
            $"($bashrc_text)(char newline)"
        }
        $"($prefix)(char newline)# ($comment)(char newline)($source_line)(char newline)" | save --force $bashrc
    }
}

def deploy-bash-prompt [] {
    let source = ($repository_directory | path join "bash" "prompt.bash")
    let destination = ($env.HOME | path join ".config" "basic-cli" "prompt.bash")
    let bashrc = ($env.HOME | path join ".bashrc")
    let source_line = 'source "$HOME/.config/basic-cli/prompt.bash"'

    if not ($source | path exists) {
        print "Skipped bash prompt deployment because the prompt source is missing."
        return null
    }

    if not ($bashrc | path exists) {
        print "Skipped bash prompt deployment because ~/.bashrc is missing."
        return null
    }

    mkdir ($destination | path dirname)
    ^cp --archive $source $destination
    append-bashrc-source $bashrc "basic-cli prompt" $source_line

    [
        {
            source: $source
            destination: $destination
        }
        {
            source: $source
            destination: $bashrc
        }
    ]
}

def deploy-bash-aliases [] {
    let source = ($repository_directory | path join "bash" "aliases.bash")
    let destination = ($env.HOME | path join ".config" "basic-cli" "aliases.bash")
    let bashrc = ($env.HOME | path join ".bashrc")
    let source_line = 'source "$HOME/.config/basic-cli/aliases.bash"'

    if not ($source | path exists) {
        print "Skipped bash alias deployment because the alias source is missing."
        return null
    }

    if not ($bashrc | path exists) {
        print "Skipped bash alias deployment because ~/.bashrc is missing."
        return null
    }

    mkdir ($destination | path dirname)
    ^cp --archive $source $destination
    append-bashrc-source $bashrc "basic-cli aliases" $source_line

    [
        {
            source: $source
            destination: $destination
        }
        {
            source: $source
            destination: $bashrc
        }
    ]
}

def deploy-blesh [] {
    let source = ($repository_directory | path join "bash" "blesh")
    let destination = ($env.HOME | path join ".config" "basic-cli" "blesh")
    let blerc_source = ($repository_directory | path join "bash" "blerc")
    let blerc_destination = ($env.HOME | path join ".config" "basic-cli" "blerc")
    let loader_source = ($repository_directory | path join "bash" "blesh.bash")
    let loader_destination = ($env.HOME | path join ".config" "basic-cli" "blesh.bash")
    let bashrc = ($env.HOME | path join ".bashrc")
    let source_line = 'source "$HOME/.config/basic-cli/blesh.bash"'
    let old_source_line = '[[ $- == *i* ]] && source -- "$HOME/.config/basic-cli/blesh/ble.sh" --attach=none --rcfile "$HOME/.config/basic-cli/blerc"'
    let old_attach_line = '[[ ${BLE_VERSION-} ]] && ble-attach'

    if not (($source | path join "ble.sh") | path exists) {
        print "Skipped ble.sh deployment because the ble.sh source is missing."
        return null
    }

    if not ($blerc_source | path exists) {
        print "Skipped ble.sh deployment because the ble.sh configuration is missing."
        return null
    }

    if not ($loader_source | path exists) {
        print "Skipped ble.sh deployment because the ble.sh loader is missing."
        return null
    }

    if not ($bashrc | path exists) {
        print "Skipped ble.sh deployment because ~/.bashrc is missing."
        return null
    }

    replace-directory $source $destination
    ^cp --archive $blerc_source $blerc_destination
    ^cp --archive $loader_source $loader_destination

    let bashrc_text = (open --raw $bashrc)
    mut updated = $bashrc_text
    if ($updated | str contains $old_source_line) {
        $updated = ($updated | str replace $old_source_line $source_line)
    }
    if ($updated | str contains $old_attach_line) {
        $updated = ($updated | str replace $"($old_attach_line)(char newline)" "")
    }
    if not ($updated | str contains $source_line) {
        let prefix = if ($updated | str ends-with (char newline)) {
            $updated
        } else {
            $"($updated)(char newline)"
        }
        $updated = $"($prefix)(char newline)# ble.sh line editor(char newline)($source_line)(char newline)"
    }
    if $updated != $bashrc_text {
        $updated | save --force $bashrc
    }

    [
        {
            source: $source
            destination: $destination
        }
        {
            source: $blerc_source
            destination: $blerc_destination
        }
        {
            source: $loader_source
            destination: $loader_destination
        }
        {
            source: $loader_source
            destination: $bashrc
        }
    ]
}

def main [
    --no-git # Skip git fetch and clone of Neovim plugin sources
] {
    let configuration_plan = [
        {
            source: ($repository_directory | path join "helix")
            destination: ($env.HOME | path join ".config" "helix")
        }
        {
            source: ($repository_directory | path join "neovim")
            destination: ($env.HOME | path join ".config" "nvim")
        }
        {
            source: ($repository_directory | path join "hypr")
            destination: ($env.HOME | path join ".config" "hypr")
        }
        {
            source: ($repository_directory | path join "herdr")
            destination: ($env.HOME | path join ".config" "herdr")
        }
        {
            source: ($repository_directory | path join "powershell")
            destination: ($env.HOME | path join ".config" "powershell")
        }
        {
            source: ($repository_directory | path join "odin")
            destination: ($env.HOME | path join ".config" "odin")
        }
        {
            source: ($repository_directory | path join "cheatsheet")
            destination: ($env.HOME | path join ".config" "cheatsheet")
        }
        {
            source: ($repository_directory | path join "nushell")
            destination: ($env.HOME | path join ".config" "nushell")
        }
    ]

    for configuration in $configuration_plan {
        mkdir $configuration.destination
        let source_contents = (glob $"($configuration.source)/*")
        ^cp --archive ...$source_contents $configuration.destination
    }

    let odinfmt_home = {
        source: ($repository_directory | path join "odin" "odinfmt.json")
        destination: ($env.HOME | path join "odinfmt.json")
    }
    ^cp --archive $odinfmt_home.source $odinfmt_home.destination

    let herdr_skill = (deploy-herdr-skill)
    let bash_prompt = (deploy-bash-prompt)
    let bash_aliases = (deploy-bash-aliases)
    let blesh = (deploy-blesh)
    let neovim_plugins = (deploy-neovim-plugins --no-git=$no_git)
    let topiary_nushell = (deploy-topiary-nushell)
    let deployed_configurations = (
        (
            if $herdr_skill == null {
                $configuration_plan
            } else {
                $configuration_plan | append $herdr_skill
            }
        )
        ++ $neovim_plugins
        ++ (if $bash_prompt == null { [] } else { $bash_prompt })
        ++ (if $bash_aliases == null { [] } else { $bash_aliases })
        ++ (if $blesh == null { [] } else { $blesh })
        ++ (if $topiary_nushell == null { [] } else { [$topiary_nushell] })
        ++ [$odinfmt_home]
    )

    print "Deployed configurations:"
    $deployed_configurations
    | select source destination
    | update source {|configuration| display-source $configuration.source }
    | update destination {|configuration| display-destination $configuration.destination }
    | print-table
}
