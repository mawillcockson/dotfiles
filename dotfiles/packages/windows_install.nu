const packages = $'($nu.home-path)/projects/dotfiles/dotfiles/packages'
const package_module = $'($packages)/packages.nu'
use $package_module
const utils = $'($nu.home-path)/projects/dotfiles/dotfiles/nushell/scripts/utils.nu'
use $utils [log]

def powershell [cmd: string] {
    ^powershell -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy RemoteSigned -Command $cmd
}

log 'updating scoop'
if (which 'scoop' | length) <= 0 {
    log 'installing scoop'
    powershell 'Invoke-RestMethod -UseBasicParsing -Uri "https://get.scoop.sh" | Invoke-Expression; scoop install aria2 git nu'
} else {
    powershell 'scoop update'
}
let default_buckets = [
    'main',
    'extras',
    'nerd-fonts',
]
log 'checking currently enabled buckets:'
let buckets = (powershell '(scoop bucket list).Name' | lines)
let missing_buckets = ($default_buckets | filter {|it| $it not-in $buckets})
log $"adding buckets: ($missing_buckets | str join ', ')"
$missing_buckets | each {|it| powershell $"scoop bucket add '($it)'"}

# let selected_packages = packages select-by-tags 'essential' 'yt-dlp' 'keepass' 'small_rarely' | where install.windows? != null
let selected_packages = packages select-by-tags 'yt-dlp' 'keepass' 'test' | where install.windows? != null
log info $'($selected_packages | length) packages were selected'
let with_package_manager = $selected_packages | filter {|it| ($it.install.windows | reject custom? | columns | length) > 0}
let package_managers = $selected_packages | get install.windows | reject custom? | columns | uniq
$package_managers | filter {|it| $it not-in ['scoop' 'winget']} | collect {|it|
    if ($it | length) != 0 {
        return (error make {
            'msg': $"these package managers are not supported yet: ($it | str join ', ')",
        })
    }
}
#  | reduce --fold {} {|it,acc| {...($acc), $it: []}}
let by_package_manager = $with_package_manager | get install.windows | reject custom? | reduce --fold {} {|it,acc|
    let package_manager = $it | columns | first
    let id = $it | values | first
    $acc | upsert $package_manager (
        $acc | get --ignore-errors $package_manager | default [] | append $id
    )
}
print ($by_package_manager | table -e)
# exit 0
# let custom_install = $selected_packages | where install.windows?.custom? != null
# 
# let outputs = $selected_packages | filter {|it| $it.install.windows?.custom? == null and  each {
#     |package|
#     print --no-newline $'installing ($package.name)...'
#     let output = (
#         # have to run inside a `do` block in order to capture stderr, too
#         do {
#             # could do `^scoop install $package`, but the scoop.cmd shim always
#             # exits with 0 :/
#             powershell $'scoop install "($package.name)"'
#         } | complete
#     )
#     if $output.exit_code == 0 { print '✔️' } else { print '❌' }
#     return { 'package': $package, 'output': $output}
# }
# 
# # NOTE::DEBUG
# #$outputs | to text | print $in
# 
# let errors = $outputs | filter {|output| $output.output.exit_code != 0 }
# if ($errors | length) == 0 { 
#     print 'all packages installed succesfully'
#     exit 0
# }
# 
# # errors happened
# print 'these packages encountered errors during installation'
# $errors | each {
#     |output|
#     print $output.package
# }
# let timestamp = date now | format date '%+' | str replace --all ':' ''
# let logs = $nu.default-config-dir | path join "logs"
# mkdir $logs
# let log_file = $logs | path join $"scoop_install_errors_($timestamp).json"
# print $"\nsaving output to ($log_file)"
# $errors | to json | save $log_file
