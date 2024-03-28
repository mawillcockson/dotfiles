const scripts = $"($nu.default-config-dir)/scripts"
const generated = $"($scripts)/generated"
const default_config = $"($generated)/default_config.nu"
source $default_config

const postconfig = $"($generated)/postconfig.nu"
# because this is a parser directive, it can't be guarded with `if path
# exists`: if it exists, it'll be sourced, and if it doesn't, the whole file
# can't be read
source $postconfig

export use $"($scripts)/clipboard.nu"
# changing this to `overlay use` produces an error at line 20 for some reason
export use $"($scripts)/utils.nu"

def "date my-format" [] {
    let my_date = date now | format date "%Y-%m-%dT%H%M%z"
    $my_date | clipboard clip
}
alias dt = date my-format

# Atuin should be able to handle a lot of history, so don't cull based on
# number of entries
# let opopo = {
#     history.max_size: 10_000_000
#     show_banner: false
# }
