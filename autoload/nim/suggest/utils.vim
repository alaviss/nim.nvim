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

function! nim#suggest#utils#Query(buf, line, col, query, opts, queue)
  " opts = { 'onReply': function(reply) invoked for each reply,
  "          'onEnd': function() invoked after query end (optional) }
  " retVal:
  "   1 = queued
  "   0 = executed
  "  -1 = failed
  let instance = nim#suggest#FindInstance(bufname(a:buf))
  if empty(instance) || !instance.isRunning()
    echomsg 'nimsuggest is not running for this project'
    if has_key(a:opts, 'onEnd')
      call a:opts.onEnd()
    endif
    return -1
  endif
  if !a:queue && !instance.isReady()
    echomsg 'nimsuggest is not ready for this project'
    if has_key(a:opts, 'onEnd')
      call a:opts.onEnd()
    endif
    return -1
  endif
  let fileQuery = nim#suggest#utils#MakeFileQuery(a:buf, a:line, a:col)

  let scoped = {} " use a dummy dict to create anonymous functions
  function scoped.onSuggestReply(chan, line, stream) abort closure
    if empty(a:line)
      if !empty(fileQuery.dirty)
        call delete(fileQuery.dirty)
      endif
      if has_key(self, 'onEnd')
        call self.onEnd()
      endif
      return
    endif

    let reply = split(trim(a:line), '\t')
    call self.onReply(!empty(reply) ? reply : [''])
  endfunction

  let opts = {'on_data': nim#suggest#utils#BufferNewline(scoped.onSuggestReply)}
  call extend(opts, a:opts)
  if !has_key(opts, 'onReply') || empty(opts.onReply)
    throw 'suggest-utils-query: reply callback required'
    return -1
  endif
  try
    call instance.message([a:query . ' ' . fileQuery.query, ''], opts)
  catch /^suggest-manager-connect/
    echomsg 'unable to connect to nimsuggest'
    call scoped.onSuggestReply(0, '', '')
    return -1
  endtry
  return 0
endfunction
