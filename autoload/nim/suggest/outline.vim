" Copyright 2019 Leorize <leorize+oss@disroot.org>
"
" Licensed under the terms of the ISC license,
" see the file "license.txt" included within this distribution.

function! s:OnReply(reply) dict
  if a:reply[0] != 'outline'
    return
  endif

  let prefix = tolower(a:reply[1][2:])
  call setloclist(self.window,
       \          [{
       \             'bufnr': self.buffer,
       \             'filename': a:reply[4],
       \             'lnum': str2nr(a:reply[5]),
       \             'col': str2nr(a:reply[6] + 1),
       \             'text': prefix . ' ' . join(split(a:reply[2], '\i\.\zs')[1:], '')
       \          }],
       \          'a'
       \         )
endfunction

function! s:OnEnd() dict
  let tabwin = win_id2tabwin(self.window)
  call settabwinvar(tabwin[0], tabwin[1], 'nimSugOutlineLock', v:false)
endfunction

function! nim#suggest#outline#OpenLocList()
  if exists('w:nimSugOutlineLock') && w:nimSugOutlineLock
    return
  endif
  let opts = {
      \         'onReply': function('s:OnReply'),
      \         'onEnd': function('s:OnEnd'),
      \         'buffer': bufnr(''),
      \         'window': win_getid()
      \      }
  let w:nimSugOutlineLock = v:true
  call setloclist(opts.window, [], ' ', {'title': 'Outline'})
  if nim#suggest#utils#Query(bufnr(''), line('.'), col('.'), 'outline', opts, v:false) == 0
    lopen
  endif
endfunction
