use std [log]

def main [] {
    cd (chezmoi dump-config --format=json | from json | get 'workingTree')
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
