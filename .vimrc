" Global settings adapted from $VIMRUNTIME/defaults.vim.

" Use Vim mode, not Vi mode.
set nocompatible

" Allow backspacing over everything in insert mode.
set backspace=indent,eol,start

set history=200		" keep 200 lines of command line history
set ruler		" show the cursor position all the time
set showcmd		" display incomplete commands
set wildmenu		" display completion matches in a status line

set ttimeout		" time out for key codes
set ttimeoutlen=100	" wait up to 100ms after Esc for special key

" Show @@@ in the last line if it is truncated.
set display=truncate

" Show a few lines of context around the cursor.  Note that this makes the
" text scroll if you mouse-click near the start or end of the window.
set scrolloff=5

" Do incremental searching when it's possible to timeout.
if has('reltime')
  set incsearch
endif

" Do not recognize octal numbers for Ctrl-A and Ctrl-X, most users find it
" confusing.
set nrformats-=octal

" Don't use Q for Ex mode, use it for formatting.  Except for Select mode.
" Revert with ":unmap Q".
map Q gq
sunmap Q

" CTRL-U in insert mode deletes a lot.  Use CTRL-G u to first break undo,
" so that you can undo CTRL-U after inserting a line break.
" Revert with ":iunmap <C-U>".
inoremap <C-U> <C-G>u<C-U>

" In many terminal emulators the mouse works just fine.  By enabling it you
" can position the cursor, Visually select and scroll with the mouse.
" Only xterm can grab the mouse events when using the shift key, for other
" terminals use ":", select text and press Esc.
if has('mouse')
  if &term =~ 'xterm'
    set mouse=a
  else
    set mouse=nvi
  endif
endif

" Enable True Color support.
" True Color uses 24 bits to represent colors.
" 256 Color uses 8 bits (hence 256) to represent colors.
if has('termguicolors')
  set termguicolors
endif

" Enable file type detection.
" Use the default filetype settings, so that mail gets 'tw' set to 72,
" 'cindent' is on in C files, etc.
" Also load indent files, to automatically do language-dependent indenting.
" Revert with ":filetype off".
filetype plugin indent on

" Put these in an autocmd group, so that you can revert them with:
" ":autocmd! vimStartup"
augroup vimStartup
  autocmd!

  " When editing a file, always jump to the last known cursor position.
  " Don't do it when the position is invalid, when inside an event handler
  " (happens when dropping a file on gvim), for a commit or rebase message
  " (likely a different one than last time), and when using xxd(1) to filter
  " and edit binary files (it transforms input files back and forth, causing
  " them to have dual nature, so to speak)
  autocmd BufReadPost *
  \ let line = line("'\"")
  \ | if line >= 1 && line <= line("$") && &filetype !~# 'commit'
  \      && index(['xxd', 'gitrebase'], &filetype) == -1
  \ |   execute "normal! g`\""
  \ | endif
augroup END

" Quite a few people accidentally type "q:" instead of ":q" and get confused
" by the command line window.  Give a hint about how to get out.
" If you don't like this you can put this in your vimrc:
" ":autocmd! vimHints"
augroup vimHints
  au!
  autocmd CmdwinEnter *
    \ echohl Todo |
    \ echo gettext('You discovered the command-line window! You can close it with ":q".') |
    \ echohl None
augroup END

" Revert with ":syntax off".
syntax on

" I like highlighting strings inside C comments.
" Revert with ":unlet c_comment_strings".
" let c_comment_strings=1

" Convenient command to see the difference between the current buffer and the
" file it was loaded from, thus the changes you made.
" Only define it when not defined already.
" Revert with: ":delcommand DiffOrig".
if !exists(":DiffOrig")
  command DiffOrig vert new | set bt=nofile | r ++edit # | 0d_ | diffthis
		  \ | wincmd p | diffthis
endif

if has('langmap') && exists('+langremap')
  " Prevent that the langmap option applies to characters that result from a
  " mapping. If set (default), this may break plugins (but it's backward
  " compatible).
  set nolangremap
endif
" ----------------------------------------------------------------------------
" Add some packages to runtimepath, but defer loading.

" The ! means the package won't be loaded right away but when plugins are
" loaded during initialization.

" The matchit plugin makes the % command work better, but it is not backwards
" compatible.
if has('syntax') && has('eval')
  packadd! matchit
endif
" ----------------------------------------------------------------------------
" Backup files settings.

" Put al three types of backup files in one directory ~/.vimdata.
set swapfile
let &directory = expand('~/.vimdata/swap/')

set backup
let &backupdir = expand('~/.vimdata/backup/')

set undofile
let &undodir = expand('~/.vimdata/undo/')

if !isdirectory(&undodir) | call mkdir(&undodir, "p") | endif
if !isdirectory(&backupdir) | call mkdir(&backupdir, "p") | endif
if !isdirectory(&directory) | call mkdir(&directory, "p") | endif
" ----------------------------------------------------------------------------
" Personal settings from now on.
" ----------------------------------------------------------------------------
" Global options.

" Display row number by default.
set nu

" Use highlight search by default.
set hlsearch

" Use light background.
set bg=dark
" ----------------------------------------------------------------------------
" Global mappings.

" Set no highlight until next search.
nnoremap <silent> <C-L> :noh<CR>

" Turn on spell check for the local buffer.
nnoremap <F1> :setlocal spell spelllang=en_us<CR>

" Add Claude Code as co-author
nnoremap <leader>cc :call append(line('.'), ['', 'Co-Authored-By: Claude Code <noreply@anthropic.com>'])<CR>

" Use NvChad style window navigation
nnoremap <C-h> <C-w><C-h>
nnoremap <C-j> <C-w><C-j>
nnoremap <C-k> <C-w><C-k>
nnoremap <C-l> <C-w><C-l>
" ----------------------------------------------------------------------------
" Global commands.

" Show man page in a new buffer and set it as the only window.
command! -nargs=+ KMan call s:OpenManPage(<q-args>)

function! s:OpenManPage(args)
  " Load the man.vim plugin if hasn't.
  if !exists(':Man')
    runtime ftplugin/man.vim
  endif

  execute ':Man ' . a:args
  only
endfunction
" ----------------------------------------------------------------------------
" Autocommands per filetype.

" Set extension name for Bash scripts.
augroup ShellScriptFileType
  autocmd!
  autocmd BufRead,BufNewFile *.bashrc let g:is_bash = 1 | set filetype=sh
augroup END

" For Markdown files, show rendered HTML in browser.
function! s:SetupMarkdownMappings()
  nnoremap <buffer> <silent> <leader>ll :call <SID>RenderMarkdownFile()<CR>
endfunction

function! s:RenderMarkdownFile()
  let l:curr_file = expand('%:p')

  call system('toolkit-show-md ' . shellescape(l:curr_file) . ' >/dev/null 2>&1')
endfunction

augroup MarkdownShowFile
  autocmd!
  autocmd FileType markdown call s:SetupMarkdownMappings()
augroup END
" ----------------------------------------------------------------------------
" Package settings from now on.
" ----------------------------------------------------------------------------
" Packages are manually mananged inside the ~/.vim/pack/*/start/* folders.
" Currently there are no opt files, only start.

" ~/.vim/pack
"   ├─ gruvbox/start/gruvbox
"   ├─ nerdtree/start/nerdtree
"   ├─ vim-airline/start/vim-airline
"   └─ vim-airline-themes/start/vim-airline-themes
" ----------------------------------------------------------------------------
" Nerdtree setting.

" Automatically open nerdtree.
" autocmd vimenter * NERDTree

" Close vim when the only window open is nerdtree.
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif

" Toggle nerdtree.
nmap <C-n> :NERDTreeToggle<CR>
" ----------------------------------------------------------------------------
" gruvbox color scheme setting.

let g:gruvbox_bold = 0
let g:gruvbox_italic = 0

autocmd vimenter * ++nested colorscheme gruvbox
" ----------------------------------------------------------------------------
" Vim-airline setting.

" Show buffer info at the top as a tab line.
let g:airline#extensions#tabline#enabled = 1

" Airline theme.
let g:airline_theme='base16_gruvbox_dark_medium'

if !exists('g:airline_symbols')
  let g:airline_symbols = {}
endif

let g:airline_left_sep = '▶'
let g:airline_right_sep = '◀'
let g:airline_symbols.colnr = ' ㏇:'
let g:airline_symbols.crypt = '🔒'
let g:airline_symbols.linenr = ' ␤:'
let g:airline_symbols.maxlinenr = ''
let g:airline_symbols.branch = '⎇'
let g:airline_symbols.paste = 'ρ'
let g:airline_symbols.spell = 'Ꞩ'
let g:airline_symbols.notexists = 'Ɇ'
let g:airline_symbols.whitespace = 'Ξ'
" ----------------------------------------------------------------------------
