# Tasks for changes that need to be made in general

- codify temporary ncspot login-flow
- Add idempotence to existing nu setup module
- find a way to get periodic notifications on which software projects have
released a new version, primarily on GitHub
- `package install` doesn't give a great error message when trying to `do
$install 'package'` and the `'package'` cites a package manager that isn't
implemented for the current platform
- add more logging to package installation process
- add more logging to setup module
- make default `main` function in each setup `mod.nu` allow choosing of which submodules to run
- I get desktop notifications about apt package updates, but not eget or asdf ones
  - build a script (or Janet program) that checks for updates to the packages I use (<https://repology.org> might be useful)
- ~~I want to write a shell script that uses `curl` and `jq` to download the plugins,~~ ☑️ and also a janet script that's compiled
- `package install` should first try to find a package manager that's already
installed, and if there's not one installed, it should run the installation for
it
- add ability to test `use setup; setup` in qemu, like how nix does some tests
  - testing on windows would be super cool
    - maybe GitHub Actions?
    - command I can run on a machine with 4GB would be the coolest
  - maybe just the fonts could be dual encrypted with a GitHub or other token / secret
- allow alacritty to run via nixpkgs
- gpg has more commands that let trust and such be configured
  - the entire `gpg_setup.sh` might be able to be automated now?
- configure kde settings, like Win+` keyboard shortcut
- gpg -> ssh doesn't seem to be set up correctly?
- make sure ble.sh or bash-preexec are installed, so atuin works in those environments
  - maybe disable up-arrow in bash, but still have Ctrl-R work?
- I have chezmoi configured to _ask_ where `$XDG_CONFIG_HOME` and `$XDG_DATA_HOME` should point to, but I don't think the response is recorded anywhere other than in the chezmoi prompts database, and certainly isn't used anywhere that I can tell
  - None of the chezmoi externals settings respect this, currently
