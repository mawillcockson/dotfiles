# Local settings per-repository
# git config --local "user.name" "User Name"
# git config --local "user.email" "email@example.com"
# git config --local "user.signingKey" "fingerprint"

# Don't automatically delete commits, no matter what
git config --global "gc.auto" 0
git config --global "gc.pruneExpire" "never"
git config --global "gc.worktreePruneExpire" "never"
git config --global "gc.reflogExpire" "never"
git config --global "gc.reflogExpireUnreachable" "never"
git config --global "core.logAllRefUpdates" "always"
git config --global "maintenance.auto" "false"
git config --global "maintenance.strategy" "none"
git config --global "maintenance.gc.enabled" "false"
git config --global "receive.autogc" "false"

# Signing
git config --global "push.gpgSign" "if-asked"
git config --global "tag.gpgSign" "true"
git config --global "tag.forceSignAnnotated" "true"
git config --global "commit.gpgSign" "true"
# minTrustLevel defaults to merges requiring "minimal" or higher, and
# everything else requiring "undefined" or higher
git config --global "gpg.minTrustLevel" "ultimate"
# Forces side-branches to have a trusted key signing the tip commit
#git config --global "merge.verifySignatures" "true"

# General
git config --global "init.defaultBranch" "main"
git config --global "push.default" "simple"
git config --global "core.safecrlf" "true"
# Apparently, "input" still does some conversions, despite the docs saying that
# it won't: https://stackoverflow.com/a/21822812
git config --global "core.autocrlf" "false"
git config --global "core.abbrev" "no"
git config --global "clean.requireForce" "true"
# Disables repository urls starting with git://
# These aren't encrypted with TLS.
git config --global "protocol.git.allow" "never"
# Same thing for http, since that's different from https://
git config --global "protocol.http.allow" "never"
git config --global "status.branch" "true"
git config --global "user.useConfigOnly" "true"
git config --global "pull.ff" "only"

# this could speed up starsip's `git status`, but it didn't in the lightest of
# testing
#git config --local "core.fsmonitor" "true"
