python -m pip install --user --upgrade pip setuptools wheel pipx
python -m pipx ensurepath
python -m pipx upgrade-all
python -m pipx reinstall-all
$pipx_apps = @(
    "black",`
    "build",`
    "commitizen",`
    "httpie",`
    "isort",`
    "mypy",`
    "poetry",`
    "py-spy",`
    "pyclip",`
    "pygount",`
    "pylint",`
    "pytest",`
    "tox",`
    "twine",`
    "yt-dlp",`
)
foreach ($i in $pipx_apps) {
    python -m pipx install "$i"
}
if ($pipx_apps.Contains("pytest")) {
    python -m pipx inject pytest pytest-cov
    python -m pipx inject pytest pytest-subtests
    if ($pipx_apps.Contains("mypy")) {
        python -m pipx inject mypy pytest
    }
    if ($pipx_apps.Contains("pylint")) {
        python -m pipx inject pylint pytest
}
