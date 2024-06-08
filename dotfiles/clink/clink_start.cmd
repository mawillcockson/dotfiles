if not defined FNM_AUTORUN_GUARD (
      set "FNM_AUTORUN_GUARD=AutorunGuard"
      FOR /f "tokens=*" %%z IN ('fnm env --use-on-cd --version-file-strategy=recursive --shell=cmd') DO CALL %%z
)
