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
"   'autofind': v:true (attempt to find the actual project file)
" }
"
" exception 'suggest-manager-':
"   'compat': regarding compatibility with nimsuggest
"   'running': regarding an instance 'running' state
"   'ready': regarding an instance 'ready' state
"   'exec': regarding execution of an external program
"   'file': regarding files
"   'connect': regarding connection

" Checks if the given instance is running.
function! s:instance_isRunning() abort dict
  return self.job != 0
endfunction

" Checks if the given instance can receive connections.
function! s:instance_isReady() abort dict
  return self.job != 0 && self.port != 0
endfunction

" Starts the instance, can also be used to restart a dead instance.
function! s:instance_start() abort dict
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
function! s:instance_stop() abort dict
  if self.isRunning()
    call jobstop(self.job)
  endif
endfunction

function s:message_sendmsg(env, nothrow) abort dict
  try
    let channel = sockconnect('tcp', 'localhost:' . self.port, a:env.opts)
  catch
    if a:nothrow
      call a:env.opts.on_data(0, [''], 'data')
      return
    else
      throw 'suggest-manager-connect: unable to connect to nimsuggest'
    endif
  endtry
  call chansend(channel, a:env.data)
endfunction

function s:message_onReady(env, event) abort dict
  if a:event == 'ready'
    call call(function('s:message_sendmsg'), [a:env, v:true], self)
  else
    call a:env.opts.on_data(0, [''], 'data')
  endif
endfunction
" Messages the instance asynchronously.
"
" This function is a convenience wrapper around the editor's tcp messaging
" functions that connect to and send the specified message to the instance. It
" does not attempt to provide an abstraction layer over the editor's
" facilities, so mandatory arguments will be interpreted differently
" between editors.
"
" It might take a while for the instance to become ready. If immediate result
" is wanted, pass v:true as the third argument.
"
" data: See ':h chansend' on neovim
" opts: See ':h sockconnect' on neovim
" mustReady (optional): Throw if instance is not ready
"
" If the instance died before message can be sent, `on_data` will be called with
" on_data(0, [''], 'data').
"
" Will throw if instance is not running.
function! s:instance_message(data, opts, ...) abort dict
  let mustReady = a:0 >= 1 ? a:1 : v:false
  let env = {
  \   'data': a:data,
  \   'opts': a:opts
  \}

  if !self.isReady()
    if !mustReady
      call self.addCallback(function('s:message_onReady', [env], self))
    elseif !self.isRunning()
      throw 'suggest-manager-running: instance is not running'
    else
      throw 'suggest-manager-ready: instance is not ready'
    endif
  else
    call call(function('s:message_sendmsg'), [env, v:false], self)
  endif
endfunction

" Set a callback to be called when the instance is ready. The callback will
" also be called if the instance died.
"
" callback: function(event)
"   event => 'ready': Instance is ready
"   event => 'exit': Instance didn't finish initializing and exited
function! s:instance_addCallback(callback) abort dict
  if !self.isRunning()
    throw 'suggest-manager-running: instance is not running'
  elseif self.isReady()
    call a:callback('ready')
  else
    call add(self.oneshots, a:callback)
  endif
endfunction

" Get the project directory responsible by the instance
function! s:instance_project() abort dict
  return fnamemodify(self.file, ':h')
endfunction

" Given a path, check if it's covered by the current nimsuggest instance
function! s:instance_contains(path) abort dict
  let path = isdirectory(a:path) ? fnamemodify(a:path, ':p') : fnamemodify(a:path, ':p:h')
  return path =~ '\V\^' . escape(self.project(), '\')
endfunction

" Helper functions for query()
function s:query_cleanup() abort dict
  if !empty(self.dirtyFile)
    call delete(self.dirtyFile)
  endif
  call self.opts.on_data([])
endfunction

function s:query_on_data(chan, line, stream) abort dict
  if empty(a:line)
    call chanclose(a:chan)
    call self.cleanup()
  else
    call self.opts.on_data(split(trim(a:line), '\t', v:true))
  endif
endfunction
" Send a query to the instance.
"
" command: A command string for nimsuggest (ie. 'highlight', 'sug', 'def', etc.)
" opts: {
"   'on_data': function(reply) [dict]: Will be called for every reply from
"                                      nimsuggest. Each reply will be a List
"                                      splitted by '\t' and passed to the
"                                      callback. An empty list means end of
"                                      response. The callback will also be
"                                      called with an empty list if nimsuggest
"                                      died before it was ready.
"   'buffer' (optional): The number of the buffer containing the file used for
"                        the query. If not exist will be populated with the
"                        current buffer number.
"   'pos' (optional): [lnum, col]: The cursor position, if not available will
"                                  not be passed to nimsuggest.
" }
" mustReady (optional): Throw if instance is not ready.
"
" It might take a while before the instance can be ready. If an immediate
" answer is required, pass v:true as the third parameter.

" Will throw if instance is not running.
function! s:instance_query(command, opts, ...) abort dict
  let mustReady = a:0 >= 1 ? a:1 : v:false
  if !has_key(a:opts, 'buffer')
    let a:opts['buffer'] = bufnr('')
  endif

  let invalidChars = '"\|\n\|\r'
  let filename = bufname(a:opts.buffer)
  if filename =~ invalidChars
    throw 'suggest-manager-file: unsupported character in path to file'
  endif
  let dirtyFile = ''
  let fileQuery = '"' . filename . '"'
  if getbufvar(a:opts.buffer, '&modified')
    let dirtyFile = tempname()
    " shouldn't happen, but doesn't hurt to check
    if dirtyFile =~ invalidChars
      throw 'suggest-manager-file-internal: unsupported character in path to dirty file'
    endif
    let fileQuery .= ';' . dirtyFile
    call writefile(getbufline(a:opts.buffer, 1, '$'), dirtyFile, 'S')
  endif
  if has_key(a:opts, 'pos')
    let fileQuery .= ':' . a:opts.pos[0] . ':' . (a:opts.pos[1] - 1)
  endif

  let opts = {
  \   'opts': a:opts,
  \   'dirtyFile': dirtyFile,
  \   'cleanup': function('s:query_cleanup')
  \}

  let opts.on_data = nim#suggest#utils#BufferNewline(function('s:query_on_data'))
  try
    call self.message([a:command . ' ' . fileQuery, ''], opts, mustReady)
  catch
    call opts.cleanup()
    throw v:exception
  endtry
endfunction

function! s:doOneshot(event) abort dict
  if !empty(self.oneshots)
    for F in self.oneshots
      call F(a:event)
    endfor
    let self.oneshots = []
  endif
endfunction

function! s:instanceHandler(chan, line, stream) abort dict
  if a:stream == 'stdout' && self.port == 0
    let self.port = str2nr(a:line)
    call self.cb('ready', '')
    call call(function('s:doOneshot'), ['ready'], self)
    return
  elseif a:stream == 'stderr' && self.port == 0 && a:line =~ '^cannot find file:'
    call self.cb('error', 'suggest-manager-file: file cannot be opened by nimsuggest')
    return
  elseif a:stream == 'exit'
    let self.job = 0
    let self.port = 0
    call call(function('s:doOneshot'), ['exit'], self)
  endif
  call self.cb(a:stream, a:line)
endfunction

function! s:findProjectMain(path) abort
  let current = a:path
  let prev = current
  let pkg = fnamemodify(a:path, ':t')
  let candidates = []

  let nimblepkg = ''
  while v:true
    " arcane magic to make sure that the path seperator appear at the end
    let esccur = fnameescape(fnamemodify(current, ':p'))
    let escprv = fnameescape(fnamemodify(prev, ':p'))
    let configs = []
    for ext in ['*.nims', '*.cfg', '*.nimcfg', '*.nimble']
      call extend(configs, glob(esccur . ext, v:true, v:true))
    endfor

    for f in configs
      if f == 'config.nims'
        continue
      elseif fnamemodify(f, ':e') == 'nimble'
        if empty(nimblepkg)
          let nimblepkg = fnamemodify(f, ':t:r')
        else
          " more than one nimble file found, don't trust the result
          return ''
        endif
      endif
      let candidate = fnamemodify(f, ':t:r')
      if fnamemodify(candidate, ':e') != 'nim'
        let candidate .= '.nim'
      endif
      let candidate = fnameescape(candidate)
      for i in current != a:path && !empty(nimblepkg) ? [esccur, escprv] : [esccur]
        call extend(candidates, glob(i . candidate, v:true, v:true))
      endfor
    endfor

    for f in candidates
      let fname = fnamemodify(f, ':t')
      if stridx(fname, !empty(nimblepkg) ? nimblepkg : pkg) != -1
        return f
      endif
    endfor
    if !empty(candidates)
      return candidates[0]
    endif
    let prev = current
    let current = fnamemodify(current, ':h')
    if prev == current
      return ''
    endif
  endwhile
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
  if v:shell_error == -1
    throw 'suggest-manager-exec: nimsuggest (' . a:config.nimsuggest . ') cannot be executed'
  elseif help !~ '--autobind'
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
      \         'cb': a:callback,
      \         'oneshots': [],
      \         'isRunning': function('s:instance_isRunning'),
      \         'isReady': function('s:instance_isReady'),
      \         'start': function('s:instance_start'),
      \         'stop': function('s:instance_stop'),
      \         'message': function('s:instance_message'),
      \         'addCallback': function('s:instance_addCallback'),
      \         'project': function('s:instance_project'),
      \         'contains': function('s:instance_contains'),
      \         'query': function('s:instance_query')}

  if !has_key(a:config, 'autofind') || a:config.autofind
    let projectFile = s:findProjectMain(result.project())
    if !empty(projectFile)
      let result.file = projectFile
    endif
  endif

  call result.start()
  return result
endfunction
