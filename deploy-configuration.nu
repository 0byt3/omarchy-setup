#!/usr/bin/env nu

const repository_directory = (path self | path dirname)

def print-table [] {
    $in | to csv | ^gum table --print
}

def display-source [source] {
    try {
        $source | path relative-to $repository_directory
    } catch {
        $source
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
    $"($skill)(char newline)(char newline)The default shell of herdr is nushell.(char newline)" | save --force $destination

    {
        source: "herdr --skill"
        destination: $destination
    }
}

def display-destination [destination] {
    let relative_destination = (try {
        $destination | path relative-to $env.HOME
    } catch {
        null
    })

    if $relative_destination == null {
        $destination
    } else if $relative_destination == "" {
        "~"
    } else {
        $"~/($relative_destination)"
    }
}

def main [] {
    let configuration_plan = [
        {
            source: ($repository_directory | path join "helix")
            destination: ($env.HOME | path join ".config" "helix")
        }
        {
            source: ($repository_directory | path join "omarchy" "themes" "eag")
            destination: ($env.HOME | path join ".config" "omarchy" "themes" "eag")
        }
        {
            source: ($repository_directory | path join "hypr")
            destination: ($env.HOME | path join ".config" "hypr")
        }
        {
            source: ($repository_directory | path join "herdr")
            destination: ($env.HOME | path join ".config" "herdr")
        }
    ]

    for configuration in $configuration_plan {
        mkdir $configuration.destination
        let source_contents = (glob $"($configuration.source)/*")
        ^cp --archive ...$source_contents $configuration.destination
    }

    let herdr_skill = (deploy-herdr-skill)
    let deployed_configurations = if $herdr_skill == null {
        $configuration_plan
    } else {
        $configuration_plan | append $herdr_skill
    }

    print "Deployed configurations:"
    $deployed_configurations
    | select source destination
    | update source {|configuration| display-source $configuration.source }
    | update destination {|configuration| display-destination $configuration.destination }
    | print-table
}
