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
