def main [] {
    {
        'keetraytotp': {
            'url': 'https://api.github.com/repos/KeeTrayTOTP/KeeTrayTOTP/releases/latest',
            'data': {},
            'cached_at': (timestamp),
        },
        'readablepassphrase': {
            'url': 'https://api.github.com/repos/ligos/readablepassphrasegenerator/releases/latest'
            'data': {},
            'cached_at': (timestamp --subtract 1day),
        },
    } |
    to json --indent 2
}

def timestamp [--subtract: duration = 0sec] {
    ((date now) - $subtract) | format date '%s%.6f' | into float
}
