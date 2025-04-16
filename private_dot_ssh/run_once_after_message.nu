use consts.nu [platform]

def main [] {
    match $platform {
        'windows' => {print -e r##'
These instructions need to be followed:

https://stackoverflow.com/a/58275268/

This can be automated with tips from this:

https://stackoverflow.com/q/31721221/
'##},
        _ => { 'nothing needs to be done' }
    }
}
