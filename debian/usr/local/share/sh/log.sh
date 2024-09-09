log() {
    case "$#" in
        1)
            LOG_LEVEL="info"
            MSG="${1:?"message cannot be empty"}"
            ;;
        2)
            LOG_LEVEL="${1:?"if a log level is given, it cannot be empty"}"
            MSG="${2:?"message cannot be empty"}"
            ;;
        *)
            printf 'wrong number of arguments (%s): log [LEVEL] MSG\n' "$#"
            return 1
            ;;
    esac
    LOG_PREFIX="${LOG_PREFIX-"--${LOG_LEVEL}--"}"
    printf '%s%s%s\n' "${LOG_PREFIX-}" "${LOG_PREFIX:+" "}" "${MSG}"
    return 0
}
export log

info() {
    log INFO "$*"
}
export info

warn() {
    log WARN "$*"
}
export warn

error() {
    log ERROR "$*"
    return 1
}
export error
