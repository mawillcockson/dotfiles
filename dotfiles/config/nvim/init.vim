set autoindent
set smartindent
set ts=4
set sw=4
set expandtab
set number
set undofile
colorscheme desert

" Install vim-plug
if empty(glob('~/.vim/autoload/plug.vim'))
    silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
        \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.local/share/nvim/vim-plug-plugins')
if has('nvim')
    Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
else
    Plug 'Shougo/deoplete.nvim'
    Plug 'roxma/nvim-yarp'
    Plug 'roxma/vim-hug-neovim-rpc'
endif
let g:deoplete#enable_at_startup = 1

" General
Plug 'neomake/neomake'
Plug 'junegunn/fzf.vim'
Plug 'vim-airline/vim-airline'
Plug 'embear/vim-localvimrc'
" Python
Plug 'zchee/deoplete-jedi'
" Go
"Plug 'zchee/deoplete-go', {'do': 'make'} " Make sure this is actually working
                                          " as intended
" Rust
Plug 'rust-lang/rust.vim'
Plug 'sebastianmarkow/deoplete-rust'
call plug#end()

" From :h provider-python
let g:loaded_python_provider = 1

"function! MyOnBattery()
"    return readfile('/sys/class/power_supply/ACAD/online') == ['0']
"endfunction
"
"if MyOnBattery()
"    call neomake#configure#automake('w')
"else
"    call neomake#configure#automake('nw', 1000)
"endif

" For Plug 'embear/vim-localvimrc'
" Whitelist '.lvimrc' files in projects directories
let g:localvimrc_whitelist='/home/mw/projects/'

" For Plug 'neomake/neomake'
" Don't set this. Instead, use `pipenv run nvim` or `pipenv shell --fancy`
" let g:python3_host_prog = '/home/mw/.local/share/virtualenvs/mw-C00ZcD88/bin/python'
