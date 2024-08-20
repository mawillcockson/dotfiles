use std [log]
use utils.nu ["powershell-safe"]

export def main [] {
    comiccode
}

export def dejavusansmono [] {
    # the reason I'm not `use`-ing `package install` commands here is that I
    # don't want to drag in `package` as a dependency
    run-external $nu.executable '-c' 'scoop bucket add nerd-fonts'
    run-external $nu.executable '-c' 'scoop install DejaVuSansMono-NF'
}

export def comiccode [] {
    if (
        $env |
        get ONEDRIVE? OneDrive? ONEDRIVECONSUMER? OneDriveConsumer? |
        is-empty
    ) {
        log warning "OneDrive not signed in? Can't install Comic Code NF from OneDrive, then"
        return false
    }
    do {
        cd (comiccode_dir)
        glob --no-dir --no-symlink '*.otf'
    } |
    each {|it|
        $it |
        # https://web.archive.org/web/20220620091307/https://www.alkanesolutions.co.uk/2021/12/06/installing-fonts-with-powershell/
        # Alternate technique here:
        # https://github.com/matthewjberger/scoop-nerd-fonts/blob/3917d7a81a5559eae34c4f97918e0bc1d78c7810/bucket/DejaVuSansMono-NF-Mono.json#L13-L29
        powershell-safe -c '(New-Object -ComObject Shell.Application).Namespace(0x14).CopyHere($Input,0x14)'
    }
}

export def comiccode_dir [] {
    $env |
    get ONEDRIVE? OneDrive? ONEDRIVECONSUMER? OneDriveConsumer? |
    first |
    path join 'Documents' 'Fonts' 'Comic Code' 'careful'
}
