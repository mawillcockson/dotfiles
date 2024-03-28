# checks if the path is a file
# can only accept an argument or piped data, not both
export def "path is-file" [
    path?: string # path to check; if none given, treat piped input as a path
] {
    let piped = $in
    if not (($path == null) xor ($piped == null)) {
        return (error make {
            'msg': 'need exactly one of piped data or a positional argument',
        })
    }

    let value = if ($path == null) { $piped } else { $path }

    if not ($value | path exists) {
        return false
    }
    return ($value | path type | $in == 'file')
}

# checks if the path is a directory
# can only accept an argument or piped data, not both
export def "path is-dir" [
    path?: string # path to check; if none given, treat piped input as a path
] {
    let piped = $in
    if not (($path == null) xor ($piped == null)) {
        return (error make {
            'msg': 'need exactly one of piped data or a positional argument',
        })
    }

    let value = if ($path == null) { $piped } else { $path }

    if not ($value | path exists) {
        return false
    }
    return ($value | path type | $in == 'dir')
}
