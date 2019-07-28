" Copyright 2019 Leorize <leorize+oss@disroot.org>
"
" Licensed under the terms of the ISC license,
" see the file "license.txt" included within this distribution.

function! s:GetText(filename, lnum)
  let buffer = bufnr(fnameescape(a:filename))
  if buffer != -1
    return getbufline(buffer, a:lnum)[0]
  else
    return readfile(a:filename, '', a:lnum)[-1]
  endif
endfunction

function! s:OnReply(reply) dict
  if a:reply[0] == 'def'
    call setloclist(self.window, [], 'a',
         \          {'title': 'References to symbol: ' . a:reply[2]})
    return
  endif
  if a:reply[0] != 'use'
    return
  endif

  let filename = a:reply[4]
  let lnum = str2nr(a:reply[5])
  call setloclist(self.window,
       \          [{
       \             'filename': filename,
       \             'lnum': lnum,
       \             'col': str2nr(a:reply[6] + 1),
       \             'text': s:GetText(filename, lnum)
       \          }],
       \          'a'
       \         )
endfunction

function! s:OnEnd() dict
  let tabwin = win_id2tabwin(self.window)
  call settabwinvar(tabwin[0], tabwin[1], 'nimSugUseLock', v:false)
endfunction

function! nim#suggest#use#ShowReferences()
  if exists('w:nimSugUseLock') && w:nimSugUseLock
    return
  endif
  let opts = {
      \         'onReply': function('s:OnReply'),
      \         'onEnd': function('s:OnEnd'),
      \         'window': win_getid()
      \      }
  let w:nimSugUseLock = v:true
  call setloclist(opts.window, [], ' ', {'title': 'References to symbol:'})
  if nim#suggest#utils#Query(bufnr(''), line('.'), col('.'), 'use', opts, v:false) == 0
    lopen
  endif
endfunction
