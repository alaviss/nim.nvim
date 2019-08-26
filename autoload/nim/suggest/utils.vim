" helper functions for interfacing with nimsuggest
"
" Copyright 2019 Leorize <leorize+oss@disroot.org>
"
" Licensed under the terms of the ISC license,
" see the file "license.txt" included within this distribution.

function! nim#suggest#utils#BufferNewline(cb) abort
  " cb: function(chan, line, stream) dict
  "   stream corresponds to normal stream names used by neovim.
  "   an empty string will be passed to line on EOF. If a line is empty, a
  "   newline will be passed instead.
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

function! nim#suggest#utils#Query(buf, line, col, query, opts, queue)
  " opts = { 'onReply': function(reply) invoked for each reply,
  "          'onEnd': function() invoked after query end (optional) }
  " retVal:
  "   1 = queued
  "   0 = executed
  "  -1 = failed
  let instance = nim#suggest#FindInstance(bufname(a:buf))
  if empty(instance)
    echomsg 'no nimsuggest instance is running for this project'
    return -1
  endif

  let scoped = {} " use a dummy dict to create anonymous functions
  function scoped.onSuggestReply(reply) abort closure
    if empty(a:reply)
      if has_key(self, 'onEnd')
        call self.onEnd()
      endif
      return
    endif

    call self.onReply(a:reply)
  endfunction

  let opts = {'on_data': scoped.onSuggestReply,
      \       'buffer': a:buf}
  if a:line >= 0 && a:col >= 0
    let opts['pos'] = [a:line, a:col]
  endif
  call extend(opts, a:opts)
  if !has_key(opts, 'onReply') || empty(opts.onReply)
    throw 'suggest-utils-query: reply callback required'
    return -1
  endif
  try
    call instance.query(a:query, opts, !a:queue)
  catch
    call function(scoped.onSuggestReply, opts)([])
    echomsg v:exception
    return -1
  endtry
  if a:queue
    return 1
  else
    return 0
  endif
endfunction
