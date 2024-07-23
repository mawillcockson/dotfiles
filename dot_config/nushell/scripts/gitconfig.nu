use std [log]
use consts.nu [platform]

# Local settings per-repository
# git config --local "user.name" "User Name"
# git config --local "user.email" "email@example.com"
# git config --local "user.signingKey" "fingerprint"
# available as `use utils.nu [setup-gitlocal]`

if $platform == 'windows' {
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
                filter {|it|
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
        log warning 'cannot find gpg, should install and rerun'
    }
}

# Don't automatically delete commits, no matter what
git config --global "gc.auto" 0
git config --global "gc.pruneExpire" "never"
git config --global "gc.worktreePruneExpire" "never"
git config --global "gc.reflogExpire" "never"
git config --global "gc.reflogExpireUnreachable" "never"
git config --global "core.logAllRefUpdates" "always"
git config --global "maintenance.auto" "false"
git config --global "maintenance.strategy" "none"
git config --global "maintenance.gc.enabled" "false"
git config --global "receive.autogc" "false"

# Signing
git config --global "push.gpgSign" "if-asked"
git config --global "tag.gpgSign" "true"
git config --global "tag.forceSignAnnotated" "true"
git config --global "commit.gpgSign" "true"
# minTrustLevel defaults to merges requiring "minimal" or higher, and
# everything else requiring "undefined" or higher
git config --global "gpg.minTrustLevel" "ultimate"
# Forces side-branches to have a trusted key signing the tip commit
#git config --global "merge.verifySignatures" "true"

# General
git config --global "init.defaultBranch" "main"
git config --global "push.default" "simple"
git config --global "core.safecrlf" "true"
# Apparently, "input" still does some conversions, despite the docs saying that
# it won't: https://stackoverflow.com/a/21822812
git config --global "core.autocrlf" "false"
git config --global "core.abbrev" "no"
git config --global "clean.requireForce" "true"
# Disables repository urls starting with git://
# These aren't encrypted with TLS.
git config --global "protocol.git.allow" "never"
# Same thing for http, since that's different from https://
git config --global "protocol.http.allow" "never"
git config --global "status.branch" "true"
git config --global "user.useConfigOnly" "true"
git config --global "pull.ff" "only"

# this could speed up starsip's `git status`, but it didn't in the lightest of
# testing
#git config --local "core.fsmonitor" "true"
