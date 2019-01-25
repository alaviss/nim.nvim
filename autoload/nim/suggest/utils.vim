" helper functions for interfacing with nimsuggest
"
" Copyright 2019 Leorize <leorize+oss@disroot.org>
"
" Licensed under the terms of the ISC license,
" see the file "license.txt" included within this distribution.

function! nim#suggest#utils#BufferedCallback(chan, data, event) dict
  " required self.buf = ['']
  " required self.onReply(reply) where reply = split(line, '\t')
  " optional self.onEnd()
  " optional self.closeNow = v:false
  if a:event != 'data'
    return
  endif

  if a:data == ['']
    call chanclose(a:chan)
    if has_key(self, 'onEnd')
      call self.onEnd()
      return
    endif
  endif

  if has_key(self, 'closeNow') && self.closeNow
    call chanclose(a:chan)
    return
  endif

  let self.buf[-1] .= split(a:data[0], '\r', v:true)[0]
  call extend(self.buf, a:data[1:])
  while len(self.buf) > 1
    let reply = split(self.buf[0], '\t', v:true)
    call self.onReply(reply)
    unlet self.buf[0]
  endwhile
endfunction

function! nim#suggest#utils#MakeFileQuery(buf, ...)
  let line = a:0 >= 1 ? a:1 : -1
  let col = a:0 >= 2 ? a:2 - 1 : -1
  let file = fnamemodify(bufname(a:buf), ':p')
  let ext = fnamemodify(file, ':e')
  let dirty = ''
  if getbufvar(a:buf, '&modified')
    let dirty = tempname() . '.' . ext
    call writefile(getbufline(a:buf, 1, '$'), dirty, 'S')
  endif
  let query = '"' . file . '"'
  let query .= !empty(dirty) ? ';"' . dirty . '"' : ''
  if line >= 0 && col >= 0
    let query .= ':' . line . ':' . col
  endif
  return {'query': query, 'dirty': dirty}
endfunction
