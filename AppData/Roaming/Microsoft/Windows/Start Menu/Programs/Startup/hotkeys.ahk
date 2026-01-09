#.::
{
    Run(Format("wt --focus --window new new-tab -p Neovim --suppressApplicationTitle --title emoji-picker nu `"{1}\{2}`"", EnvGet("UserProfile"), ".config\nushell\scripts\emoji-picker.nu"))
    WinWait("emoji-picker", unset, 2)
    WinActivate
}
#`::Run("alacritty")
