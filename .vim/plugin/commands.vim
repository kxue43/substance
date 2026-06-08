" ----------------------------------------------------------------------------
" Global commands
" ----------------------------------------------------------------------------
" Show man page in a new buffer and set it as the only window

command! -nargs=+ KMan call s:OpenManPage(<q-args>)

function! s:OpenManPage(args)
  " Load the man.vim plugin if hasn't
  if !exists(':Man')
    runtime ftplugin/man.vim
  endif

  execute ':Man ' . a:args
  only
endfunction
" ----------------------------------------------------------------------------
