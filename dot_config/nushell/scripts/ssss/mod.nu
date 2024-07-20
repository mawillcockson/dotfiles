# use sops and age to encrypt a secret with an arbitrary number of age keys,
# and an arbitrary threshold for the required number of keys needed to decrypt
# the secret

# NOTE::DIRECTION I'd love to implement this myself, in a manner similar to
# https://github.com/paritytech/banana_split, first as a cli tool, then as a
# standalone html page. I'd love for the keys to be encoded in such a way that
# I can use the bip39 word list and fuzzy matching with something like
# RapidFuzz to help with typos, and make it much easier to re-enter the
# distributed keys. I'd also love to envode more info into the key, like a MAC
# and signature. That way, the issue of the resultant key being changed by a
# maliciously-modified input key is not applicable.
#
# I'd love for the only thing each person has to type in is a number of bip39
# words, in the order given to them, without having to remember that "this is
# the file that needs to be decrypted", "this is your key", etc.

# required tools:
# - sops: does SSSS part
# - age: does the encryption and key generation part
use std [log]

const ssss_dir = $'($nu.default-config-dir)/scripts/ssss'
const wordlist_file = $'($ssss_dir)/english-bip39-wordlist.txt'
const wordlist_url = 'https://github.com/bitcoin/bips/blob/master/bip-0039/english.txt'

export def main [] {
    load-env {
        'NU_LOG_LEVEL': 'info',
        'NU_LOG_FORMAT': '%ANSI_START%[%LEVEL%] %MSG%%ANSI_STOP%',
    }

    let tmpdir = (mktemp -d)
    log info $'using temporary directory -> ($tmpdir)'
    let starting_dir = $env.PWD
    cd $tmpdir

    let options = (get-input)
    let keys = (generate-keys $options.num_keys)
    let unencrypted_file = ($tmpdir | path join 'unencrypted.yaml')
    $options | select description decryption_instructions secret | to yaml | save -f $unencrypted_file
    let conf = {
        'creation_rules': [
            {
                'path_regex': '\.yaml$',
                'encrypted_regex': '^secret$',
                'shamir_threshold': ($options.threshold),
                'mac_only_encrypted': true,
                'key_groups': ($keys | each {|it| {
                    'age': [$it.recipient],
                }}),
            }
        ],
    }
    log debug ($conf | to yaml)
    let conf_file = ($tmpdir | path join '.sops.yaml')
    log info $'saving temporary sops config file to: ($conf_file)'
    $conf | to yaml | save -f $conf_file
    # NOTE::DEBUG
    #$conf | to yaml | print
    #return false

    log info 'the following are the age keys that were encrypted with a password each, that should be distributed:'
    let keys_json = ($keys | select recipient encrypted | to json)
    log info $keys_json
    let out_file = ($starting_dir | path join 'encrypted.sops.yaml')
    let args = [
        --encrypt,
        --input-type, yaml,
        --output-type, yaml,
        --output, ($out_file),
        --config, ($conf_file),
        ($unencrypted_file),
    ]
    log debug ($args | to nuon)
    
    log info $'running sops to generate ($out_file)'
    with-env {
        'SOPS_AGE_KEY': ($keys | get identity | str join "\n"),
    } {
        run-external 'sops' ...($args)
    }
    log info 'sops finished'
    log info 'finished'

    cd $starting_dir
    log debug $'removing $tmpdir -> ($tmpdir)'
    rm -rf $tmpdir
    return $keys_json
}

def "generate-keys" [number: int] {
    log info $'generating ($number) private keys'
    1..($number) | each {|it|
        let identity = (^age-keygen)
        let recipient = ($identity | ^age-keygen -y)
        let encrypted_identity = ($identity | ^age --encrypt --passphrase --armor)
        log debug $"key #($it):\n($encrypted_identity)\n"
        {
            'identity': ($identity),
            'recipient': ($recipient),
            'encrypted': ($encrypted_identity),
        }
    }
}

def "get-input" [] {
    # arbitrary numbers
    let $num_keys = (3..10 | input list 'number of keys> ')
    log info $'number of keys -> ($num_keys)'
    let $threshold = (2..10 | input list 'threshold> ')
    while ($threshold > $num_keys) {
        log warning $"the threshold \(($threshold)\) must be less than or equal to the number of keys \(($num_keys)\)"
        let $threshold = (1..10 | input list 'threshold> ')
    }
    log info $'threshold -> ($threshold)'
    let sops_version = (run-external --redirect-stdout 'sops' ...[--disable-version-check, --version] | str trim)

    return {
        'num_keys': ($num_keys),
        'threshold': ($threshold),
        'description': (input 'description> '),
        'decryption_instructions': $'This was encrypted with ($sops_version) [https://github.com/getsops/sops/releases]

To decrypt, first put the encrypted contents of each key file into a json array of objects with the key "encrypted":

```json
[
    {"encrypted": "---....---"},
    {"encrypted": "---....---"}
]
```

order does not matter. Then:

```nu
$json_output | from json | ssss decrypt encrypted.sops.yaml
```',
        'secret': (input 'secret> '),
    }
}

export def decrypt [file: path] {
    let source = $in
    try {hide-env SOPS_AGE_KEY_FILE}
    let threshold = (open --raw $file | from yaml | get sops.shamir_threshold)
    log debug $'only decrypting ($threshold) keys'
    let age_keys = ($source | first $threshold | get encrypted | each {|it| $it | ^age --decrypt | str trim})
    with-env {
        'SOPS_AGE_KEY': ($age_keys | str join "\n"),
    } {
        ^sops --decrypt --extract '["secret"]' $file
    }
}

export def "wordlist" [] {
    if not ($wordlist_file | path exists) {
        http get $wordlist_url | save $wordlist_file
    }

    open $wordlist_file
}
