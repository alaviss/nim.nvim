autocmd BufNewFile,BufReadPost *.nim,*.nims,*.nimble setfiletype nim
autocmd BufNewFile,BufReadPost,BufWritePost,TextChanged,TextChangedI,TextChangedP *.nim
      \ if (!exists('SessionLoad') || !SessionLoad) &&
      \    !empty(nim#suggest#ProjectFindOrStart()) |
      \ call nim#suggest#highlight#HighlightBuffer() |
      \ endif
