export def "date my-format" []: nothing -> string {
    date now |
    format date '%Y-%m-%dT%H%M%z'
}

export def main [
    # whether to attempt to copy the output to the clipboard
    --no-clipboard,
]: nothing -> string {
    let result = (date my-format)
    if (not $no_clipboard) {
        try {
            use clipboard.nu
            $result | clipboard clip
        }
    }
    return $result
}
