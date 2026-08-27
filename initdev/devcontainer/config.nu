$env.config.edit_mode = "vi"
$env.config.show_banner = false
$env.PROMPT_COMMAND = {||
    let path = if ($env.PWD | str starts-with $env.HOME) {
        $env.PWD | str replace $env.HOME "~"
    } else { $env.PWD }
    let branch = do { git rev-parse --abbrev-ref HEAD } | complete
    let git = if $branch.exit_code == 0 and ($branch.stdout | str trim) != "" { " " + (ansi cyan) + "(" + ($branch.stdout | str trim) + ")" + (ansi reset) } else { "" }
    $"(ansi green_bold)($env.USER? | default 'vscode')(ansi reset) (ansi green)➜(ansi reset) (ansi blue_bold)($path)(ansi reset)($git) $ "
}
$env.PROMPT_COMMAND_RIGHT = ""
$env.PROMPT_INDICATOR = ""
$env.PROMPT_INDICATOR_VI_INSERT = ""
$env.PROMPT_INDICATOR_VI_NORMAL = ""
