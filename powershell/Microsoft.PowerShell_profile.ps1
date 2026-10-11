#!/usr/bin/env pwsh

if ([string]::IsNullOrEmpty($env:WARP_TERMINAL_SESSION_UUID))
{
    Set-PSReadLineOption -EditMode Vi
}

if ([string]::IsNullOrEmpty($env:WARP_TERMINAL_SESSION_UUID))
{
    function Get-HostName
    {
        if ([string]::IsNullOrWhiteSpace($env:HOST_NAME))
        {
            if (-not [string]::IsNullOrWhiteSpace($env:HOSTNAME))
            {
                $env:HOST_NAME = $env:HOSTNAME
            } elseif (-not [string]::IsNullOrWhiteSpace($env:COMPUTERNAME))
            {
                $env:HOST_NAME = $env:COMPUTERNAME
            } else
            {
                $env:HOST_NAME = [System.Net.Dns]::GetHostName().Split('.')[0]
            }
        }
        $env:HOST_NAME
    }

    function Get-HomePath
    {

        if ([string]::IsNullOrWhiteSpace($env:USER_HOME))
        {
            $env:USER_HOME = Get-Item -Path '~' | Select-Object -ExpandProperty FullName
        }
        $env:USER_HOME
    }

    function Get-HomeRelativePath
    {
        param(
            [string]$HomePath,
            [string]$Path
        )

        if ([string]::IsNullOrEmpty($HomePath) -or [string]::IsNullOrEmpty($Path))
        {
            return $Path
        }

        $trimmedHomePath = $HomePath.TrimEnd([System.IO.Path]::DirectorySeparatorChar).Trim()
        if ($Path.StartsWith($trimmedHomePath, [System.StringComparison]::Ordinal))
        {
            "~$($Path.Substring($trimmedHomePath.Length))"
        } else
        {
            $Path
        }
    }

    function prompt
    {
        $escape = [char]27
        $user = [System.Environment]::UserName
        $hostName = Get-HostName
        $homePath = Get-HomePath
        $directory = Get-HomeRelativePath -HomePath $homePath -Path $PWD.Path

        "${escape}[0m`n╭─|${escape}[36m ${user}${escape}[0m@${escape}[91m${hostName}${escape}[0m: ${escape}[92m${directory}${escape}[0m`n╰─${escape}[3;93m PS${escape}[0m `$ "
    }
}

if (-not ('MEGraphDeviceCodeConsoleWriter' -as [type]))
{
    Add-Type -TypeDefinition @'
using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;

public sealed class MEGraphDeviceCodeConsoleWriter : TextWriter
{
    private static readonly Regex UrlPattern = new Regex(@"https?://[^\s]+", RegexOptions.Compiled);
    private readonly TextWriter _inner;
    private readonly string _userDataDir;
    private readonly object _gate = new object();
    private bool _opened;

    public MEGraphDeviceCodeConsoleWriter(TextWriter inner, string userDataDir)
    {
        _inner = inner ?? throw new ArgumentNullException(nameof(inner));
        _userDataDir = userDataDir ?? throw new ArgumentNullException(nameof(userDataDir));
    }

    public override Encoding Encoding
    {
        get { return _inner.Encoding ?? Encoding.UTF8; }
    }

    public override void Write(char value)
    {
        _inner.Write(value);
    }

    public override void Write(char[] buffer, int index, int count)
    {
        _inner.Write(buffer, index, count);
        if (buffer != null && count > 0)
        {
            TryOpenBrowser(new string(buffer, index, count));
        }
    }

    public override void Write(string value)
    {
        _inner.Write(value);
        TryOpenBrowser(value);
    }

    public override void WriteLine(string value)
    {
        _inner.WriteLine(value);
        TryOpenBrowser(value);
    }

    public override void Flush()
    {
        _inner.Flush();
    }

    private void TryOpenBrowser(string text)
    {
        if (string.IsNullOrEmpty(text))
        {
            return;
        }

        Match match = UrlPattern.Match(text);
        if (!match.Success)
        {
            return;
        }

        lock (_gate)
        {
            if (_opened)
            {
                return;
            }

            _opened = true;
        }

        string url = match.Value.TrimEnd('.', ',', ';', ':');
        try
        {
            var startInfo = new ProcessStartInfo
            {
                FileName = "chromium",
                UseShellExecute = false
            };
            startInfo.ArgumentList.Add("--user-data-dir=" + _userDataDir);
            startInfo.ArgumentList.Add(url);
            Process.Start(startInfo);
        }
        catch (Exception ex)
        {
            _inner.WriteLine("Failed to open Chromium Admin: " + ex.Message);
        }
    }
}
'@
}

function Connect-MEGraph
{
    $adminProfile = Join-Path $HOME '.local/share/chromium-profiles/admin'
    $originalOut = [Console]::Out
    $forwarded = [System.Collections.Generic.List[object]]::new()

    foreach ($argument in $args)
    {
        if ($argument -in @('-UseDeviceCode', '-UseDeviceAuthentication', '-DeviceCode', '-DeviceAuth', '-Device'))
        {
            continue
        }

        $forwarded.Add($argument)
    }

    try
    {
        [Console]::SetOut([MEGraphDeviceCodeConsoleWriter]::new($originalOut, $adminProfile))
        Connect-MgGraph -UseDeviceCode @forwarded
    }
    finally
    {
        [Console]::SetOut($originalOut)
    }
}
