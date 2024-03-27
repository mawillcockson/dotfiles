const packages = {
    'install_script': [
        'aria2',
        'clink',
        'git',
        'gnupg',
    ],

    'auto_dependencies': [
        '7zip',
        'dark',
        'innounp',
    ],

    'essential': [
        'dejavusansmono-nf',
        'eget',
        'fd',
        'jq',
        'mpv',
        'neovide',
        'neovim',
        'notepadplusplus',
        'nu',
        'peazip',
        'python',
        'rclone',
        'ripgrep',
        'sqlite',
        'starship',
        'vlc',
        'windirstat',
        'wsl-ssh-pageant',
    ],

    'yt-dlp': [
        'ffmpeg',
    ],

    'keepass': [
        'keepass',
        'keepass-plugin-keetraytotp',
        'keepass-plugin-readable-passphrase',
    ],

    'neovim_dependencies': [
        'stylua',
        'taplo',
        'tree-sitter',
    ],

    'large': [
        'inkscape',
        'obs-studio',
    ],

    'small_rarely': [
        'caddy',
        'duckdb',
        'gifsicle',
        'gifski',
        'love',
        'luajit',
        'pandoc',
        'rufus',
        'shellcheck',
        'transmission',
        'upx',
        'xmplay',
        'zig', # currently I'm using this as the compiler for neovim's tree-sitter
        'zstd',
    ],

    'rarely': [
        'audacity',
        'filezilla',
        'fontforge',
        'handbrake',
        'hashcat',
        'imageglass',
        'libreoffice',
        'picard',
        'screentogif',
    ],

    'why_even': [
        'foobar2000',
        'freac',
        'fvim',
        'libxml2',
    ],
}

^powershell -c 'scoop update'

let selected_packages = (
    $packages | select 'essential' 'yt-dlp' 'keepass' 'small_rarely' | values | flatten | uniq
)
# NOTE::DEBUG
#let selected_packages = ["nonexistent"]
#print $selected_packages

let outputs = $selected_packages | each {
    |package|
    print --no-newline $'installing ($package)...'
    let output = (
        # have to run inside a `do` block in order to capture stderr, too
        do {
            # could do `^scoop install $package`, but the scoop shim always
            # exits with 0 :/
            ^powershell -c $'scoop install "($package)"'
        } | complete
    )
    if $output.exit_code == 0 { print '✔️' } else { print '❌' }
    return { 'package': $package, 'output': $output}
}

# NOTE::DEBUG
#$outputs | to text | print $in

let errors = $outputs | filter {|output| $output.output.exit_code != 0 }
if ($errors | length) == 0 { 
    print 'all packages installed succesfully'
    exit 0
}

# errors happened
print 'these packages encountered errors during installation'
$errors | each {
    |output|
    print $output.package
}
let timestamp = date now | format date '%+' | str replace --all ':' ''
let logs = $nu.default-config-dir | path join "logs"
mkdir $logs
let log_file = $logs | path join $"scoop_install_errors_($timestamp).json"
print $"\nsaving output to ($log_file)"
$errors | to json | save $log_file
