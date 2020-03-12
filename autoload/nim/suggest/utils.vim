" helper functions for interfacing with nimsuggest
"
" Copyright 2019 Leorize <leorize+oss@disroot.org>
"
" Licensed under the terms of the ISC license,
" see the file "license.txt" included within this distribution.

function! s:process(data) abort dict
  " more than one line is received, and/or the last buffer completed
  if len(a:data) > 1
    " the first item completes the buffer
    let a:data[0] = self.buffer . a:data[0]
    " the last item is incomplete, buffer from there
    let self.buffer = a:data[-1]
  else
    let self.buffer .= a:data[0]
  endif
  call remove(a:data, -1)
endfunction

" Return a Dict for processing the raw data passed to `on_data`-style callbacks.
"
" The Dict provides:
"   function process(data): This function take in the `a:data` List, then
"                           process it so that the list contains only
"                           completed lines.
function! nim#suggest#utils#NewLineBuffer() abort
  return {
  \   'buffer': '',
  \   'process': function('s:process')
  \}
endfunction

function s:bufCb(env, chan, data, stream) abort dict
  let Cb = function(a:env.cb, self)

  if a:stream is# 'exit'
    call Cb(a:chan, a:data, a:stream)
  elseif a:data ==# ['']
    call Cb(a:chan, v:null, a:stream)
  else
    call a:env.buffer.process(a:data)
    for i in a:data
      call Cb(a:chan, i, a:stream)
    endfor
  endif
endfunction

" Creates an `on_data`-compatible callback that buffers data by line.
"
" cb: function(chan, line, stream) dict
"   chan corresponds to the channel number
"   stream corresponds to normal stream names used by neovim.
"   line is the buffered line. On EOF, v:null is passed to line.
"
" The callback will be called with the assigned Dict as it's Dict.
function! nim#suggest#utils#BufferNewline(cb) abort
  let env = {
  \   'cb': a:cb,
  \   'buffer': nim#suggest#utils#NewLineBuffer(),
  \}
  return function('s:bufCb', [env])
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
  catch /^suggest-/
    call nim#suggest#utils#PrintException()
    return -1
  endtry
  return 0
endfunction

" Returns the cursor column where the Nim identifier under the cursor starts
"
" The current column will be returned if a valid Nim identifer is not found.
function! nim#suggest#utils#FindIdentifierStart() abort
  let line = getline('.')
  let start = col('.')
  if mode() is# 'i'
    " when in insert mode, the cursor will be placed at the next character,
    " so we reduce it to get the right position.
    let start -= 1
  endif
  " the cursor position starts from 1, but string starts from 0.
  let result = start - 1
  while result >= 0 && line[result] =~ '\k'
    let result -= 1
  endwhile
  let result += 1
  if result < start && line[result] =~ '\K'
    " found an identifier, advance by one to get the cursor column
    let result += 1
  else
    let result = start
  endif
  return result
endfunction
