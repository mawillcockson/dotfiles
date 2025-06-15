use std/log

export def main [] {
    if (which apt-get | is-empty) {
        return (error make {
            'msg': 'is this a system with apt installed? could not find executable "apt-get"',
        })
    }

    if ('/etc/apt' | path type) != 'dir' {
        return (error make {
            'msg': 'expected apt configuration to be located at /etc/apt/',
        })
    }

    if not ('~/projects/dotfiles/' | path exists) {
        return (error make {
            'msg': 'expected to be able to pull files from ~/projects/dotfiles/, but it does not exist',
        })
    }
    let from = ('~/projects/dotfiles/debian' | path expand)
    let to = '/etc/apt'
    [
        'apt/preferences.d/01_general',
        'apt/sources.list.d/01_general.sources',
        'apt/sources.list.d/02_backports.sources',
    ] |
    each {|it|
        {
            'from': ($from | path join $it),
            'to': ($to | path join $it),
        }
    } |
    where {|it|
        if ($it.to | path exists) {
            log info $'path exists already, not overwriting -> ($it.to)'
            false
        } else {true}
    } |
    each {|it|
        sudo cp $it.from $it.to
    }
}
