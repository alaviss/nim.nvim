" Copyright 2019 Leorize <leorize+oss@disroot.org>
"
" Licensed under the terms of the ISC license,
" see the file "license.txt" included within this distribution.

function! s:on_data(reply) abort dict
  if nvim_win_is_valid(self.window)
    if a:reply is v:null
      call settabwinvar(0, self.window, 'nimSugLocListLock', v:false)
    " Don't display gensym-ed symbols
    elseif a:reply[0] == 'outline' && a:reply[2] !~ '`gensym\d\+$'
      let prefix = tolower(a:reply[1][2:])
      call setloclist(self.window,
           \          [{
           \             'bufnr': self.buffer,
           \             'filename': a:reply[4],
           \             'lnum': str2nr(a:reply[5]),
           \             'col': str2nr(a:reply[6] + 1),
           \             'text': prefix . ' ' . join(split(a:reply[2], '\i\.\zs')[1:], '')
           \          }],
           \          'a'
           \         )
    endif
  endif
endfunction

" Opens a location list containing the outline of the current module.
"
" When an another operation that uses the location list of this window in this
" plugin is being done, no action will be taken. Alternatively, no action will
" be taken when the window that requested the location list is destroyed.
"
" This is an user-facing function, thus it does not return nor throw. Errors
" will be displayed as messages.
function! nim#suggest#outline#OpenLocList() abort
  if !exists('w:nimSugLocListLock') || !w:nimSugLocListLock
    let opts = {
        \         'on_data': function('s:on_data'),
        \         'window': win_getid()
        \      }
    let w:nimSugLocListLock = v:true
    call setloclist(opts.window, [], ' ', {'title': 'Outline'})
    if nim#suggest#utils#Query('outline', opts, v:false) == 0
      lopen
    endif
  endif
endfunction
