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
endfunction

function! nim#suggest#sug#GetCompletions(callback)
  " callback(startpos, complete-item, completed) for every candidate found
  let cursor = getcurpos()[1:2]
  let startpos = s:FindStartingPosition(getline('.'), cursor[1])
  let opts = {'onReply': function('s:OnReply'),
      \       'onEnd': function('s:OnEnd'),
      \       'callback': function(a:callback, [startpos])}
  call nim#suggest#utils#Query(bufnr(''), cursor[0], cursor[1], 'sug', opts, v:false)
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
