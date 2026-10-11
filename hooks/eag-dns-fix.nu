#!/usr/bin/nu --no-config-file
# By default '{name}.local' uses mDNS resolution only, however EAG uses some internal domains that end in '.local'

const eag_dns_servers = [ '10.101.10.4', '10.115.10.7', '10.101.10.8' ]
const route_domains = [ 'emil.local', 'viewpoint.local', 'emilanderson.ca', 'eac.bc.ca' ]

def test-eag-domain []: [string -> bool, list -> bool] {
    let ip_list = $in

    $eag_dns_servers | par-each {|s|
        $ip_list | each {|ip|
            ^dig -b $ip +short $"@($s)" SRV _ldap._tcp.dc._msdcs.emil.local
            | complete
            | match $in {
                {exit_code: 0, stdout: $stdout} => (not ($stdout | str trim | is-empty))
                _ => false
            }
        }
    }
    | any {|ok| $ok}
}

def get-conn-info [conn_uuid: string] {
    
    $env | transpose key val | where key =~ "^(IP[46]|CONNECTION_ID)"
    | reduce --fold {connection: null, ip4_addr: [], domains: []} {|i,acc|
        match $i.key {
            'CONNECTION_ID' => ($acc | upsert connection $i.val)
            'IP4_DOMAINS' | 'IP6_DOMAINS' =>  (
                $acc
                | upsert domains {|a|
                    $i.val | split row --regex '[\s\t]+'
                    | par-each {|d| $d | str trim }
                    | append $a.domains
                }
            )
            $k if ($k | str contains "IP4_ADDRESS") => {
                let ip = $i.val | parse "{ip}/{the_rest}" | get ip | first
                $acc |
                upsert ip4_addr {|a|
                    $a.ip4_addr | append $ip
                }
            }
            _ => $acc
        }
    } | upsert type {|info|
        ^nmcli -g "connection.type" con show $info.connection
        | complete | match $in {
            {exit_code: 0, stdout: $out} => ($out | str trim)
            _ => ""
        }
    }
}

def main [interface: string, event: string] {
    $env
    | upsert script_args {interface: $interface, event: $event}
    | save -f /home/erolleman/debug/net-dispatcher-env.nuon
    ^chown erolleman:erolleman /home/erolleman/debug/net-dispatcher-env.yaml

    let self = $env.CURRENT_FILE | path basename

    match $event {
        'up' | 'dhcp4-change' | 'dhcp6-change' | 'reapply' => {
            let conn = get-conn-info $env.CONNECTION_ID

            if (
                ($conn.type in ['802-3-ethernet', '802-11-wireless'])
                and (not ($conn.addr | is-empty))
                and (test-eag-domain $conn.addr)
            ) {
                let current_domains = (
                    ^resolvectl domain $interface
                    | lines
                    | parse '{fluff}: {domains}'
                    | get --optional 0.domains
                    | default ""
                    | split row ' '
                    | where {|d| not ($d | is-empty)}
                )

                let add_domains = (
                    $route_domains
                    | where {|d|
                        ($d not-in $current_domains) and ($"~($d)" not-in $current_domains)
                    }
                    | each {|d| $"~($d)" }
                )

                if not ($add_domains | is-empty) {
                    ^resolvectl domain $interface ...$current_domains ...$add_domains
                }
            }
        }
        _ => {
            $"($self) only applies to up/dhcp4-change/dhcp6-change/reapply events" | print -e
        }
    }
}
