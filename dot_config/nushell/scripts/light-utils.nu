export def --env "path add" [
     --prepend (-p)  # prepend to $env.PATH instead of appending to.
     --ignore-nulls # don't produce errors on null paths; empty path values will still produce errors
     ...paths  # the paths to add to $env.PATH.
]: [
    nothing -> list<string>
] {
    if ($paths | is-empty) or ($paths | length) == 0 {
        error make {msg: "Empty input", label: {
            text: "Provide at least one string or a record",
            span: (metadata $paths).span,
        }}
    }

    let paths = (
        $paths
        | each {|p|
            match ($p | describe | str replace --regex '<.*' '') {
                "string" | "nothing" => $p,
                "record" => { $p | get --ignore-errors $nu.os-info.name },
                _ => {
                    return (error make {
                        msg: $'unsupported path type: ($p | describe)',
                        label: {
                            text: 'expected string, record, or null',
                            span: (metadata $p).span,
                        },
                    })
                },
            }
        }
        | compact
        | path expand --no-symlink
        | each {|p|
            if ($p | is-empty) {
                error make {
                    msg: 'empty path',
                    label: {
                        span: (metadata $p).span,
                    },
                }
            } else {
                $p
            }
        }
    )

    let path_env_name = ([Path, PATH] | filter {$in in $env} | first)
    (
            $env
            | get $path_env_name
            | if ($in | describe | str replace --regex '<.*' '') == 'string' {
                $in | split row (char env_sep)
            } else {$in}
            | if $prepend { prepend $paths } else { append $paths }
    ) |
    tee {
        { ($path_env_name): ($in) } | load-env
    }
}
