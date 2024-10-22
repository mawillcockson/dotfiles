use std/log

export def main [] {
    comiccode
}

export def comiccode [] {
    log info 'installing prerequisites'
    run-external $nu.current-exe '-c' 'use package; package install zstd'
    run-external $nu.current-exe '-c' 'use package; package install age'

    let tmpdir = (mktemp --tmpdir --directory)
    log info $'making $tmpdir -> ($tmpdir)'
    mkdir $tmpdir
    let encrypted = ($tmpdir | path join 'fonts.tar.zst.age')
    let unencrypted = ($tmpdir | path join 'fonts.tar.zst')
    let uncompressed = ($tmpdir | path join 'fonts.tar')
    let to = ($env.HOME | path join '.local' 'share' 'fonts')
    log info $'making $to -> ($to)'
    mkdir $to

    log info $'downloading encrypted fonts stash to ($encrypted)'
    http get --max-time 30 'https://mw.je/fonts.tar.zst.age' |
    save -f $encrypted
    let age_key = ('~/.age/chezmoi_age_identity.txt.age' | path expand)
    log info $'using age to decrypt font stash, with the key assumed to be at ($age_key)'
    age --decrypt --identity $age_key --output $unencrypted $encrypted
    log info 'decompressing font stash'
    zstd --decompress $unencrypted -o $uncompressed
    log info $'unpacking font stash to ($to)'
    tar -xf $uncompressed -C $to

    log info 'removing $tmpdir'
    rm -r $tmpdir
    log info 'refreshing fontconfig cache'
    fc-cache -fv
}
