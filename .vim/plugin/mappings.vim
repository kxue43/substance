" ----------------------------------------------------------------------------
" Global mappings
" ----------------------------------------------------------------------------
" Set no highlight until next search

nnoremap <silent> <C-L> :noh<CR>
" ----------------------------------------------------------------------------
" Turn on spell check for the local buffer

nnoremap <F1> :setlocal spell spelllang=en_us<CR>
" ----------------------------------------------------------------------------
" Add Claude Code as co-author

nnoremap <leader>cc :call append(line('.'), ['', 'Co-Authored-By: Claude Code <noreply@anthropic.com>'])<CR>
" ----------------------------------------------------------------------------
" Use NvChad style window navigation

nnoremap <C-h> <C-w><C-h>
nnoremap <C-j> <C-w><C-j>
nnoremap <C-k> <C-w><C-k>
nnoremap <C-l> <C-w><C-l>
" ----------------------------------------------------------------------------
" Use Tab and Shift+Tab to navigate buffers

function! s:IsSourceBuffer(bufnr)
  if !buflisted(a:bufnr)
    return 0
  endif
  if getbufvar(a:bufnr, '&buftype') != ''
    return 0
  endif
  if getbufvar(a:bufnr, '&filetype') ==# 'nerdtree'
    return 0
  endif
  return 1
endfunction

function! s:NavSourceBuffer(dir)
  let l:source_bufs = filter(range(1, bufnr('$')), {_, v -> s:IsSourceBuffer(v)})
  if empty(l:source_bufs)
    return
  endif
  let l:idx = index(l:source_bufs, bufnr('%'))
  let l:n = len(l:source_bufs)
  let l:next = l:source_bufs[(l:idx + a:dir + l:n) % l:n]
  if &buftype !=# ''
    let l:win = s:FindNormalWindow()
    if l:win > 0
      execute l:win . 'wincmd w'
    endif
  endif
  execute 'buffer ' . l:next
endfunction

function! s:FindNormalWindow()
  for l:w in range(1, winnr('$'))
    if getwinvar(l:w, '&buftype') ==# '' && getwinvar(l:w, '&filetype') !=# 'nerdtree'
      return l:w
    endif
  endfor
  return -1
endfunction

nnoremap <silent> <Tab>   :call <SID>NavSourceBuffer(1)<CR>
nnoremap <silent> <S-Tab> :call <SID>NavSourceBuffer(-1)<CR>
" ----------------------------------------------------------------------------
