autocmd BufNewFile,BufRead *.nim,*.nims,*.nimble setfiletype nim
autocmd BufEnter,BufWritePost,InsertLeave,TextChanged,TextChangedI *.nim
      \ if (!exists('SessionLoad') || !SessionLoad) &&
      \    !empty(nim#suggest#ProjectFindOrStart()) |
      \ call nim#suggest#highlight#HighlightBuffer() |
      \ endif
