use consts.nu [autoload]

$env.ASDF_DIR = ($env.HOME | path join '.asdf')
let asdf_nu = ($env.ASDF_DIR | path join 'asdf.nu')
if ($asdf_nu | path exists) {
    echo $"source \(($asdf_nu | to nuon)\)"
} else {
    use std/log
    const msg = 'asdf setup script not found'
    log debug $msg
    echo $'# ($msg)'
} |
save -f ($autoload | path join '56_asdf_generated_source_setup.nu') |
null
