" asynchronous highlighter using nimsuggest
"
" Copyright 2019 Leorize <leorize+oss@disroot.org>
"
" Licensed under the terms of the ISC license,
" see the file "license.txt" included within this distribution.

function! s:OnReply(chan, data, event) dict
  if a:event != 'data'
    return
  endif

  if a:data == ['']
    call chanclose(a:chan)
    if !empty(self.dirty)
      call delete(self.dirty)
    endif
    if self.hldata.newId != -1
      if self.hldata.srcId != -1
        call nvim_buf_clear_highlight(self.hldata.buffer, self.hldata.srcId, 0, -1)
      endif
      let self.hldata.srcId = self.hldata.newId
      let self.hldata.newId = -1
      if self.hldata.queued
        let self.hldata.queued = v:false
        call s:HighlightBuffer(self.instance, self.hldata)
      endif
    endif
    return
  endif

  let self.buf[-1] .= split(a:data[0], '\r', v:true)[0]
  call extend(self.buf, a:data[1:])
  while len(self.buf) > 1
    " nimsuggest will send a <CR> at the end of the reply
    " catch that as the marker to exit early
    let reply = split(self.buf[0], '\t', v:true)
    if reply[0] != "highlight"
      return
    endif
    " replace sk prefix with ours
    let group = "nimSug" . reply[1][2:]
    let line = str2nr(reply[2] - 1)
    let col = str2nr(reply[3])
    let count = str2nr(reply[4])
    call nvim_buf_add_highlight(self.hldata.buffer, self.hldata.newId, group,
         \                      line, col, col + count)
    unlet self.buf[0]
  endwhile
endfunction

function! s:HighlightBuffer(instance, hldata) abort
  if a:hldata.newId != -1
    " another highlight instance in-progress
    let a:hldata.queued = v:true
    return
  endif
  let curfile = expand("%:p")
  let fileext = expand("%:e")
  let dirty = ""
  let file = ""
  let ext = "nim"
  if filereadable(curfile)
    let file = curfile
  endif
  if fileext =~ '^\%(nim\|nims\|nimble\)$'
    let ext = fileext
  endif

  if &modified
    let dirty = tempname() . '.' . ext
    call writefile(getline(1, '$'), dirty, 'S')
  endif

  let a:hldata.newId = nvim_buf_add_highlight(a:hldata.buffer, 0, '', 0, 0, 0)
  let channel = nim#suggest#Connect(a:instance,
      \                             {'on_data': function('s:OnReply'),
      \                              'hldata': a:hldata,
      \                              'buf': [''],
      \                              'instance': a:instance,
      \                              'dirty': dirty})
  if channel == 0
    echomsg '[nim#suggest#highlight] Unable to connect to nimsuggest'
    if !empty(dirty)
      call delete(dirty)
    endif
    let a:hldata.newId = -1
    return
  endif

  call chansend(channel,
       \        ['highlight "' . file . '";"' . dirty . '"', ''])
endfunction

function! nim#suggest#highlight#HighlightBuffer()
  let current = nim#suggest#FindInstance()
  if empty(current)
    echomsg 'nimsuggest is not running for this project'
    return
  endif
  call nim#suggest#highlight#InitBuffer()
  call nim#suggest#RunAfterReady(current.instance,
       \                         {-> s:HighlightBuffer(current.instance,
       \                                               b:nimSugHighlight)})
endfunction

function! nim#suggest#highlight#InitBuffer()
  if exists('b:nimSugHighlight')
    return
  endif
  let buffer = bufnr('')
  let b:nimSugHighlight = {
      \ 'buffer': buffer,
      \ 'srcId': -1,
      \ 'newId': -1,
      \ 'queued': v:false
      \ }
endfunction
