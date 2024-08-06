nvim --clean --headless '+lua vim.g.lazy_install_plugins = true' -l ~/.config/nvim/lua/bootstrap-plugins.lua
nvim --headless '+DoLspConfig' '+TSUpdateSync' '+MasonUpdate' '+q'
