if not defined FNM_AUTORUN_GUARD (
    where fnm >nul 2>nul
    if NOT ERRORLEVEL 1 (
          set "FNM_AUTORUN_GUARD=AutorunGuard"
          FOR /f "tokens=*" %%z IN ('fnm env --use-on-cd --version-file-strategy=recursive --shell=cmd') DO CALL %%z
    ) else set "ERRORLEVEL=0"
)
