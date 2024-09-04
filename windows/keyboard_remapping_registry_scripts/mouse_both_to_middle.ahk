RButton::
SetMouseDelay -1
if (not GetKeyState("LButton")) {
    SendEvent {Blind}{RButton down}
    KeyWait RButton
    SendEvent {Blind}{RButton up}
    return
}
KeyWait RButton
KeyWait LButton
SendEvent {Blind}{MButton}
return

/*
LButton::
SetMouseDelay -1
if (not GetKeyState("RButton")) {
    SendEvent {Blind}{LButton down}
    KeyWait LButton
    SendEvent {Blind}{LButton up}
    return
}
KeyWait RButton
KeyWait LButton
SendEvent {Blind}{MButton}
return
*/

/* this adds a hotkey for Ctrl+Alt+x to quit the script (in case there's an
 * error in the script), but this combination is removed when the script is
 * compiled:
 * https://www.autohotkey.com/docs/misc/Ahk2ExeDirectives.htm#IgnoreKeep
 */
;@Ahk2Exe-IgnoreBegin
^!x::ExitApp
;@Ahk2Exe-IgnoreEnd
