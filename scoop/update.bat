powershell.exe -ex remotesigned -command "scoop update *"
%HOMEDRIVE%%HOMEPATH%\scoop\apps\python\current\python.exe -m pip install --user --upgrade --no-warn-script-location pip setuptools wheel pipx
%HOMEDRIVE%%HOMEPATH%\scoop\apps\python\current\python.exe -m pip install --user --upgrade --no-warn-script-location pip setuptools wheel pipx
%HOMEDRIVE%%HOMEPATH%\scoop\apps\python\current\python.exe -m pipx reinstall-all
powershell.exe -ex remotesigned -command "scoop cleanup *"
winget upgrade --accept-package-agreements --accept-source-agreements --disable-interactivity --all --scope user
PAUSE
