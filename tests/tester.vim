let g:test_exit = 0

function! ParseTests() abort
  " result: [# test no.] = { position: [lnum, col], expected: int }
  let result = []
  let numRegex = '-\?\d\+'
  call cursor(1, 1)
  while search('#!\s*' . numRegex, 'zW') != 0
    let pos = getcurpos()
    let line = getline('.')
    let test = {'position': [pos[1], pos[2]],
        \       'expected': str2nr(matchstr(line, numRegex)),
        \       'disabled': line =~ ('#!\s*' . numRegex . '\s\+disabled')}
    call add(result, test)
  endwhile
  return result
endfunction

function! RunTests() abort
  let tests = ParseTests()
  for t in tests
    let posStr = bufname('') . '(' . t.position[0] . ', ' . t.position[1] . '): '
    if t.disabled
      echomsg posStr . 'skipped'
      continue
    endif
    let indent = GetNimIndent(t.position[0])
    if indent != t.expected
      echomsg posStr . 'expected ' . t.expected . ' but got ' . indent
      let g:test_exit = 1
    else
      echomsg posStr . 'OK'
    endif
  endfor
endfunction
