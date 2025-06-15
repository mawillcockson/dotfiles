use std/log

export def main [] {
# ensure the scoop version of git uses the builtin Windows version of SSH, not the version packaged with Git-for-Windows
    if (which 'ssh' | is-not-empty) {
        let sshCommand = (
            which 'ssh' |
            get 0.path |
            str replace --all '\' '/'
        )
        git config --global "core.sshCommand" $sshCommand
    } else {
        return (error make {
            'msg': "could not find Windows' builtin ssh",
        })
    }

    if (which 'ssh-keygen' | is-not-empty) {
        # I'm unlikely to use it, but git supports signing using SSH keys, in
        # addition to the GnuPG keys I currently use
        let ssh_keygen = (
            which 'ssh-keygen' |
            get 0.path |
            str replace --all '\' '/'
        )
        git config --global "gpg.ssh.program" $ssh_keygen
    } else {
        return (error make {
            'msg': "could not find Windows' builtin ssh-keygen",
        })
    }

    if (which 'gpg' | is-not-empty) {
        let gpg_program = (
            which 'gpg' |
            get 0.path |
            find_current $in |
            str replace --all '\' '/'
        )
        git config --global "gpg.program" $gpg_program
        git config --global "gpg.openpgp.program" $gpg_program
    } else {
        log warning 'cannot find gpg, could try an install and rerun'
    }
}

def find_current [p: path] {
    for dir in (
        $p |
        path split |
        0..<($in | length) |
        each {|it| $p | path split | drop $it | path join}
    ) {
        if ($dir | path basename) == 'current' {
            return $dir
        }

        if ($dir | path type) != 'dir' {
            continue
        }

        let current = (
            ls --all --full-paths $dir |
            where {|it|
                $it.type == 'symlink' and ($it.name | path basename) == 'current'
            }
        )
        if ($current | is-not-empty) {
            let current = ($current | get 0.name)
            let rest = (
                $p |
                path relative-to ($current | path expand --strict)
            )
            let current_file = (
                $current |
                path join $rest
            )
            if not ($current_file | path exists) {
                return (error make {
                    'msg': $"constructed incorrect path:\n$current: ($current)\n$rest: ($rest)\n$dir: ($dir)\n$p: ($p)",
                })
            }
            return $current_file
        }
    }
}
