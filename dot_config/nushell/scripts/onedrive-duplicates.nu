use std [log]

# NOTE::IMPROVEMENT this list should auto-update
# it can be moved to a .nuon file, and every startup, $env.ONEDRIVE etc are
# checked, and if present, add $env.COMPUTERNAME to the list
const computers = [
    'INSPIRON15-3521',
    'omen',
    'OMEN',
    'BatCave',
    'DENNIS',
]

### examples
# -INSPIRON15-3521.hidden_file
# -beginning_dash
# -beginning_dash-INSPIRON15-3521
# -beginning_dash-omen
# -beginning_dash-omen-2
# -omen-2.hidden_file
# -omen.hidden_file
# .hidden_file
# .hidden_file-INSPIRON15-3521.txt
# .hidden_file-omen-2.txt
# .hidden_file-omen.txt
# .hidden_file.txt
# .hidden_multi_ext.tar-INSPIRON15-3521.gz
# .hidden_multi_ext.tar-omen-2.gz
# .hidden_multi_ext.tar-omen.gz
# .hidden_multi_ext.tar.gz
# 1-LONG_N~3-INSPIRON15-3521.TXT
# 1-LONG_N~3-omen.TXT
# 2-LONG_N~3-omen.TXT
# LONG_N-1.TXT
# LONG_N~3.TXT
# bare_name
# bare_name-INSPIRON15-3521
# bare_name-omen
# bare_name-omen-2
# long_name1-INSPIRON15-3521.txt
# long_name1-omen-2.txt
# long_name1-omen.txt
# long_name1.txt
# long_name2-INSPIRON15-3521.txt
# long_name2-omen-2.txt
# long_name2-omen.txt
# long_name2.txt
# multi_extension.tar-INSPIRON15-3521.gz
# multi_extension.tar-omen-2.gz
# multi_extension.tar-omen.gz
# multi_extension.tar.gz
# regular_file-INSPIRON15-3521.txt
# regular_file-omen-2.txt
# regular_file-omen.txt
# regular_file.txt
# ~-INSPIRON15-3521.weird
# ~.weird

const default_start_dir = ('~/OneDrive' | path expand)

export def list [
    # directory to search under
    --start-dir?
] {
    let start_dir = (
        $env
        | get ONEDRIVE? OneDrive? ONEDRIVECONSUMER? OneDriveConsumer?
        | default $default_start_dir
    )

    (
        $computers
        | each {|name|
            glob --no-dir $'**/*-($name)*' |
            each {|file|
                let basename = ($file | path basename)
                mut maybe_original_basename = ($basename | str replace $'-($name)' '')
                mut maybe_original = ($file | path basename --replace $maybe_original_basename)
                if not ($maybe_original | path exists) {
                    $maybe_original_basename = ($basename | str replace --regex $'-($name)-\d+' '')
                    $maybe_original = ($file | path basename --replace $maybe_original_basename)
                }
                if not ($maybe_original | path exists) {
                    log error $"can't find original file for: ($file)"
                }
                {
                    'original': ($maybe_original),
                    'duplicate': ($file),
                    'name': ($name),
                }
            }
        }
        | flatten
        | sort-by 'original'
        # | group-by 'original'
        # | transpose
        # | rename 'original' 'duplicates'
        # | update 'duplicates' {|row| $row.duplicates | reject 'original'}
    )
}

export def main [] { list }
