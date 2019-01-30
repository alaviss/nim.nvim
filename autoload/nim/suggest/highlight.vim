" asynchronous highlighter using nimsuggest
"
" Copyright 2019 Leorize <leorize+oss@disroot.org>
"
" Licensed under the terms of the ISC license,
" see the file "license.txt" included within this distribution.

function! s:OnEnd() dict
  let data = self.hldata
  if data.newId != -1
    if data.srcId != -1
      call nvim_buf_clear_highlight(self.buffer, data.srcId, 0, -1)
    endif
    let data.srcId = data.newId
    let data.newId = -1
    if data.queued
      let data.queued = v:false
      call s:HighlightBuffer(self.buffer, data)
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
  call nvim_buf_add_highlight(self.buffer, self.hldata.newId, group,
       \                      line, col, col + count)
endfunction

function! s:HighlightBuffer(buffer, hldata) abort
  if a:hldata.newId != -1
    " another highlight instance in-progress
    let a:hldata.queued = v:true
    return
  endif
  let a:hldata.newId = nvim_buf_add_highlight(a:buffer, 0, '', 0, 0, 0)
  let opts = {'onReply': function('s:OnReply'),
      \       'onEnd': function('s:OnEnd'),
      \       'buffer': a:buffer,
      \       'hldata': a:hldata}
  call nim#suggest#utils#Query(a:buffer, -1, -1, 'highlight', opts, v:true)
endfunction

function! nim#suggest#highlight#HighlightBuffer()
  call nim#suggest#highlight#InitBuffer()
  call s:HighlightBuffer(bufnr(''), b:nimSugHighlight)
endfunction

function! nim#suggest#highlight#InitBuffer()
  if exists('b:nimSugHighlight')
    return
  endif
  let b:nimSugHighlight = {
      \ 'srcId': -1,
      \ 'newId': -1,
      \ 'queued': v:false
      \ }
endfunction
