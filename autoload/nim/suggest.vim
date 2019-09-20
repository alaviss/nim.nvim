" nimsuggest management routines
"
" Copyright 2019 Leorize <leorize+oss@disroot.org>
"
" Licensed under the terms of the ISC license,
" see the file "license.txt" included within this distribution.

" NOTE: Don't depend too much on the APIs provided in this file, they are
" subjected to future breaking changes.

let s:instances = {}
let s:config = {'nimsuggest': 'nimsuggest', 'extraArgs': []}

function! s:findProjectInstance(dir)
  if empty(a:dir)
    return ''
  endif
  let result = ''
  let matchingRegex = '\V\^' . escape(a:dir, '\')
  for key in keys(s:instances)
    if a:dir =~ matchingRegex && strlen(key) > strlen(result)
      let result = key
    endif
  endfor
  return result
endfunction

function! nim#suggest#FindInstance(...)
  let project = a:0 >= 1 ? fnamemodify(a:1, ':p:h') : expand('%:p:h')
  let project = s:findProjectInstance(project)
  if empty(project)
    return {}
  endif
  return s:instances[project]
endfunction

function! s:onEvent(event, message) abort dict
  if a:event == 'error' && a:message =~ '^suggest-manager-file'
    echomsg 'nimsuggest is only available to files on disk'
    unlet s:instances[self.project()]
  elseif a:event == 'exit' && a:message != 0 && has_key(s:instances, self.project())
    echomsg 'nimsuggest instance for project' self.project()
    \       'stopped with exitcode:' a:message
  endif
endfunction

function! nim#suggest#ProjectFileStart(file)
  let project = fnamemodify(a:file, ':p:h')
  if has_key(s:instances, project) && s:instances[project].isRunning()
    echomsg 'An instance of nimsuggest has already been started for this project'
    return s:instances[project]
  endif
  try
    let s:instances[project] = nim#suggest#manager#NewInstance(s:config, a:file, function('s:onEvent'))
  catch
    call nim#suggest#utils#PrintException()
    return {}
  endtry
  return s:instances[project]
endfunction

function! nim#suggest#ProjectStart()
  return nim#suggest#ProjectFileStart(expand('%'))
endfunction

function! nim#suggest#ProjectStop()
  let instance = nim#suggest#FindInstance()
  call instance.stop()
endfunction

function! nim#suggest#ProjectStopAll()
  for project in keys(s:instances)
    call s:instances[project].stop()
  endfor
endfunction

function! nim#suggest#ProjectFindOrStart()
  let project = expand('%:p:h')
  let project = s:findProjectInstance(project)
  if empty(project)
    return nim#suggest#ProjectStart()
  endif
  let inst = s:instances[project]
  if !inst.isRunning()
    try
      call inst.start()
    catch
      call nim#suggest#utils#PrintException()
    endtry
  endif
  return inst
endfunction
