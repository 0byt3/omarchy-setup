#!/usr/bin/env nu

# Keep persistent workspaces 1–13 on the active external display. When no
# external display is connected, they remain on the laptop's internal panel.
const internal_monitor = "eDP-1"
const first_external_workspace = 1
const last_external_workspace = 13

def target-monitor [] {
    let monitors = (^hyprctl monitors -j | from json)
    let external_monitors = (
        $monitors
        | where {|monitor| $monitor.name != $internal_monitor and $monitor.disabled == false }
    )
    let focused_external_monitors = $external_monitors | where focused

    if not ($focused_external_monitors | is-empty) {
        $focused_external_monitors | get 0.name
    } else if not ($external_monitors | is-empty) {
        $external_monitors | get 0.name
    } else {
        $internal_monitor
    }
}

def move-workspaces [] {
    let monitor = target-monitor

    for workspace in $first_external_workspace..$last_external_workspace {
        ^hyprctl dispatch moveworkspacetomonitor $"($workspace) ($monitor)" | ignore
    }
}

def main [] {
    # Apply the intended layout at session startup.
    move-workspaces

    let socket = (
        $env.XDG_RUNTIME_DIR
        | path join "hypr" $env.HYPRLAND_INSTANCE_SIGNATURE ".socket2.sock"
    )

    # Re-evaluate after the compositor has finished adding or removing a
    # monitor. The small delay avoids acting on an intermediate monitor list.
    ^socat -U - $"UNIX-CONNECT:($socket)"
    | lines
    | each {|event|
        let event_name = $event | str trim

        if (
            ($event_name | str starts-with "monitoradded")
            or ($event_name | str starts-with "monitorremoved")
        ) {
            sleep 250ms
            move-workspaces
        }
    }
}
