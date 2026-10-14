#!/usr/bin/env nu

# Convenience script to send events/commands to the Window-ing environment
def main [
    command: string # valid commands: workspace
    value: string # if command is workspace then this is the workspace number
]: nothing -> nothing {
    match $command {
        "workspace" | "ws" => {
            try {
                $value | into int | ignore -x
            } catch {|err|
                error make {msg: "If command is 'workspace' then value must be a number."}
            }
            # hl.dsp.focus({ workspace = "3" })
            let hyprctl_eval = [
                "hl.dsp.focus({ "
                $"workspace = \"($value)\""
                " })"
            ] | str join ""

            print $hyprctl_eval
            ^hyprctl dispatch $hyprctl_eval
        }
        _ => (error make {msg: $"($command) is not a valid command."})
    }
}
