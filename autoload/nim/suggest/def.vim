function! s:OnReply(reply) dict
  if a:reply[0] != 'def'
    return
  endif
  let file = a:reply[4]
  let line = a:reply[5]
  let col = a:reply[6] + 1
  if file == self['utils#dirty']
    let file = fnamemodify(bufname(self.buffer), ':p')
  endif
  let openCmd = 'edit'
  if self.openIn == 'v'
    let openCmd = 'vsplit'
  elseif self.openIn == 's'
    let openCmd = 'split'
  endif
  if openCmd == 'edit' && file == fnamemodify(bufname(self.buffer), ':p')
    execute self.buffer . 'bufdo! ' . 'call cursor([' . line . ',' . col . '])'
  else
    execute self.buffer . 'bufdo! ' . openCmd . ' ' . '+' .
    \       'call\ cursor([' . line . ',' . col . ']) ' . file
  endif
  let self.closeNow = v:true
endfunction

function! nim#suggest#def#GoTo(openIn)
  let buffer = bufnr('')
  let opts = {'onReply': function('s:OnReply'),
      \       'buffer': buffer,
      \       'openIn': a:openIn}
  call nim#suggest#utils#Query(buffer, line('.'), col('.'), 'def', opts, v:false)
endfunction
