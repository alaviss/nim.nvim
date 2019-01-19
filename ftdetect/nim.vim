autocmd BufNewFile,BufRead *.nim,*.nims,*.nimble setfiletype nim
autocmd BufEnter,BufWritePost,InsertLeave,TextChanged,TextChangedI *.nim
      \ call nim#suggest#ProjectFindOrStart() |
      \ call nim#suggest#highlight#HighlightBuffer()
