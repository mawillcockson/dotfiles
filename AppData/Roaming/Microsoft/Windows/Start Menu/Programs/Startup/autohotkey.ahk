#.::
{
    Run(Format("wt --focus --window new new-tab -p Neovim nu `"{1}\{2}`"", EnvGet("UserProfile"), ".config\nushell\scripts\emoji-picker.nu"))
}
