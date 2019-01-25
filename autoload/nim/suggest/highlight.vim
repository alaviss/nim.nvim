" asynchronous highlighter using nimsuggest
"
" Copyright 2019 Leorize <leorize+oss@disroot.org>
"
" Licensed under the terms of the ISC license,
" see the file "license.txt" included within this distribution.

function! s:OnEnd() dict
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
endfunction

function! s:OnReply(reply) dict
  if a:reply[0] != "highlight"
    return
  endif
  " replace sk prefix with ours
  let group = "nimSug" . a:reply[1][2:]
  let line = str2nr(a:reply[2] - 1)
  let col = str2nr(a:reply[3])
  let count = str2nr(a:reply[4])
  call nvim_buf_add_highlight(self.hldata.buffer, self.hldata.newId, group,
       \                      line, col, col + count)
endfunction

function! s:HighlightBuffer(instance, hldata) abort
  if a:hldata.newId != -1
    " another highlight instance in-progress
    let a:hldata.queued = v:true
    return
  endif
  let fileQuery = nim#suggest#utils#MakeFileQuery(a:hldata.buffer)
  let a:hldata.newId = nvim_buf_add_highlight(a:hldata.buffer, 0, '', 0, 0, 0)
  let connOpts = {'on_data': v:null,
      \           'onReply': function('s:OnReply'),
      \           'onEnd': function('s:OnEnd'),
      \           'hldata': a:hldata,
      \           'buf': [''],
      \           'instance': a:instance,
      \           'dirty': fileQuery.dirty}
  let connOpts.on_data = function('nim#suggest#utils#BufferedCallback', connOpts)
  let channel = nim#suggest#Connect(a:instance, connOpts)
  if channel == 0
    echomsg '[nim#suggest#highlight] Unable to connect to nimsuggest'
    if !empty(fileQuery.dirty)
      call delete(fileQuery.dirty)
    endif
    let a:hldata.newId = -1
    return
  endif

  call chansend(channel, ['highlight ' . fileQuery.query, ''])
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
