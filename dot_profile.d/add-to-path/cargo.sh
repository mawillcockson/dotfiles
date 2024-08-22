CARGO_HOME="${HOME:?"\$HOME is not set!"}/.cargo"
export CARGO_HOME
printf '%s' "${CARGO_HOME}/bin"
