if (!(gcm scoop)) {
	iwr -useb "https://get.scoop.sh" | iex
	if ($? -ne 0) {
	    write-host "maybe try the following command?"
        write-host "Set-ExecutionPolicy RemoteSigned -Scope CurrentUser"
	    exit 1
	}
} else {
    write-host "updating all scoop apps"
	scoop update *
}

scoop install aria2 git
write-host "disabling scoop's warning about aria2"
# https://github.com/ScoopInstaller/scoop#multi-connection-downloads-with-aria2
scoop config aria2-warning-enabled false
write-host "installing apps from 'main'"
scoop install `
    clink `
    starship `
    python `
    ripgrep `
    fd `
    jq # needed for later in script
write-host "adding scoop 'extras' bucket"
scoop bucket add extras
# may not be necessary anymore:
# https://github.com/starship/starship/pull/4031/files#diff-87db21a973eed4fef5f32b267aa60fcee5cbdf03c67fafdc2a9b553bb0b15f34R69
# Needed for ripgrep
write-host "install dlls for ripgrep"
scoop install "extras/vcredist2022"
scoop uninstall vcredist2022
write-host "installing apps from 'extras'"
scoop install `
    keepass `
    keepass-plugin-keetraytotp `
    keepass-plugin-readable-passphrase `
    neovim `
    neovide `
    gnupg `
    wsl-ssh-pageant
#     fvim `
#     neovide `
#     notepadplusplus `
#     vlc
write-host "adding scoop 'nerd-fonts' bucket"
scoop bucket add nerd-fonts
write-host "install DejaVuSans font"
scoop install DejaVuSansMono-NF

$content = {
    if (Test-Path Env:XDG_CONFIG_HOME) {
        . "$Env:XDG_CONFIG_HOME\powershell\profile.ps1"
    }
}
if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force -Value $content
} else {
    write-host "not overwriting existing $PROFILE"
}

if (Test-Path Env:OneDrive) {
    write-host "configuring clink for autorun"
    clink autorun install -- --profile "$Env:OneDrive\Documents\configs\clink"
} else {
    write-host "OneDrive not signed in? Can't install clink for cmd"
}

# git config
write-host "configuring git"
# The following config calls could be placed in the gitconfig.ps1, but are only
# necessary on Windows when things are installed through scoop
git config --global core.sshCommand ((gcm ssh).Source -replace '\\','/')
git config --global gpg.program ((gcm gpg).Source -replace '\\','/')
git config --global gpg.openpgp.program ((gcm gpg).Source -replace '\\','/')
# I'm unlikely to ever use it, but git supports signing using SSH keys, in
# addition to the GnuPG keys I usually use
git config --global gpg.ssh.program ((gcm ssh-keygen).Source -replace '\\','/')
if (Test-Path Env:OneDrive) {
    write-host "configuring additional git settings"
    & "$Env:OneDrive\Documents\configs\gitconfig.ps1"
} else {
    write-host "OneDrive not signed in? Can't run gitconfig.ps1"
}

# neovim
if (Test-Path Env:OneDrive) {
    write-host "setting XDG_CONFIG_HOME environment variable for neovim and others"
    Set-Item -Path Env:XDG_CONFIG_HOME -Value "$Env:OneDrive\Documents\configs"
    [Environment]::SetEnvironmentVariable('XDG_CONFIG_HOME', $env:XDG_CONFIG_HOME, 'User')
} else {
    write-host "OneDrive not signed in? Can't set (neovim) configuration directory"
}

# ssh and gnupg
# Based on:
# https://github.com/mawillcockson/dotfiles/blob/798d6ea7267a73502ae8242fae1aa4b0d0618af5/INSTALL_windows.md
# This is the default name of the named pipe used Windows' builtin ssh, set explicitly here. More info:
# https://github.com/PowerShell/Win32-OpenSSH/issues/1136#issuecomment-500549297
write-host "setting SSH_AUTH_SOCK environment variable for gpg and ssh"
Set-Item -Path Env:SSH_AUTH_SOCK -Value "\\.\pipe\openssh-ssh-agent"
[Environment]::SetEnvironmentVariable('SSH_AUTH_SOCK', $env:SSH_AUTH_SOCK, 'User')
write-host "enabling putty support in gpg-agent"
# Found with:
# https://www.gnupg.org/documentation/manuals/gnupg/Listing-options.html#Listing-options
# gpgconf --list-options gpg-agent
echo "enable-putty-support:0:1" | gpgconf --change-options gpg-agent
write-host "retrieving my gpg keys from GitHub"
# Have to run through cmd because of the PowerShell alias for curl
# I think I'm doing this because PowerShell pipes write data in a format gpg
# doesn't like, like UTF-16LE?
# cmd /c "curl -fsS https://github.com/mawillcockson.gpg | `"$((gcm gpg).Source)`" --import"
# Kaspersky can make that fail, though, trying to proxy the TLS connection, so
# this could work instead:
gpg --keyserver "keyserver.ubuntu.com" `
    --receive-key "EDCA9AF7D273FA643F1CE76EA5A7E106D69D1115"
# Ideally, this command could do the fetching of the url set on the OpenPGP
# card, and import the returned data, instead of the above command, but it
# returns "Command 'fetch' failed: Not implemented"
#gpg-card fetch

write-host "installing customized ComicCode font with PowerShell"
# https://web.archive.org/web/20220620091307/https://www.alkanesolutions.co.uk/2021/12/06/installing-fonts-with-powershell/
if (-not (Test-Path Env:OneDrive)) {
    write-host "OneDrive not signed in? Can't install Comic Code NF from OneDrive"
} else {
    $comiccode_dir = "$Env:OneDrive\Documents\Fonts\Comic Code\careful"
    # Alternate technique here:
    # https://github.com/matthewjberger/scoop-nerd-fonts/blob/3917d7a81a5559eae34c4f97918e0bc1d78c7810/bucket/DejaVuSansMono-NF-Mono.json#L13-L29
    gci $comiccode_dir | ForEach-Object {$_.Name} | `
        ForEach-Object {
            (New-Object -ComObject Shell.Application).Namespace(0x14).CopyHere("$comiccode_dir\$_",0x14);
        }
}

& "$Env:OneDrive\Documents\configs\scoop_windows_terminal.ps1"

# Install nvim plugins
if (Test-Path Env:OneDrive) {
    # DONE: update for lazy.nvim
    write-host "Installing Neovim plugins"
    # from end of:
    # https://github.com/wbthomason/packer.nvim#bootstrapping
    nvim `
        --headless `
        -u NONE `
        -i NONE `
        "+lua vim.g.lazy_install_plugins = true" `
        -S "$Env:OneDrive\Documents\configs\nvim\lua\bootstrap-plugins.lua" `
        "+q"  # quit after everything's done
    # lazy.nvim suggests: $ nvim --headless "+Lazy! sync" +qa
    # +Lazy! will wait until it's finished, instead of running it asynchronously
    # opts = {wait = true, show = true, concurrency = nproc,}

    # If this gets stuck, the plugins.lua probably didn't appropriately call
    # :quitall
    # Thankfully, Neovim starts a remote server session every time it starts.
    # On Windows, as of 2022-October, these are named pipes like
    # \\.\pipe\nvim.xxxx.x
    # The following command will connect neovim-qt to the first one:
    # nvim-qt --server "\\.\pipe\$((gci \\.\pipe\ | Where-Object -Property Name -Like "nvim*" | Select-Object -First 1).Name)"
} else {
    write-host "OneDrive not signed in? Can't install Neovim plugins"
}

# don't want to automate
write-host "set my gpg keys as ultimate trust with: gpg --edit-key matthew"
