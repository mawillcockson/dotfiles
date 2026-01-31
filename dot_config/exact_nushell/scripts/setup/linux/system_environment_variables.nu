use std/log

export const variable_names = [
    'ALREADY_SOURCED_SYSTEM_PROFILE_D',
    'XDG_CONFIG_HOME',
    'XDG_DATA_HOME',
]

export def main [
    # copy ones that can be copied
    --continue
    variable_names_: list<string> = $variable_names,
] {
    let vars = (
        $variable_names_ |
        wrap name |
        insert source {|rec|
            $env.HOME |
            path join '.profile.d' $'($rec.name).sh' |
            path expand
        } |
        insert destination {|rec|
            '/etc/profile.d' |
            path join $'($rec.name).sh'
        } |
        insert source_found {|rec|
            $rec.source | path exists
        } |
        insert source_content {|rec|
            if $rec.source_found {
                open $rec.source
            } else {null}
        } |
        insert destination_exists {|rec|
            $rec.destination | path exists
        } |
        insert destination_content {|rec|
            if $rec.destination_exists {
                open $rec.destination
            } else {null}
        }

    )

    let no_source = ($vars | where not source_found)
    let vars = ($vars | where source_found)
    $no_source |
    each {|it|
        log error $'expected to find corresponding file at ($it.source | to nuon), but found nothing'
    }

    let content_mismatch = ($vars | where {|it| $it.source_found and $it.destination_exists and $it.source_content != $it.destination_content})
    let vars = ($vars | where {|it| (not $it.destination_exists) or ($it.destination_exists and $it.source_content == $it.destination_content)})
    $content_mismatch |
    each {|it|
        log error $"source content differs from already existing destination content!\n($it | reject source_found destination_exists | table)"
    }

    let any_errors = ($no_source | append $content_mismatch | is-not-empty)
    if (not $any_errors) or $continue {
        let paths_to_copy = (
            $vars |
            each {|it|
                if ($it.source_content == $it.destination_content) {
                    log info $'($it.name | to nuon) -> same content, skipping'
                    null
                } else {
                    $it.source
                }
            }
        )
        if ($paths_to_copy | is-not-empty) {
            sudo cp --verbose ...($paths_to_copy) /etc/profile.d/
        }
    }

    if $any_errors {
        return (error make {
            'msg': 'encountered errors',
        })
    }
}
