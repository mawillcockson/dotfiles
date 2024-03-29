xontrib load coreutils
$STARSHIP_CONFIG = p"$XDG_CONFIG_HOME/starship/starship.toml"
# allows `imp.json.loads("[]")` instead of having to ^C and `import json`
# https://github.com/anki-code/xonsh-cheatsheet/blob/9be52b17557afd96ebdfd52a71c5fe4366746ca9/README.md?plain=1#L1353-L1366
imp = type('ImpCl', (object,), {'__getattr__':lambda self, name: __import__(name) })()
$VI_MODE = True
$XONSH_HISTORY_SIZE = '50gb'
$XONSH_HISTORY_BACKEND = 'json'
$CASE_SENSITIVE_COMPLETIONS = False
$UPDATE_COMPLETIONS_ON_KEYPRESS = False
# pressing <Enter> always runs the currently suggested command
$COMPLETIONS_CONFIRM = False
$ENABLE_ASYNC_PROMPT = True
# When ENABLE_ASYNC_PROMPT is True, it may call the redraw frequently. This is
# to group such calls into one that happens within that timeframe. The number
# is set in seconds.
# This sets the minimum amount of time after a previous draw that a new prompt
# should be drawn, in case <Enter> is being mashed. Does not cause the prompt
# to update live.
$ASYNC_INVALIDATE_INTERVAL = 0.05

# NOTE::NOT_IMPLEMENTED atuin supports neither xonsh nor windows
# if imp.shutil.which("atuin"):
#     execx($(atuin init xonsh))

from pathlib import Path as P

# NOTE::BUG
# should be as easy as:
# if imp.shutil.which("starship"):
#     execx($(starship init xonsh))
# but raw strings aren't used so \ inside '' confuses xonsh
import uuid


def starship_prompt():
    last_cmd = __xonsh__.history[-1] if __xonsh__.history else None
    status = last_cmd.rtn if last_cmd else 0
    # I believe this is equivalent to xonsh.jobs.get_next_job_number() for our purposes,
    # but we can't use that function because of https://gitter.im/xonsh/xonsh?at=60e8832d82dd9050f5e0c96a
    jobs = sum(1 for job in __xonsh__.all_jobs.values() if job['obj'] and job['obj'].poll() is None)
    duration = round((last_cmd.ts[1] - last_cmd.ts[0]) * 1000) if last_cmd else 0
    # The `| cat` is a workaround for https://github.com/xonsh/xonsh/issues/3786. See https://github.com/starship/starship/pull/2807#discussion_r667316323.
    return $(r'C:\Users\mawil\scoop\shims\starship.exe' prompt --status=@(status) --jobs=@(jobs) --cmd-duration=@(duration))

def starship_rprompt():
    last_cmd = __xonsh__.history[-1] if __xonsh__.history else None
    status = last_cmd.rtn if last_cmd else 0
    # I believe this is equivalent to xonsh.jobs.get_next_job_number() for our purposes,
    # but we can't use that function because of https://gitter.im/xonsh/xonsh?at=60e8832d82dd9050f5e0c96a
    jobs = sum(1 for job in __xonsh__.all_jobs.values() if job['obj'] and job['obj'].poll() is None)
    duration = round((last_cmd.ts[1] - last_cmd.ts[0]) * 1000) if last_cmd else 0
    # The `| cat` is a workaround for https://github.com/xonsh/xonsh/issues/3786. See https://github.com/starship/starship/pull/2807#discussion_r667316323.
    return $(r'C:\Users\mawil\scoop\shims\starship.exe' prompt --status=@(status) --jobs=@(jobs) --cmd-duration=@(duration) --right)


$PROMPT = starship_prompt
$RIGHT_PROMPT = starship_rprompt
$STARSHIP_SHELL = "xonsh"
$STARSHIP_SESSION_KEY = uuid.uuid4().hex
