" asynchronous highlighter using nimsuggest
"
" Copyright 2019 Leorize <leorize+oss@disroot.org>
"
" Licensed under the terms of the ISC license,
" see the file "license.txt" included within this distribution.

let s:Methods = {}

function! s:Methods.highlight() abort
  if self.locked
    let self.queued = v:true
    return
  endif
  let self.locked = v:true
  let updated = v:false
  function! self.on_data(reply) abort closure
    if empty(a:reply)
      if updated
        if exists('*nvim_buf_clear_namespace')
          call nvim_buf_clear_namespace(self.buffer, self.ids[0], 0, -1)
        else
          call nvim_buf_clear_highlight(self.buffer, self.ids[0], 0, -1)
        endif
        call reverse(self.ids)
      endif
      let self.locked = v:false
      if self.queued
        let self.queued = v:false
        call self.highlight()
      endif
    elseif a:reply[0] == 'highlight'
      let updated = v:true
      " replace sk prefix with ours
      let group = "nimSug" . a:reply[1][2:]
      let line = str2nr(a:reply[2]) - 1
      let col = str2nr(a:reply[3])
      let count = str2nr(a:reply[4])
      call nvim_buf_add_highlight(self.buffer, self.ids[1], group, line, col, col + count)
    endif
  endfunction
  call nim#suggest#utils#Query('highlight', self)
endfunction

" Semantically highlight the current buffer.
"
" This is an user-facing function, thus it does not return nor throw. Errors
" will be displayed as messages.
function! nim#suggest#highlight#HighlightBuffer()
  if !exists('b:nimSugHighlight')
    let b:nimSugHighlight = {
        \ 'buffer': bufnr(''),
        \ 'locked': v:false,
        \ 'queued': v:false
        \}
    let buf = bufnr('')
    if exists('*nvim_create_namespace')
      let b:nimSugHighlight['ids'] = [nvim_create_namespace('nim.nvim#1'),
          \                           nvim_create_namespace('nim.nvim#2')]
    else
      let b:nimSugHighlight['ids'] = [nvim_buf_add_highlight(buf, 0, '', 0, 0, 0),
          \                           nvim_buf_add_highlight(buf, 0, '', 0, 0, 0)]
    endif
    call extend(b:nimSugHighlight, s:Methods)
  endif

  call b:nimSugHighlight.highlight()
endfunction
