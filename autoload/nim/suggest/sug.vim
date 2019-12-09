let s:sugToCompleteType = {'skProc': 'f', 'skFunc': 'f', 'skMethod': 'f',
    \                      'skType': 't', 'skVar': 'v', 'skLet': 'v',
    \                      'skConst': 'd', 'skResult': 'v', 'skIterator': 'f',
    \                      'skConverter': 'd', 'skMacro': 'd', 'skTemplate': 'd',
    \                      'skField': 'm', 'skEnumField': 'm', 'skForVar': 'v',
    \                      'skUnknown': '', 'skParam': 'v'}

function! s:findStartingPosition(line, start) abort
  let result = a:start - 1
  while result > 0 && a:line[result - 1] =~ '\k'
    let result -= 1
  endwhile
  return result + 1
endfunction

" Get completion candidates for ident under cursor asynchronously, one-by-one.
"
" callback: function(startpos, complete-item) where:
"   startpos is the starting byte of the ident to be completed.
"   complete-item is a Dict as described in :h complete-items. Once all
"   results are returned, the callback will be invoked with an empty Dict.
"
" As this function is designed to easily compose with asynchronous completion
" frameworks, it does not return nor throw. Errors are displayed to the user
" as messages. However, this might change in the future.
function! nim#suggest#sug#GetCandidates(callback) abort
  let pos = getcurpos()[1:2]
  let startpos = s:findStartingPosition(getline('.'), pos[1])
  let opts = {'on_data': function('s:on_data'),
      \       'callback': function(a:callback, [startpos]),
      \       'pos': pos}
  call nim#suggest#utils#Query('sug', opts)
endfunction

function! s:on_data(reply) abort dict
  if empty(a:reply)
    call self.callback({})
  elseif a:reply[0] == 'sug'
    let result = {'word': split(a:reply[2], '\i\.\zs')[-1],
        \         'menu': a:reply[3],
        \         'info': len(a:reply[7]) > 2 ? eval(a:reply[7]) : ' ',
        \         'icase': 1,
        \         'dup': 1}
    try
      let result.kind = s:sugToCompleteType[a:reply[1]]
    catch
      echomsg 'suggest-sug: error: unknown symbol kind ''' . a:reply[1] . ''''
    endtry
    call self.callback(result)
  endif
endfunction

" Get all completion candidates asynchronously.
"
" Similar to GetCandidates(), but the callback will be invoked with a list of
" complete-item instead.
function! nim#suggest#sug#GetAllCandidates(callback) abort
  let items = []
  let scoped = {}
  function scoped.accumulator(startpos, candidate) abort closure
    if !empty(a:candidate)
      call add(items, a:candidate)
    else
      call a:callback(a:startpos, items)
    endif
  endfunction
  call nim#suggest#sug#GetCandidates(scoped.accumulator)
endfunction
