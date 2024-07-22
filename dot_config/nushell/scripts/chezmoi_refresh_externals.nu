use std [log]

def main [] {
    cd ~/projects/dotfiles
    open --raw .chezmoiexternal.toml.tmpl |
    from toml |
    transpose path data |
    filter {|it|
        if $it.data.type != 'file' {
            log warning $"don't know how to refresh: ($it)"
            return false
        } else { return true }
    } |
    par-each {|it|
        mkdir ($it.path | path dirname)
        http get --max-time 3 $it.data.url | save -f $it.path
    }
}
