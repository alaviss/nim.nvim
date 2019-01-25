function! s:OnReply(reply) dict
  if a:reply[0] != 'def'
    return
  endif
  let file = a:reply[4]
  let line = a:reply[5]
  let col = a:reply[6] + 1
  if file == self.dirty
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

function! s:OnEnd() dict
  if !empty(self.dirty)
    call delete(self.dirty)
  endif
endfunction

function! nim#suggest#def#GoTo(openIn)
  let current = nim#suggest#FindInstance()
  if empty(current)
    echomsg 'nimsuggest is not running for this project'
    return
  endif
  if current.instance.port == -1
    echomsg 'nimsuggest is not yet ready'
    return
  endif
  let buffer = bufnr('')
  let fileQuery = nim#suggest#utils#MakeFileQuery(buffer, line('.'), col('.'))
  let connOpts = {'on_data': v:null,
      \           'onReply': function('s:OnReply'),
      \           'onEnd': function('s:OnEnd'),
      \           'buf': [''],
      \           'buffer': buffer,
      \           'dirty': fileQuery.dirty,
      \           'openIn': a:openIn}
  let connOpts.on_data = function('nim#suggest#utils#BufferedCallback', connOpts)
  let chan = nim#suggest#Connect(current.instance, connOpts)
  if chan == 0
    if !empty(fileQuery.dirty)
      call delete(fileQuery.dirty)
    endif
    return
  endif
  call chansend(chan, ['def ' . fileQuery.query, ''])
endfunction
