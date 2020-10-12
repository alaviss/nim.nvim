" functions used for go-to-definition feature
"
" Copyright 2019 Leorize <leorize+oss@disroot.org>
"
" Licensed under the terms of the ISC license,
" see the file "license.txt" included within this distribution.

function! s:setCloseOnMove(win) abort
  augroup nim_nvim_sig_tooltip_autoclose
    execute 'autocmd BufEnter,CursorMoved,CursorMovedI,InsertEnter * ++once call <SID>closeWin(' . a:win . ')'
  augroup END
endfunction

function! s:closeWin(win) abort
  if win_getid() is a:win
    call s:setCloseOnMove(a:win)
    return
  endif
  let buf = winbufnr(a:win)
  if buf isnot -1
    execute 'bwipeout ' . buf
  endif
endfunction

function! s:type_handler(reply) abort dict
  for i in a:reply
    let i = split(i, '\t', v:true)
    if !self.done && nvim_win_is_valid(self.window)
      if i[0] is# 'def' && !empty(i[3])
        let signature = i[2] . ': ' . i[3]
        let scratch = nvim_create_buf(v:false, v:true)
        call nvim_buf_set_lines(scratch, 0, -1, v:true, [signature])
        call nvim_buf_set_option(scratch, 'modifiable', v:false)
        call nvim_buf_set_option(scratch, 'filetype', 'nim')
        let float = nvim_open_win(
        \   scratch,
        \   v:false,
        \   {
        \     'relative': 'win',
        \     'win': self.window,
        \     'height': 1,
        \     'width': strdisplaywidth(signature),
        \     'bufpos': map(self.pos, 'v:val - 1'),
        \     'style': 'minimal'
        \   }
        \)
        call s:setCloseOnMove(float)
        let self.done = v:true
        break
      endif
    endif
  endfor
endfunction

function! s:doc_cleanup() abort dict
  call nvim_tabpage_set_var(self.tabpage, 'nimSugPreviewLock', v:false)
endfunction

function! s:doc_handler(reply) abort dict
  for i in a:reply
    let i = split(i, '\t', v:true)
    if !self.done && nvim_tabpage_is_valid(self.tabpage)
      if i[0] is# 'def'
        if len(i[7]) > 2
          let docs = split(trim(eval(i[7])), '\n')
          let signature = i[2] . ': ' . i[3]
          let title = 'Documentation for symbol: ' . signature
          let scratch = bufnr(title)
          if scratch is -1
            let scratch = nvim_create_buf(v:false, v:true)
            call nvim_buf_set_lines(scratch, 0, -1, v:true, docs)
            call nvim_buf_set_option(scratch, 'modifiable', v:false)
            call nvim_buf_set_option(scratch, 'filetype', 'rst')
            call nvim_buf_set_option(scratch, 'bufhidden', 'wipe')
            call nvim_buf_set_name(scratch, title)
            call nvim_set_current_tabpage(self.tabpage)
            execute 'pedit +buffer\ ' . scratch
          endif
          let self.done = v:true
          break
        endif
      endif
    endif
  endfor
endfunction

function! s:goto_cleanup() abort dict
  if self.defIdx isnot 0 && nvim_win_is_valid(self.window)
    let oldSwb = &switchbuf
    let &switchbuf = 'useopen'
    if self.openIn is# 'v'
      let &switchbuf = 'vsplit'
    elseif self.openIn is# 's'
      let &switchbuf = 'split'
    endif
    call win_gotoid(self.window)
    if self.defIdx > 1
      lopen
    endif
    execute 'll ' . self.defIdx
    let &switchbuf = oldSwb
    call settabwinvar(0, self.window, 'nimSugDefLock', v:false)
    call settabwinvar(0, self.window, 'nimSugLocListLock', v:false)
  endif
endfunction

function! s:goto_handler(reply) abort dict
  for i in a:reply
    let i = split(i, '\t', v:true)
    if nvim_win_is_valid(self.window)
      if i[0] is# 'def'
        let signature = i[2]
        let file = i[4]
        let lnum = str2nr(i[5])
        let col = str2nr(i[6]) + 1
        if self.firstReply
          call setloclist(self.window, [], ' ',
               \          {'title': 'Declarations of symbol: ' . signature})
          let self.firstReply = v:false
        endif
        call setloclist(self.window,
             \          [{
             \            'filename': file,
             \            'lnum': lnum,
             \            'col': col,
             \            'text': nim#suggest#utils#GetLine(file, lnum)
             \          }],
             \          'a'
             \         )
        let self.defIdx += 1
      endif
    endif
  endfor
endfunction

" Go to the definition of the symbol under the cursor.
"
" openIn:
"   's'  => Use `split` to open the target buffer.
"   'v'  => Use `vsplit` to open the target buffer.
"   else => Use `edit` to open the target buffer. If the current buffer
"           contains the definition, the cursor will be moved to the target
"           position instead.
"
" This is a motion function.
"
" If an another GoTo() is being done for the current window, no action
" will be made. Additionally, if the window is destroyed before GoTo()
" completes, no action will be made.
"
" This is an user-facing function, thus no errors will be thrown, instead they
" are displayed as messages.
function! nim#suggest#def#GoTo(openIn) abort
  if exists('w:nimSugDefLock') && w:nimSugDefLock
    return
  endif
  let opts = {'on_data': function('s:goto_handler'),
      \       'on_end': function('s:goto_cleanup'),
      \       'window': win_getid(),
      \       'openIn': a:openIn,
      \       'pos': getcurpos()[1:2],
      \       'firstReply': v:true,
      \       'defIdx': 0}
  let w:nimSugDefLock = v:true
  let w:nimSugLocListLock = v:true
  call setloclist(opts.window, [], ' ')
  call nim#suggest#utils#Query('def', opts, v:false, v:true)
endfunction

" Display the type of the symbol under the cursor.
"
" If the editor supports floating windows, it will be used to display the
" type, otherwise a message will be printed.
function! nim#suggest#def#ShowType() abort
  let opts = {'on_data': function('s:type_handler'),
      \       'window': win_getid(),
      \       'pos': [line('.'), nim#suggest#utils#FindIdentifierStart()],
      \       'done': v:false}
  call nim#suggest#utils#Query('def', opts, v:false, v:true)
endfunction

" Display the documentations of the symbol under the cursor in the preview
" window.
"
" No action will be made if the symbol contains no documentation, or if
" another instance of ShowDoc() is running in the current tabpage.
"
" The function will switch to the tabpage at the time of invocation before
" opening the preview window.
function! nim#suggest#def#ShowDoc() abort
  if !exists('t:nimSugPreviewLock') || !t:nimSugPreviewLock
    let t:nimSugPreviewLock = v:true
    let opts = {'on_data': function('s:doc_handler'),
        \       'on_end': function('s:doc_cleanup'),
        \       'tabpage': nvim_get_current_tabpage(),
        \       'pos': getcurpos()[1:2],
        \       'done': v:false}
    call nim#suggest#utils#Query('def', opts, v:false, v:true)
  endif
endfunction
