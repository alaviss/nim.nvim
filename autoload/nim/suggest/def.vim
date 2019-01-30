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
  if openCmd == 'edit' && bufnr(file) == self.buffer
    execute self.buffer . 'bufdo! ' . 'call cursor([' . line . ',' . col . '])'
  elseif bufwinnr(self.buffer) != -1 || openCmd == 'edit'
    execute self.buffer . 'bufdo! ' . openCmd . ' ' . '+' .
    \       'call\ cursor([' . line . ',' . col . ']) ' . fnameescape(file)
  endif
endfunction

function! s:OnEnd() dict
  call setbufvar(self.buffer, 'nimSugDefLock', v:false)
endfunction

function! nim#suggest#def#GoTo(openIn)
  if exists('b:nimSugDefLock') && b:nimSugDefLock
    return
  endif
  let buffer = bufnr('')
  let opts = {'onReply': function('s:OnReply'),
      \       'onEnd': function('s:OnEnd'),
      \       'buffer': buffer,
      \       'openIn': a:openIn}
  let b:nimSugDefLock = v:true
  call nim#suggest#utils#Query(buffer, line('.'), col('.'), 'def', opts, v:false)
endfunction
