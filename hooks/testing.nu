# const eag_dns_servers = [ '10.101.10.4', '10.115.10.7', '10.101.10.8' ]
const eag_dns_servers = [ '8.8.8.8']

def test-eag-domain []: [string -> bool, list -> bool] {
    let ip_list = if ($in | describe) == "string" {
        [$in]
    } else {
        $in
    }

    $eag_dns_servers | each {|s|
        $ip_list | par-each {|ip|
            ^dig -b $ip +short $"@($s)" SRV _ldap._tcp.dc._msdcs.emil.local
            | complete
            | match $in {
                {exit_code: 0, stdout: $stdout} => (not ($stdout | str trim | is-empty))
                _ => false
            }
        }
    }
    | tee { $in | first | print }
    | flatten
    | any {}
}

"10.0.2.63" | test-eag-domain
