use std [log]
let $projects = $nu.home-path | path join 'projects'
log info $'will place ~/projects at ($projects)'
mkdir $projects
if ($projects | path join 'dotfiles' | path exists) {
    log info 'using already existing dotfiles'
} else {
    log info 'using git to download dotfiles'
    ^git clone 'https://github.com/mawillcockson/dotfiles.git' ($projects | path join 'dotfiles')
}
nu ($projects | path join 'dotfiles' 'dotfiles' 'packages' 'install.nu')
