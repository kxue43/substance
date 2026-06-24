" ----------------------------------------------------------------------------
" Package settings
" ----------------------------------------------------------------------------
" Packages are manually mananged inside the ~/.vim/pack/*/start/* folders.
" Currently there are no opt files, only start.

" ~/.vim/pack
"   ├─ gruvbox/start/gruvbox
"   ├─ nerdtree/start/nerdtree
"   ├─ vim-airline/start/vim-airline
"   └─ vim-airline-themes/start/vim-airline-themes
" ----------------------------------------------------------------------------
" Nerdtree setting

" Toggle nerdtree
nmap <C-n> :NERDTreeToggle<CR>
" ----------------------------------------------------------------------------
" Gruvbox color scheme setting

let g:gruvbox_bold = 0
let g:gruvbox_italic = 0

autocmd vimenter * ++nested colorscheme gruvbox
" ----------------------------------------------------------------------------
" Vim-airline setting

" Show buffer info at the top as a tab line
let g:airline#extensions#tabline#enabled = 1

" Airline theme
let g:airline_theme='base16_gruvbox_dark_medium'

" The term extension renders section C using the `airline_term` highlight group,
" which no theme defines. Patch it with the normal-mode section-C colors so
" it doesn't fall back to a black background in terminal buffers.
function! AirlineThemePatch(palette) abort
  if !has_key(a:palette, 'normal') || !has_key(a:palette.normal, 'airline_c')
    return
  endif
  if !has_key(a:palette, 'terminal')
    let a:palette.terminal = {}
  endif
  let a:palette.terminal['airline_term'] = copy(a:palette.normal['airline_c'])
endfunction
let g:airline_theme_patch_func = 'AirlineThemePatch'

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
