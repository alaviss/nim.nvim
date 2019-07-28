" helper functions for interfacing with nimsuggest
"
" Copyright 2019 Leorize <leorize+oss@disroot.org>
"
" Licensed under the terms of the ISC license,
" see the file "license.txt" included within this distribution.

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

function! s:BufferedCallback(chan, data, event) dict
  " required self['utils#buffer'] = ['']
  " required self['utils#on_reply'](reply) where reply = split(line, '\t')
  " optional self['utils#on_end']()
  if a:event != 'data'
    return
  endif

  if a:data == ['']
    call chanclose(a:chan)
    call self['utils#on_end']()
    return
  endif

  let buffer = self['utils#buffer']
  let buffer[-1] .= split(a:data[0], '\r', v:true)[0]
  call extend(buffer, a:data[1:])
  while len(buffer) > 1
    let reply = split(buffer[0], '\t', v:true)
    call self.onReply(reply)
    unlet buffer[0]
  endwhile
endfunction

function! s:EndCallback() dict
  if !empty(self['utils#dirty'])
    call delete(self['utils#dirty'])
  endif
  if has_key(self, 'onEnd') && !empty(self.onEnd)
    call self.onEnd()
  endif
endfunction

function! nim#suggest#utils#Query(buf, line, col, query, opts, queue, ...)
  " opts = { 'onReply': function(reply) invoked for each reply,
  "          'onEnd': function() invoked after query end (optional) }
  " retVal:
  "   1 = queued
  "   0 = executed
  "  -1 = failed
  let failed = a:0 >= 1 ? a:1 : v:false
  if failed
    if has_key(a:opts, 'onEnd')
      call a:opts.onEnd()
    endif
    return -1
  endif
  let instance = nim#suggest#FindInstance(bufname(a:buf))
  if empty(instance)
    echomsg 'nimsuggest is not running for this project'
    if has_key(a:opts, 'onEnd')
      call a:opts.onEnd()
    endif
    return -1
  endif
  if !a:queue && instance.instance.port == -1
    echomsg 'nimsuggest is not ready for this project'
    if has_key(a:opts, 'onEnd')
      call a:opts.onEnd()
    endif
    return -1
  elseif instance.instance.port == -1
    call nim#suggest#RunAfterReady(instance.instance,
         \                         function('nim#suggest#utils#Query',
         \                                  [a:buf, a:line, a:col, a:query,
         \                                   a:opts, a:queue]))
    return 1
  endif
  let fileQuery = nim#suggest#utils#MakeFileQuery(a:buf, a:line, a:col)
  let opts = {'on_data': function('s:BufferedCallback'),
      \       'utils#on_end': function('s:EndCallback'),
      \       'utils#buffer': [''],
      \       'utils#dirty': fileQuery.dirty}
  call extend(opts, a:opts)
  if !has_key(opts, 'onReply') || empty(opts.onReply)
    echoerr 'reply callback required'
  endif
  let chan = nim#suggest#Connect(instance.instance, opts)
  if chan == 0
    echomsg 'unable to connect to nimsuggest'
    call opts['utils#on_end']()
    return -1
  endif
  call chansend(chan, [a:query . ' ' . fileQuery.query, ''])
  return 0
endfunction
