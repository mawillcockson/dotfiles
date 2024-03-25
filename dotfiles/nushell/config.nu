const scripts = $"($nu.default-config-dir)/scripts"
const generated = $"($scripts)/generated"
const default_config = $"($generated)/default_config.nu"
source $default_config

export use $"($scripts)/clipboard.nu"

def "date my-format" [] {
    let my_date = date now | format date "%Y-%m-%dT%H%M%z"
    $my_date | clipboard clip
}
alias dt = date my-format

const postconfig = $"($generated)/postconfig.nu"
if ($postconfig | path exists) {
    source $postconfig
}
