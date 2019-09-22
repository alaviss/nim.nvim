" functions used for go-to-definition feature
"
" Copyright 2019 Leorize <leorize+oss@disroot.org>
"
" Licensed under the terms of the ISC license,
" see the file "license.txt" included within this distribution.

function! s:on_data(reply) abort dict
  if nvim_win_is_valid(self.window)
    if empty(a:reply)
      call settabwinvar(0, self.window, 'nimSugDefLock', v:false)
    elseif a:reply[0] == 'def'
      let file = a:reply[4]
      let line = a:reply[5]
      let col = a:reply[6] + 1
      let openCmd = 'edit'
      if self.openIn == 'v'
        let openCmd = 'vsplit'
      elseif self.openIn == 's'
        let openCmd = 'split'
      endif
      call win_gotoid(self.window)
      if openCmd == 'edit' && bufnr(file) == winbufnr(self.window)
        call cursor([line, col])
      else
        execute openCmd '+' . 'call\ cursor([' . line . ',' . col . '])' fnameescape(file)
      endif
    endif
  endif
endfunction

" Go to the definition of the symbol under the cursor.
"
" openIn:
"   's'  => Use `split` to open the target buffer.
"   'v'  => Use `vsplit` to open the target buffer.
"   else => Use `edit` to open the target buffer. If the current buffer
"           contains the definition, the cursor will be moved to the target
"           position instead.
"
" Before jumping the ' mark will be set.
"
" If an another GoTo() is being done for the current window, no action
" will be made. Additionally, if the window is destroyed before GoTo()
" completes, no action will be made.
"
" This is an user-facing function, thus no errors will be thrown, instead they
" are displayed as messages.
function! nim#suggest#def#GoTo(openIn) abort
  if exists('w:nimSugDefLock') && w:nimSugDefLock
    return
  endif
  let opts = {'on_data': function('s:on_data'),
      \       'window': win_getid(),
      \       'openIn': a:openIn,
      \       'pos': getcurpos()[1:2]}
  let w:nimSugDefLock = v:true
  call setpos("''", getcurpos())
  call nim#suggest#utils#Query('def', opts, v:false, v:true)
endfunction
