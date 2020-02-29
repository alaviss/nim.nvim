" Copyright 2019 Leorize <leorize+oss@disroot.org>
"
" Licensed under the terms of the ISC license,
" see the file "license.txt" included within this distribution.

function! s:getText(filename, lnum) abort
  let buffer = bufnr(fnameescape(a:filename))
  if bufloaded(buffer)
    return getbufline(buffer, a:lnum)[0]
  else
    return readfile(a:filename, '', a:lnum)[-1]
  endif
endfunction

function! s:on_end() abort dict
  call settabwinvar(0, self.window, 'nimSugLocListLock', v:false)
endfunction

function! s:on_data(reply) abort dict
  for i in a:reply
    let i = split(i, '\t', v:true)
    if nvim_win_is_valid(self.window)
      if i[0] is# 'def'
        call setloclist(self.window, [], ' ',
             \          {'title': 'References to symbol: ' . i[2]})
        call win_gotoid(self.window)
        lopen
      elseif i[0] is# 'use'
        let filename = i[4]
        let lnum = str2nr(i[5])
        call setloclist(self.window,
             \          [{
             \             'filename': filename,
             \             'lnum': lnum,
             \             'col': str2nr(i[6] + 1),
             \             'text': s:getText(filename, lnum)
             \          }],
             \          'a'
             \         )
      endif
    endif
  endfor
endfunction

" Open a location list showing references to the symbol under cursor.
"
" If no valid symbol is under the cursor, no action will be taken. This also
" holds true for cases where an another operation in this plugin which uses the
" location list of the current window is in progress. No action will also be
" taken if the originating window is destroyed.
function! nim#suggest#use#ShowReferences() abort
  if !exists('w:nimSugLocListLock') || !w:nimSugLocListLock
    let opts = {
        \         'on_data': function('s:on_data'),
        \         'on_end': function('s:on_end'),
        \         'window': win_getid(),
        \         'pos': getcurpos()[1:2]
        \      }
    let w:nimSugLocListLock = v:true
    call nim#suggest#utils#Query('use', opts, v:false)
  endif
endfunction
