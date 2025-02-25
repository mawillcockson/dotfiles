use consts.nu [platform]
use std/log

$env.EGET_BIN = ($env | get EGET_BIN? | default (echo '~/apps/eget-bin' | path expand))
log info $'making directory ($env.EGET_BIN | to nuon)'
mkdir $env.EGET_BIN
let destination = ($env.EGET_BIN | path join (match $platform {
    'windows' => 'nu.exe',
    _ => 'nu',
}))
cp --verbose $nu.current-exe $destination
if $platform in [linux, android, macos] and (which chmod | is-not-empty) {
    log info 'attempting to set executable bit'
    try {^chmod +x $destination}
}

log info $'you can try running something like the following, and hope it works:

($env.EGET_BIN | to nuon) -e "do {use setup; setup ($platform)}"'
