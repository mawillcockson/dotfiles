#.::
{
    Run(Format("wt --focus --window new new-tab -p Neovim --suppressApplicationTitle --title emoji-picker nu `"{1}\{2}`"", EnvGet("UserProfile"), ".config\nushell\scripts\emoji-picker.nu"))
    Sleep 500
    WinActivate "emoji-picker"
}
