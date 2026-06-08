" terminal.vim
" Integrated terminal management: open, hide, toggle bottom/fullscreen.
"
" <A-h>  normal    Toggle terminal at the bottom (open / hide)
" <A-h>  terminal  Hide terminal (bottom → close window; fullscreen → swap buffer)
" <A-k>  normal    Open terminal in fullscreen (create or reveal)
" <A-k>  terminal  Toggle between bottom split and fullscreen
" <A-n>  terminal  Exit terminal mode → Normal mode in the terminal window

let s:term_buf = 0

function! s:TermHeight() abort
  return float2nr(&lines * 0.3)
endfunction

function! s:IsTermBufValid() abort
  return s:term_buf != 0
        \ && bufexists(s:term_buf)
        \ && term_getstatus(s:term_buf) =~# 'running'
endfunction

" Suppress line numbers in terminal windows
" set nu is global; setlocal overrides it per-window, including after <C-w>N.
augroup TerminalNoLineNr
  autocmd!
  autocmd TerminalOpen      *  setlocal nonumber norelativenumber
  autocmd BufEnter,WinEnter *  if &buftype ==# 'terminal'
                             \  | setlocal nonumber norelativenumber
                             \  | endif
augroup END

" Internal helpers

" Switch the current window to a non-terminal buffer, skipping buf `a:avoid`.
function! s:SwitchToSource(avoid) abort
  let l:alt = bufnr('#')
  if l:alt > 0 && bufexists(l:alt) && l:alt != a:avoid
        \ && getbufvar(l:alt, '&buftype') !=# 'terminal'
    execute 'buffer! ' . l:alt
  else
    let l:bufs = filter(range(1, bufnr('$')),
          \ 'buflisted(v:val) && getbufvar(v:val, "&buftype") !=# "terminal"'
          \ . ' && v:val != ' . a:avoid)
    execute empty(l:bufs) ? 'enew' : ('buffer! ' . l:bufs[0])
  endif
endfunction

" Create a fresh terminal at the bottom.
" ':terminal' always opens its own split, so prepending a height gives E16.
" Instead: open a sized split first, then start the terminal inside it with
" curwin:1 so term_start() reuses the current window rather than adding one.
function! s:CreateTermAtBottom() abort
  execute 'botright ' . s:TermHeight() . ' split'
  call term_start(&shell, {'curwin': 1, 'exit_cb': function('s:OnTermExit')})
  let s:term_buf = bufnr('%')
  setlocal nonumber norelativenumber
endfunction

" Re-open a hidden terminal buffer at the bottom.
function! s:OpenTermAtBottom() abort
  execute 'botright ' . s:TermHeight() . 'split'
  execute 'buffer ' . s:term_buf
  setlocal nonumber norelativenumber
  startinsert
endfunction

" Close the terminal window without killing the buffer or the shell process.
function! s:HideTermWindow() abort
  let l:win = bufwinnr(s:term_buf)
  if l:win != -1
    execute l:win . 'wincmd w'
    hide
  endif
endfunction

" Entry points called from keymaps

" <A-h> normal — toggle terminal at bottom
function! s:ToggleTerm() abort
  if !s:IsTermBufValid()
    call s:CreateTermAtBottom()
  elseif bufwinnr(s:term_buf) != -1
    call s:HideTermWindow()
  else
    call s:OpenTermAtBottom()
  endif
endfunction

" <A-h> terminal — hide terminal regardless of layout
function! s:HideTermFromTerminal() abort
  let l:alt = bufnr('#')
  if l:alt == -1 || !bufexists(l:alt)
    return
  endif
  if bufwinnr(l:alt) > 0
    " Terminal is at bottom; source buffer visible above → close terminal window.
    call s:HideTermWindow()
  else
    " Terminal is fullscreen → swap window back to source buffer.
    " buffer! required: plain :buffer refuses to leave a running terminal.
    execute 'buffer! ' . l:alt
  endif
endfunction

" <A-k> terminal — toggle between bottom split and fullscreen
function! s:ToggleTermSizeFromTerminal() abort
  let l:alt = bufnr('#')
  if l:alt == -1 || !bufexists(l:alt)
    return
  endif
  if bufwinnr(l:alt) > 0
    " Terminal is at bottom → make fullscreen.
    let l:cur = winnr()
    wincmd k
    if winnr() != l:cur
      hide
    endif
    startinsert
  else
    " Terminal is fullscreen → restore to a bottom split.
    execute 'buffer! ' . l:alt
    call s:OpenTermAtBottom()
  endif
endfunction

" <A-k> normal — open terminal (create or reveal) directly in fullscreen
function! s:OpenTermFullscreen() abort
  if !s:IsTermBufValid()
    execute 'botright ' . s:TermHeight() . ' split'
    call term_start(&shell, {'curwin': 1, 'exit_cb': function('s:OnTermExit')})
    let s:term_buf = bufnr('%')
    setlocal nonumber norelativenumber
  elseif bufwinnr(s:term_buf) == -1
    execute 'botright ' . s:TermHeight() . 'split'
    execute 'buffer ' . s:term_buf
    setlocal nonumber norelativenumber
  else
    execute bufwinnr(s:term_buf) . 'wincmd w'
  endif
  let l:cur = winnr()
  wincmd k
  if winnr() != l:cur
    hide
  endif
  startinsert
endfunction

" Lifecycle: keep Vim alive when the terminal job ends

augroup TerminalLifecycle
  autocmd!
  " TerminalClose doesn't exist in Vim (only Neovim has TermClose).
  " Job-end cleanup is handled via exit_cb passed to term_start instead.
  autocmd BufEnter * call s:CheckTermOnlyWindow()
augroup END

" Called by term_start exit_cb when the shell process exits.
function! s:OnTermExit(job, status) abort
  if s:term_buf == 0 || !bufexists(s:term_buf)
    return
  endif
  call s:OnTermJobEnd(s:term_buf)
endfunction

function! s:OnTermJobEnd(buf) abort
  if a:buf == s:term_buf
    let s:term_buf = 0
  endif
  let l:w = bufwinnr(a:buf)
  if l:w == -1
    return
  endif
  noautocmd execute l:w . 'wincmd w'
  if winnr('$') == 1
    " Only window left — swap to source buffer so Vim doesn't exit.
    call s:SwitchToSource(a:buf)
  else
    " Sibling windows exist — just close the finished terminal window.
    close!
  endif
endfunction

function! s:CheckTermOnlyWindow() abort
  if &buftype !=# 'terminal' || winnr('$') != 1
    return
  endif
  let l:has_source = !empty(filter(range(1, bufnr('$')),
        \ 'buflisted(v:val) && getbufvar(v:val, "&buftype") !=# "terminal"'))
  if !l:has_source
    qall!
  endif
endfunction

" Lifecycle: suppress E947 when quitting with a hidden terminal

augroup TerminalQuitCleanup
  autocmd!
  " Kill the terminal job before Vim's job-running check (E947) can fire.
  " Only acts when the :q would leave no non-terminal windows.
  autocmd QuitPre * call s:OnQuitPre()
augroup END

function! s:OnQuitPre() abort
  if !s:IsTermBufValid()
    return
  endif
  let l:ntw = filter(range(1, winnr('$')),
        \ 'getbufvar(winbufnr(v:val), "&buftype") !=# "terminal"')
  if len(l:ntw) > 1
    return
  endif
  let l:tb = s:term_buf
  let s:term_buf = 0
  silent! call job_stop(term_getjob(l:tb), 'kill')
  " bwipeout! removes the buffer synchronously; without it the process hasn't
  " been reaped yet when QuitPre returns and Vim fires E947.
  silent! execute 'bwipeout! ' . l:tb
endfunction

" Key bindings

" screen-256color (Tmux's default-terminal) lacks meta-key definitions, so Vim
" doesn't recognise ESC+key as <A-key> automatically. Declare them explicitly.
if !has('gui_running')
  execute "set <A-h>=\eh"
  execute "set <A-k>=\ek"
  execute "set <A-n>=\en"
endif

nnoremap <silent> <A-h> :call <SID>ToggleTerm()<CR>
tnoremap <silent> <A-h> <C-w>:call <SID>HideTermFromTerminal()<CR>
tnoremap <silent> <A-k> <C-w>:call <SID>ToggleTermSizeFromTerminal()<CR>
nnoremap <silent> <A-k> :call <SID>OpenTermFullscreen()<CR>
tnoremap <silent> <A-n> <C-w>N
