use consts.nu [autoload]

# removes file if it's no longer necessary

$env.ASDF_DIR = ($env.HOME | path join '.asdf')
let asdf_nu = ($env.ASDF_DIR | path join 'asdf.nu')
if ($asdf_nu | path exists) {
    echo $"source \(($asdf_nu | to nuon)\)" |
    save -f ($autoload | path join '56_asdf_generated_source_setup.nu')
    | null
} else {
    rm --force ($autoload | path join '56_asdf_generated_source_setup.nu')
}
