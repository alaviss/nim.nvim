" helper functions for interfacing with nimsuggest
"
" Copyright 2019 Leorize <leorize+oss@disroot.org>
"
" Licensed under the terms of the ISC license,
" see the file "license.txt" included within this distribution.

" Creates an `on_data`-compatible callback that buffers data by line.
"
" cb: function(chan, line, stream) dict
"   chan corresponds to the channel number
"   stream corresponds to normal stream names used by neovim.
"   line is the buffered line. On EOF, an empty string is passed.
"   If a line is empty, a literal newline (\n) will be passed instead.
"
" The callback will be called with the assigned Dict as it's Dict.
function! nim#suggest#utils#BufferNewline(cb) abort
  let scoped = {}
  let buffer = ['']
  function! scoped.bufCb(chan, data, stream) abort closure
    let Cb = function(a:cb, self)

    if a:stream == 'exit'
      call Cb(a:chan, a:data, a:stream)
      return
    elseif a:data == ['']
      call Cb(a:chan, '', a:stream)
      return
    endif

    let buffer[-1] .= a:data[0]
    call extend(buffer, a:data[1:])
    while len(buffer) > 1
      call Cb(a:chan, !empty(buffer[0]) ? buffer[0] : '\n', a:stream)
      unlet buffer[0]
    endwhile
  endfunction
  return scoped.bufCb
endfunction

" Pretty print a nim.nvim exception
"
" This formats and print the exceptions emitted by the plugin.
" Useful for user-facing code.
function! nim#suggest#utils#PrintException()
  echomsg substitute(v:exception, '^suggest-.\{-}:\s*', 'nim.nvim: ', '')
endfunction

" Convenient wrapper for querying nimsuggest
"
" This wrapper abstracts away exceptions and the need to find a nimsuggest
" instance. Exceptions are displayed with `echomsg` to the user.
"
" command: same as instance.query()
" opts: same as instance.query()
" mustReady: same as instance.query()
" start: start a nimsuggest instance if none could be found
"
" Will return 0 on success and -1 on failure
function! nim#suggest#utils#Query(command, opts, ...)
  let mustReady = a:0 >= 1 ? a:1 : v:false
  let start = a:0 >= 2 ? a:2 : v:false

  let filename = bufname(has_key(a:opts, 'buffer') ? a:opts.buffer : '')
  let instance = nim#suggest#FindInstance(filename)
  if empty(instance)
    if !start
      echomsg 'no nimsuggest instance is running for this project'
      return -1
    else
      let instance = nim#suggest#ProjectFileStart(filename)
    endif
  endif

  try
    call instance.query(a:command, a:opts, mustReady)
  catch
    call nim#suggest#utils#PrintException()
    return -1
  endtry
  return 0
endfunction
