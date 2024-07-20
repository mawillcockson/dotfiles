F11 & F12::
SetMouseDelay -1
SendEvent {Blind}{MButton down}
KeyWait F12
SendEvent {Blind}{MButton up}
KeyWait F11
return

F12 & F11::
SetMouseDelay -1
SendEvent {Blind}{MButton down}
KeyWait F11
SendEvent {Blind}{MButton up}
KeyWait F12
return

F11::F11
F12::F12

/* this adds a hotkey for Ctrl+Alt+x to quit the script (in case there's an
 * error in the script), but this combination is removed when the script is
 * compiled:
 * https://www.autohotkey.com/docs/misc/Ahk2ExeDirectives.htm#IgnoreKeep
 */
;@Ahk2Exe-IgnoreBegin
^!x::ExitApp
;@Ahk2Exe-IgnoreEnd
