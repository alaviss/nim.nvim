autocmd BufNewFile,BufReadPost *.nim,*.nims,*.nimble setfiletype nim

function s:updateSemanticHighlight() abort
  if (!exists('SessionLoad') || !SessionLoad) &&
    \ !empty(nim#suggest#ProjectFindOrStart())
    if get(b:, 'nim_last_changed', -1) != b:changedtick
      call nim#suggest#highlight#HighlightBuffer()
      let b:nim_last_changed = b:changedtick
    endif
  endif
endfunction

autocmd BufNewFile,BufReadPost,BufWritePost *.nim
\ call s:updateSemanticHighlight()

if get(g:, 'nim_highlight_wait', v:false)
  autocmd CursorHold,CursorHoldI,InsertEnter,InsertLeave *.nim
  \ call s:updateSemanticHighlight()
else
  autocmd TextChanged,TextChangedI,TextChangedP *.nim
  \ call s:updateSemanticHighlight()
endif
