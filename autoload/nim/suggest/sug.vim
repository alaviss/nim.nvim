let s:sugToCompleteType = {'skProc': 'f', 'skFunc': 'f', 'skMethod': 'f',
    \                      'skType': 't', 'skVar': 'v', 'skLet': 'v',
    \                      'skConst': 'd', 'skResult': 'v', 'skIterator': 'f',
    \                      'skConverter': 'd', 'skMacro': 'd', 'skTemplate': 'd',
    \                      'skField': 'm', 'skEnumField': 'm', 'skForVar': 'v',
    \                      'skUnknown': ''}

function! s:FindStartingPosition(line, start)
  let result = a:start - 1
  while result > 0 && a:line[result - 1] =~ '\i'
    let result -= 1
  endwhile
  return result + 1
endfunction

function! s:OnReply(reply) dict
  if a:reply[0] != 'sug'
    return
  endif

  let result = {'word': split(a:reply[2], '\i\.\zs')[-1],
      \         'menu': a:reply[3],
      \         'info': len(a:reply[7]) > 2 ? eval(a:reply[7]) : ' ',
      \         'icase': 1}
  if has_key(s:sugToCompleteType, a:reply[1])
    let result.kind = s:sugToCompleteType[a:reply[1]]
  endif
  call self.callback(result, v:false)
endfunction

function! s:OnEnd() dict
  call self.callback({}, v:true)
  if !empty(self.dirty)
    call delete(self.dirty)
  endif
endfunction

function! nim#suggest#sug#GetCompletions(callback)
  " callback(startpos, complete-item, completed) for every candidate found
  let current = nim#suggest#FindInstance()
  if empty(current)
    echomsg 'nimsuggest is not running for this project'
    return
  endif
  if current.instance.port == -1
    echomsg 'nimsuggest is not ready for this project, try again later'
    return
  endif
  let cursor = getcurpos()[1:2]
  let startpos = s:FindStartingPosition(getline('.'), cursor[1])
  let fileQuery = nim#suggest#utils#MakeFileQuery(bufnr(''), cursor[0], cursor[1])
  let connOpts = {'on_data': v:null,
      \           'onReply': function('s:OnReply'),
      \           'onEnd': function('s:OnEnd'),
      \           'buf': [''],
      \           'callback': function(a:callback, [startpos]),
      \           'dirty': fileQuery.dirty}
  let connOpts.on_data = function('nim#suggest#utils#BufferedCallback', connOpts)
  let chan = nim#suggest#Connect(current.instance, connOpts)
  if chan == 0
    echomsg '[nim#suggest#sug] Unable to connect to nimsuggest'
    if !empty(fileQuery.dirty)
      call delete(fileQuery.dirty)
    endif
    return
  endif
  call chansend(chan, ['sug ' . fileQuery.query, ''])
endfunction

function! nim#suggest#sug#GetAllCandidates(callback)
  " callback(startpos, [complete-items])
  let items = []
  function! Accumulator(startpos, candidate, finished) closure
    if !a:finished
      call add(items, a:candidate)
    else
      call a:callback(a:startpos, items)
    endif
  endfunction
  call nim#suggest#sug#GetCompletions(function('Accumulator'))
endfunction
