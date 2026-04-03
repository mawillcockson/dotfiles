let
  # NOTE::BUG causes an infinite recursion
  #configDir = config.systemd.services.step-ca.restartTriggers |> builtins.head |> builtins.dirOf;
  configDir = "/etc/smallstep";
  # NOTE::DONE there's a note in systemd.exec(5) under LoadCredential
  # about using `systemd-path` with an invocation like `systemd-run --collect
  # --wait --pty -- systemd-path system-credential-store-encrypted` to get the specific path to the
  # credentials directory, but it didn't work for me
  # <https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html#LoadCredential=ID:PATH>
  # it looks like it IS just missing for me:
  #
  # debian 13 has `systemd-path --version` 257.9-1~deb13u1
  # nixos-unstable has version 259
  #
  # It would be cool if this value maybe were derived from invoking
  # `systemd-path system-credential-store-encrypted`, but that would be an
  # import-from-derivation, so instead it can be validated at runtime against
  # the output of that command.
  # This is done by `mw-pki-rootCA-make-password.service`
  CREDENTIALS_DIRECTORY = "/etc/credstore.encrypted";
in {
  inherit configDir CREDENTIALS_DIRECTORY;
}
