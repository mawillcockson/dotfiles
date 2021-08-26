# notes

## Arch/Manjaro

`ln -s /usr/lib/libffi-3.2.1/include/ffi*.h /usr/include`

## Weird errors

Consistently reproducible `Fatal Python error: _Py_HashRandomization_Init: failed to get random numbers to initialize Python` when using `pip` to install `dulwich`.

[This StackOverflow answer](https://stackoverflow.com/a/64706392) and [this GitHub comment](https://github.com/appveyor/ci/issues/1995#issuecomment-546325062) both helped understand that I forgot to update the environment instead of overwriting it, in one spot.
