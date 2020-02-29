let s:sugToCompleteType = {'skProc': 'f', 'skFunc': 'f', 'skMethod': 'f',
    \                      'skType': 't', 'skVar': 'v', 'skLet': 'v',
    \                      'skConst': 'd', 'skResult': 'v', 'skIterator': 'f',
    \                      'skConverter': 'd', 'skMacro': 'd', 'skTemplate': 'd',
    \                      'skField': 'm', 'skEnumField': 'm', 'skForVar': 'v',
    \                      'skUnknown': '', 'skParam': 'v', 'skGenericParam': 't'}

" Get completion candidates for ident under cursor asynchronously.
"
" callback: function(startpos, complete-items) where:
"   startpos is the starting cursor column of the ident to be completed.
"   complete-items is as described in :h complete-items. The results will be
"   passed by chunks as they are made available. Once all results are received
"   v:null will be passed as complete-items
"
" As this function is designed to easily compose with asynchronous completion
" frameworks, it does not return nor throw. Errors are displayed to the user
" as messages. However, this might change in the future.
function! nim#suggest#sug#GetCandidates(callback) abort
  let pos = getcurpos()[1:2]
  let startpos = nim#suggest#utils#FindIdentifierStart()
  let opts = {'on_data': function('s:on_data'),
      \       'on_end': function('s:on_end'),
      \       'callback': function(a:callback, [startpos]),
      \       'pos': pos}
  call nim#suggest#utils#Query('sug', opts)
endfunction

function! s:on_end() abort dict
  call self.callback(v:null)
endfunction

function! s:on_data(reply) abort dict
  let result = []
  for i in a:reply
    let i = split(i, '\t', v:true)
    if i[0] is# 'sug'
      call add(result,
           \   {'word': split(i[2], '\i\.\zs')[-1],
           \    'menu': i[3],
           \    'info': len(i[7]) > 2 ? trim(eval(i[7])) : ' ',
           \    'icase': 1,
           \    'dup': 1})
      if has_key(s:sugToCompleteType, i[1])
        let result[-1].kind = s:sugToCompleteType[i[1]]
      else
        " it still works without kind, so we just pop a warning and pray that
        " people actually look at it to report.
        echomsg 'suggest-sug: error: unknown symbol kind ''' . i[1] . ''''
      endif
    endif
  endfor
  if len(result) > 0
    call self.callback(result)
  endif
endfunction

" Helper for GetAllCandidates
function s:accumulator(cb, buf, startpos, candidates) abort
  if a:candidates isnot v:null
    call extend(a:buf, a:candidates)
  else
    call a:cb(a:startpos, a:buf)
  endif
endfunction

" Get all completion candidates asynchronously.
"
" Similar to GetCandidates(), but buffers complete-items and only invoke the
" callback when all results are received.
function! nim#suggest#sug#GetAllCandidates(callback) abort
  call nim#suggest#sug#GetCandidates(function('s:accumulator', [a:callback, []]))
endfunction
