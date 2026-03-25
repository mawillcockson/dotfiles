use std/log

export const default_ca_type = 'ed25519'
export const default_ca_comment = 'git CA'
export const default_user_type = $default_ca_type
export const default_principals = [logseq]
# 52 weeks, ~1 year
export const default_validity_interval = '+52w'
export const default_cert_options = ([
    clear
    force-command=/usr/bin/git-shell
    no-agent-forwarding
    no-port-forwarding
    no-pty
    no-user-rc
    no-x11-forwarding
])

export def main []: nothing -> nothing {
    let user_ca_key = (pwd | path join $'ca_user_($default_ca_type)')
    let host_ca_key = (pwd | path join $'ca_host_($default_ca_type)')
    ca key $user_ca_key $host_ca_key
    let hostname = (sys host | get hostname)
    let user_key = (pwd | path join $'($hostname)_($default_user_type)')
    user key $user_key
    let user_cert = (pwd | path join $'($hostname).cert')
    user cert $user_ca_key $user_key $user_cert
}

export def "ca key" [
    # where to put the resulting private key that's used for user keys
    user_out: path,
    # where to put the resulting private key that's used for host keys
    host_out: path,
    # the comment to include in the ssh key
    --comment (-C): string,
    # the key type
    --type (-t): string,
    # number of bits for the key
    --bits (-b): int,
]: [
    #nothing -> record<string: path>
    nothing -> nothing
] {
    for $out in ([$user_out $host_out] | uniq) {
        log info $'creating ssh private key at ($out | to nuon)'
        run-external ssh-keygen ...([
            -f $out
            -t ($type | default $default_ca_type)
        ] | if ($comment | is-not-empty) {
            append [-C $comment]
        } else {$in} |
        if ($bits | is-not-empty) {
            [-b $bits]
        } else {$in})
    }
    #return {
    #    user_out: $user_out,
    #    host_out: $host_out,
    #}
}

export def "user key" [
    # where to put the key
    out: path,
    # the comment to include in the ssh key
    --comment (-C): string,
    # the key type
    --type (-t): string,
    # number of bits for the key
    --bits (-b): int,
]: [
    nothing -> path
    nothing -> nothing
] {
    log info $'making a user private key at: ($out | to nuon)'
    run-external ssh-keygen ...([
        -f $out
        -t ($type | default $default_user_type)
    ] | if ($comment | is-not-empty) {
        append [-C $comment]
    } else {$in} |
    if ($bits | is-not-empty) {
        [-b $bits]
    } else {$in})

    #return $out
}

export def "user cert" [
    # path to the ssh CA private key to use for signing
    ca_private_key: path,
    # user key (public or private) to sign
    user_key: path
    # where to put the certificate
    out: path,
    # number of bits in the key
    --bits (-b): int,
    --comment (-C): string,
    # who is this certificate for? will be appended with a creation date
    --for: string,
    # path to a Key Revocation List to create or append to
    #--krl (-f): path,
    # principals to include in the certificate
    --principals (-n): list<string>,
    # time range for which a certificate can be valid
    --validity (-V): string,
    # ssh key -O options
    --options (-O): list<string>,
    # serial number to include in the key
    --serial-number (-z): int,
]: [
    #nothing -> path
    nothing -> nothing
] {
    log info $"creating a user cert at \(hopefully\): ($out | to nuon)"

    let identity = (
        $for |
        default (sys host | get hostname) |
        $'($in)@(date now | format date '%+')'
    )
    log debug $'identity -> ($identity)'

    #let krl = (
    #    $krl |
    #    default (
    #        echo '~/.ssh/revoked_keys' | path expand
    #    )
    #)
    #log debug $'krl -> ($krl)'

    let principals = (
        $principals |
        default --empty $default_principals
    )
    log debug $'principals -> ($principals | to nuon)'

    let options = (
        $options |
        default $default_cert_options |
        each {[-O $in]} |
        flatten
    )
    log debug $'options -> ($options | to nuon)'

    let validity = (
        $validity |
        default --empty $default_validity_interval
    )
    log debug $'validity -> ($validity)'

    let serial_number = (
        if ($serial_number | is-not-empty) {
            $serial_number
        } else {
            # quintillion
            random int 0..1_000_000_000_000_000_000
        }
    )

    let args = [
        -s $ca_private_key
        -I $identity
        -n ...($principals)
        -V $validity
        -z $'($serial_number)'
    ] |
    #if ($krl | path exists) {
    #    append [-k -u -f $krl]
    #} else {
    #    append [-k -f $krl]
    #} |
    append $options |
    if ($comment | is-not-empty) {
        append [-C $comment]
    } else {$in} |
    if ($bits | is-not-empty) {
        append [-b $bits]
    } else {$in} |
    append [$user_key]

    try { log debug $"final args:\n($args | to nuon)" }

    run-external ssh-keygen ...($args)

    let guess = (
        $user_key |
        path parse |
        update stem {|rec| $'($rec.stem)-cert'} |
        update extension 'pub' |
        path join
    )
    if not ($guess | path exists) {
        log error $'based on input filename -> ($in | to nuon), expected cert to be created at ($guess | to nuon), but it was not there'
        return (error make {
            msg: 'do not know where cert was created at'
        })
    }
    mv --verbose $guess $out
    #return $out
}
