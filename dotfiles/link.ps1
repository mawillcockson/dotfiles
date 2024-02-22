$ErrorActionPreference = "Stop"
$configs = "C:\Users\mawil\OneDrive\Documents\configs"
$dotfiles = "C:\Users\mawil\projects\dotfiles\dotfiles\"
foreach ($folder in @('starship', 'nvim')) {
    if (((get-item $configs\$folder).LinkType) -ne $null) {continue}
    remove-item -recurse $configs\$folder-old -erroraction continue
    move-item $configs\$folder $configs\$folder-old
    new-item -Name $folder -Path $configs -Type Junction -Value $dotfiles\$folder
    remove-item -recurse $configs\$folder-old -erroraction continue
}
