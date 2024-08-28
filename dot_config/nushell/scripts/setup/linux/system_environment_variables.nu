use std [log]

export const variable_names = [
    'ALREADY_SOURCED_SYSTEM_PROFILE_D',
    'XDG_CONFIG_HOME',
]

export def main [
    # copy ones that can be copied
    --continue
    variable_names: list<string> = $variable_names,
] {
    let vars = (
        $variable_names |
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
            $it.source | path exists
        } |
        insert source_content {|rec|
            if $it.source_found {
                open $it.source
            } else {null}
        } |
        insert destination_exists {|rec|
            $it.destination | path exists
        } |
        insert destination_content {|rec|
            if $it.destination_exists {
                open $it.destination
            } else {null}
        }

    )

    let no_source = ($vars | where not source_found)
    let vars = ($vars | where source_found)
    $no_source |
    each {|it|
        log error $'expected to find corresponding file at ($it.source | to nuon), but found nothing'
    }

    let content_mismatch = ($vars | where source_found and destination_exists and source_content != destination_content)
    let vars = ($vars | filter {|it| (not $it.destination_exists) or ($it.destination_exists and $it.source_content == $it.destination_content)}
    $content_mismatch |
    each {|it|
        log error $"source content differs from already existing destination content!\n($it | reject source_found destination_exists | table)"
    }

    let any_errors = ($no_source | append $content_mismatch | is-not-empty)
    if (not $any_errors) or $continue {
        $vars |
        each {|it|
            if ($it.source_content == $it.destination_content) {
                log info $'($it.name | to nuon) -> same content, skipping'
                null
            } else {
                $it.source
            }
        } |
        sudo cp ...($in) /etc/profile.d/
    }

    if $any_errors {
        return (error make {
            'msg': 'encountered errors',
        })
    }
}
