" ----------------------------------------------------------------------------
" Use sane defaults

" Some system-wide vimrc (e.g. macOS) sets let skip_defaults_vim=1,
" which prevents `defaults.vim` from being sourced.
unlet! skip_defaults_vim
source $VIMRUNTIME/defaults.vim
" ----------------------------------------------------------------------------
" True Color support
if has('termguicolors')
  set termguicolors
endif
" ----------------------------------------------------------------------------
" Packages
if has('syntax') && has('eval')
  packadd! matchit
endif
" ----------------------------------------------------------------------------
" Backup files
set swapfile
let &directory = expand('~/.vimdata/swap//')

set backup
let &backupdir = expand('~/.vimdata/backup//')

set undofile
let &undodir = expand('~/.vimdata/undo/')

if !isdirectory(&undodir)   | call mkdir(&undodir,   "p") | endif
if !isdirectory(&backupdir) | call mkdir(&backupdir, "p") | endif
if !isdirectory(&directory) | call mkdir(&directory, "p") | endif
" ----------------------------------------------------------------------------
" Personal options
" ----------------------------------------------------------------------------
" Always show line numbers
set nu

" Use highlight search by default
set hlsearch

" Use light background
set bg=dark
" ----------------------------------------------------------------------------
