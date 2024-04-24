# notes

## Arch/Manjaro

`ln -s /usr/lib/libffi-3.2.1/include/ffi*.h /usr/include`

## Weird errors

Consistently reproducible `Fatal Python error: _Py_HashRandomization_Init: failed to get random numbers to initialize Python` when using `pip` to install `dulwich`.

[This StackOverflow answer](https://stackoverflow.com/a/64706392) and [this GitHub comment](https://github.com/appveyor/ci/issues/1995#issuecomment-546325062) both helped understand that I forgot to update the environment instead of overwriting it, in one spot.

## Custom fonts can be installed using

<https://github.com/MicksITBlogs/PowerShell/blob/master/InstallFonts.ps1>

## Windows GPG setup is missing some steps

Definitely need to formalize the startup process that includes a:

```powershell
del -Recurse -Force "$(gpgconf --list-dirs agent-ssh-socket)" -ErrorAction Continue
```

[docs on how to continue and stop on errors may be helpful](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_commonparameters?view=powershell-7.1)

Also, sometimes if `gpg-agent` and `wsl-ssh-pageant` appear to be running, but with the card inserted, a `git commit -S` produces:

```
gpg: signing failed: Not confirmed
gpg: signing failed: Not confirmed
error: gpg failed to sign the data
fatal: failed to write commit object
```

And the pinentry gui keeps popping up asking for the card to be inserted, and `gpg --card-status` shows:

```
gpg: OpenPGP card not available: General error
```

I've found `gpgconf --reload` usually does the trick to restart `scdaemon`, and the others. Then `gpg --card-status` shows it's inserted.

This usually happens if I load everything, then try to use the card, all before it's inserted.
