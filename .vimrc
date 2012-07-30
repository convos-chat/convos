" Add this to ~/.vimrc to read custom .vimrc from the curren directory
"
" au BufNewFile,BufRead * call CheckForCustomConfiguration()
" function! CheckForCustomConfiguration()
"   if filereadable('.vimrc')
"     exe 'source .vimrc'
"   endif
" endfunction

set shiftwidth=2
set softtabstop=2
