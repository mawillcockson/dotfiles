use consts.nu [version_info]

export def "nu-version" [
    comparison_operator: string,
    other_version: record<major: int, minor: int, patch: int>,
] {
    if ($other_version | get major? minor? patch? | compact | length) != 3 {
        return (error make {
            msg: 'other version needs to be a record of 3 integers: major, minor, patch',
            label: {
                text: 'expected a record<major: int, minor: int, patch: int>',
                span: (metadata $other_version).span,
            },
        })
    }

    let major = ($other_version | get major)
    let minor = ($other_version | get minor)
    let patch = ($other_version | get patch)

    let cur_major = ($version_info.major | into int --radix 10)
    let cur_minor = ($version_info.minor | into int --radix 10)
    let cur_patch = ($version_info.patch | into int --radix 10)

    match ($comparison_operator) {
        '>' | 'gt' | 'greater-than' | 'greaterThan' | 'is-greater-than' | 'isGreaterThan' => {
            return (($major > $cur_major) and ($minor > $cur_minor) and ($patch > $cur_patch))
        },
        '>=' | 'ge' | 'greater-than-or-equal-to' | 'greaterThanOrEqual' | 'is-greater-than-or-equal-to' | 'isGreaterThanOrEqual' => {
            return (($major >= $cur_major) and ($minor >= $cur_minor) and ($patch >= $cur_patch))
        },
        '<' | 'lt' | 'less-than' | 'lessThan' | 'is-less-than' | 'isLessThan' => {
            return (($major < $cur_major) and ($minor < $cur_minor) and ($patch < $cur_patch))
        },
        '<=' | 'le' | 'less-than-or-equal-to' | 'lessThanOrEqual' | 'is-less-than-or-equal-to' | 'isLessThanOrEqual' => {
            return (($major <= $cur_major) and ($minor <= $cur_minor) and ($patch <= $cur_patch))
        },
        '==' | 'eq' | 'equal-to' | 'equalTo' | 'is-equal-to' | 'isEqualTo' => {
            return (($major == $cur_major) and ($minor == $cur_minor) and ($patch == $cur_patch))
        },
        '!=' | 'ne' | 'not-equal-to' | 'notEqualTo' | 'is-not-equal-to' | 'isNotEqualTo' => {
            return (($major != $cur_major) and ($minor != $cur_minor) and ($patch != $cur_patch))
        },
        _ => {
            return (error make {
                msg: $'expected operator to be one of [>, gt, >=, ge, <, lt, <=, le, ==, eq, !=, ne], but got ($comparison_operator)',
                label: {
                    text: 'unknown comparison operator',
                    span: (metadata $comparison_operator).span,
                },
            })
        },
    }
}
