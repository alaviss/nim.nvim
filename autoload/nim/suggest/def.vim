function! s:OnReply(reply) dict
  if a:reply[0] != 'def'
    return
  endif
  let file = a:reply[4]
  let line = a:reply[5]
  let col = a:reply[6] + 1
  let openCmd = 'edit'
  if self.openIn == 'v'
    let openCmd = 'vsplit'
  elseif self.openIn == 's'
    let openCmd = 'split'
  endif
  let win = win_id2win(self.window)
  if win == 0
    return
  endif
  if openCmd == 'edit' && bufnr(file) == winbufnr(win)
    execute win . 'windo ' . 'call cursor([' . line . ',' . col . '])'
  else
    execute win . 'windo ' . openCmd . ' ' . '+' .
    \       'call\ cursor([' . line . ',' . col . ']) ' . fnameescape(file)
  endif
endfunction

function! s:OnEnd() dict
  let tabwin = win_id2tabwin(self.window)
  call settabwinvar(tabwin[0], tabwin[1], 'nimSugDefLock', v:false)
endfunction

function! nim#suggest#def#GoTo(openIn)
  if exists('w:nimSugDefLock') && w:nimSugDefLock
    return
  endif
  let opts = {'onReply': function('s:OnReply'),
      \       'onEnd': function('s:OnEnd'),
      \       'window': win_getid(),
      \       'openIn': a:openIn}
  let w:nimSugDefLock = v:true
  call setpos("''", getcurpos())
  call nim#suggest#utils#Query(bufnr(''), line('.'), col('.'), 'def', opts, v:false)
endfunction
