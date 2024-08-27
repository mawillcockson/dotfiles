use std [log]

export def main [] {
    comiccode
}

export def comiccode [] {
    run-external $nu.current-exe '-c' 'use package; package install zstd'
    run-external $nu.current-exe '-c' 'use package; package install age'

    let tmpdir = (mktemp --tmpdir --directory)
    log debug $'making $tmpdir -> ($tmpdir)'
    mkdir $tmpdir
    let encrypted = ($tmpdir | path join 'fonts.tar.zst.age')
    let unencrypted = ($tmpdir | path join 'fonts.tar.zst')
    let uncompressed = ($tmpdir | path join 'fonts.tar')

    log info 'downloading encrypted fonts stash'
    http get --max-time 10 https://mw.je/fonts.tar.zst.age |
    save -f $encrypted
    age --decrypt --identity ~/.age/chezmoi_age_identity.txt.age --output $unencrypted $encrypted
    zstd --decrypt $unencrypted -o $uncompressed
    tar -xf $uncompressed -C ~/.local/share/fonts/

    rm -r $tmpdir
}
