if ($host.Name -eq 'ConsoleHost') {
    Set-PSReadLineOption -EditMode Vi
}

function prompt {
    $p = $PWD.Path
    if ($env:HOME -and $p.StartsWith($env:HOME)) {
        $p = "~$($p.Substring($env:HOME.Length))"
    }
    $branch = git rev-parse --abbrev-ref HEAD 2>$null
    $git = if ($branch) { " `e[36m(${branch})`e[0m" } else { "" }
    $user = if ($env:USER) { $env:USER } else { 'vscode' }
    "`e[1;32m${user}`e[0m `e[32m➜`e[0m `e[1;34m${p}`e[0m${git} $ "
}
