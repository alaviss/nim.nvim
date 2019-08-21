" nimsuggest management routines
"
" Copyright 2019 Leorize <leorize+oss@disroot.org>
"
" Licensed under the terms of the ISC license,
" see the file "license.txt" included within this distribution.

" type NimsuggestConfig = {
"   'nimsuggest': '/path/to/nimsuggest' (or any binary in PATH)
"   'extraArgs': [] (a list of extra arguments for nimsuggest, will be passed
"                    after the default arguments ['--autobind',
"                    '--address:localhost'])
" }
"
" exception 'suggest-manager-':
"   'compat': regarding compatibility with nimsuggest
"   'running': regarding an instance 'running' state
"   'ready': regarding an instance 'ready' state
"   'exec': regarding execution of an external program
"   'file': regarding files
"   'connect': regarding connection

" Poor man's typing. This is a method table for all SuggestInstance
let s:SuggestInstance = {}

" Checks if the given instance is running.
function! s:SuggestInstance.isRunning() abort
  return self.job != 0
endfunction

" Checks if the given instance can receive connections.
function! s:SuggestInstance.isReady() abort
  return self.job != 0 && self.port != 0
endfunction

" Starts the instance, can also be used to restart a dead instance.
function! s:SuggestInstance.start() abort
  if self.isRunning()
    throw 'suggest-manager-running: instance is already running'
  endif
  let self.port = 0
  let self.job = 0
  let job = jobstart([self.cmd] + self.args + [self.file], self)
  if job == 0
    throw 'suggest-manager-exec: unable to start nimsuggest'
  elseif job == -1
    throw 'suggest-manager-exec: nimsuggest (' . self.cmd . ') cannot be executed'
  endif
  let self.job = job
endfunction

" A thin wrapper over jobstop() for stopping an instance. Does nothing if the
" instance is not running.
function! s:SuggestInstance.stop() abort dict
  if self.isRunning()
    call jobstop(self.job)
  endif
endfunction

" Messages the instance asynchronously.
"
" It might take a while for the instance to become ready. If immediate result
" is wanted, it's advised to check with inst.isReady() before calling this
" function.
"
" data: See ':h chansend'
" opts: See ':h sockconnect'
"
" If the instance died before message can be sent, `on_data` will be called with
" on_data(0, [''], 'data').
"
" Will throw if instance is not running.
function! s:SuggestInstance.message(data, opts) abort dict
  let scoped = {}
  function scoped.message(nothrow) abort closure
    try
      let channel = sockconnect('tcp', 'localhost:' . self.port, a:opts)
    catch
      if a:nothrow
        call a:opts.on_data(0, [''], 'data')
        return
      else
        throw 'suggest-manager-connect: unable to connect to nimsuggest'
      endif
    endtry
    call chansend(channel, a:data)
  endfunction

  function scoped.onReady(event) abort closure
    if a:event == 'ready'
      call scoped.message(v:true)
    else
      call a:opts.on_data(0, [''], 'data')
    endif
  endfunction
  let scoped.message = function(scoped.message, self)
  let scoped.onReady = function(scoped.onReady, self)

  if !self.isReady()
    call self.await(scoped.onReady)
  else
    call scoped.message(v:false)
  endif
endfunction

" Set a callback to be called when the instance is ready. The callback will
" also be called if the instance died.
"
" callback: function(event)
"   event => 'ready': Instance is ready
"   event => 'exit': Instance didn't finish initializing and exited
function! s:SuggestInstance.await(callback) abort dict
  if !self.isRunning()
    throw 'suggest-manager-running: instance is not running'
  elseif self.isReady()
    call a:callback('ready')
  else
    call add(self.oneshots, a:callback)
  endif
endfunction

" Get the project directory responsible by the instance
function! s:SuggestInstance.project() abort dict
  return fnamemodify(self.file, ':h')
endfunction

function! s:instanceHandler(chan, line, stream) abort dict
  let scoped = {}
  function scoped.doOneshot(event) abort
    if !empty(self.oneshots)
      for F in self.oneshots
        call F(a:event)
      endfor
      let self.oneshots = []
    endif
  endfunction
  let scoped.doOneshot = function(scoped.doOneshot, self)

  if a:stream == 'stdout' && self.port == 0
    let self.port = str2nr(a:line)
    call self.callback('ready', '')
    call scoped.doOneshot('ready')
    return
  elseif a:stream == 'stderr' && self.port == 0 && a:line =~ '^Cannot open file:'
    call self.callback('error', 'suggest-manager-file: file cannot be opened by nimsuggest')
    return
  elseif a:stream == 'exit'
    let self.job = 0
    let self.port = 0
    call scoped.doOneshot('exit')
  endif
  call self.callback(a:stream, a:line)
endfunction

" Creates a new nimsuggest instance
" config: NimsuggestConfig
" file: /path/to/file, can be relative to the cwd, must be available on disk
" callback: function(event, message) dict:
"   event == 'ready'  => nimsuggest has been initialized and connections can
"                        now be established
"   event == 'error'  => message will be a String following the
"                        'suggest-manager' exeception format described above.
"                        After an error event callback, an exit callback
"                        should soon follow
"   event == 'stdout' => message will be the latest line emitted by
"            'stderr'    nimsuggest to stdout/stderr (note: processed lines
"                        will not be relayed)
"   event == 'exit'   => message will be the exit code of nimsuggest
"
" See the result variable below for the returned Dict. It's not advised to
" edit the dict without using the functions in this file.
function! nim#suggest#manager#NewInstance(config, file, callback) abort
  let help = system([a:config.nimsuggest, '--help'])
  if help !~ '--autobind'
    throw 'suggest-manager-compat: only nimsuggest >= 0.20.0 is supported'
  endif

  let result = {'job': 0,
      \         'port': 0,
      \         'file': fnamemodify(a:file, ':p'),
      \         'cmd': a:config.nimsuggest,
      \         'args': ['--autobind', '--address:localhost'] + a:config.extraArgs,
      \         'on_stdout': nim#suggest#utils#BufferNewline(function('s:instanceHandler')),
      \         'on_stderr': nim#suggest#utils#BufferNewline(function('s:instanceHandler')),
      \         'on_exit': nim#suggest#utils#BufferNewline(function('s:instanceHandler')),
      \         'callback': a:callback,
      \         'oneshots': []}
  call extend(result, s:SuggestInstance)

  call result.start()
  return result
endfunction
