function nim#SearchIdentifierRegex(ident)
  " creates a regex that can match style-insensitive identifiers
  let i = 0
  let result = '\V\C'
  while i < len(a:ident)
    let c = a:ident[i]
    let underscore = i < len(a:ident) - 1 ? '_\?' : ''
    if i == 0 && c =~ '\a'
      let result .= escape(c, '\/ ') . underscore
    elseif c == '_'
      let result .= ''
    elseif c =~ '\k'
      let result .= '\%('. tolower(c) . '\|' . toupper(c) . '\)' . underscore
    else
      let result .= escape(i, '\/ ')
    endif
    let i += 1
  endwhile
  return result
endfunction

function nim#StarSearchRegex()
  " creates a regex that matches like how the * operator work
  " if no match could be found, an empty regex is returned
  let line = getline('.')
  let start = col('.') - 1
  while start > 0 && line[start] =~ '\k\|\w'
    let start -= 1
  endwhile
  let match = matchstrpos(line, '\a\k*', start)
  if match[0] == ''
    return ''
  endif
  let synName = synIDattr(synID(line('.'), match[1] + 1, v:true), "name")
  if synName != '' && synName !~ '\(Comment\|String\|nimCharacter\)$'
    return '\V' . match[0]
  else
    return nim#SearchIdentifierRegex(match[0])
  endif
endfunction
