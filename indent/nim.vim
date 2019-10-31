" Vim indent plugin
" Language: Nim
" Author:   Leorize

if exists("b:did_indent")
  finish
endif
let b:did_indent = v:true

setlocal autoindent
setlocal indentexpr=GetNimIndent(v:lnum)
setlocal indentkeys=!^F,o,O,<:>,{,),],},=el,=of

if exists("*GetNimIndent")
    finish
endif

function s:binaryLook(min, max, cond)
    if a:min < a:max
      let pos = (a:min + a:max) / 2
      if a:cond(pos)
        return s:binaryLook(a:min, pos, a:cond)
      else
        return s:binaryLook(pos + 1, a:max, a:cond)
      endif
    else
      return a:min
    endif
endfunction

function s:prevNonEmptyNorComments(lnum)
    let prevNonEmpty = prevnonblank(a:lnum)
    " Drop the line if it's filled with comments
    if !(getline(prevNonEmpty) =~ '^\s*#[') &&
          \ (getline(prevNonEmpty) =~ '^\s*#')
      return s:prevNonEmptyNorComments(prevNonEmpty - 1)
    else
      return prevNonEmpty
    endif
endfunction

function s:getLineNoComments(lnum)
    let line = getline(a:lnum)
    let lineLen = strlen(line)
    let result = line
    if synIDattr(synID(a:lnum, lineLen, v:true), "name") =~
          \ '\(Comment\|Todo\)$'
      let result = strpart(line, 0,
           \               s:binaryLook(1, lineLen,
           \                            {x -> synIDattr(
           \                                    synID(a:lnum, x, v:true), "name") =~
           \                            '\(Comment\|Todo\)$'}) - 1)
    endif
    return substitute(result, '\s\+$', '', '')
endfunction

let s:ParenStartDot = '(\.\|{\.\|[\.'
let s:ParenStart = s:ParenStartDot . '\|(\|{\|['
let s:ParenStopDot = '\.)\|\.}\|\.\]'
let s:ParenStop = s:ParenStopDot . '\|)\|}\|\]'

function s:lookupBaseParen(lnum, ...)
    let skipExpr = "synIDattr(synID(line('.'), col('.'), v:false), 'name') =~ '\\(Comment\\|String\\|nimCharacter\\)$'"
    let startPat = a:0 >= 1 ? a:1 : s:ParenStart
    let stopPat = a:0 >= 2 ? a:2 : s:ParenStop
    let lookOuter = a:0 >= 3 ? a:3 : v:false
    let moveCursor = a:0 >= 4 ? a:4 : v:true

    " look for the outermost paren
    if lookOuter
      if moveCursor
        call cursor(a:lnum, col([a:lnum, '$']))
      endif
      " 1ms timeout
      let closePos = searchpos(stopPat, 'bcnW', 0, 1)
      if closePos[0] == a:lnum
        call cursor(closePos)
      else
        call cursor(a:lnum, 1)
      endif
    elseif moveCursor
      call cursor(a:lnum, 1)
    endif
    " timeout in 2ms to ensure smooth typing experience
    let parenPos = searchpairpos(startPat, '', stopPat, 'bnW',
                   \             skipExpr, 0, 2)
    return parenPos
endfunction

" For debugging purposes
function NimLookupBaseParen(lnum, outer)
  return s:lookupBaseParen(a:lnum, s:ParenStart, s:ParenStop, a:outer)
endfunction

function GetNimIndent(lnum)
    " If we're in a multi-line string or comment, don't change the indent
    if synIDattr(synID(a:lnum, 1, v:true), "name") =~ '\(Comment\|String\|nimCharacter\)$'
      return -1
    endif

    " Search backwards for a non-empty line
    let prevNonEmpty = s:prevNonEmptyNorComments(a:lnum - 1)

    if prevNonEmpty == 0
      " No indent for the first line
      return 0
    endif

    let prevNonEmptyLine = s:getLineNoComments(prevNonEmpty)
    let prevParen = s:lookupBaseParen(prevNonEmpty, s:ParenStart, s:ParenStop, v:true)
    let curParen = s:lookupBaseParen(a:lnum)
    if curParen == [0, 0]
      let curParen = s:lookupBaseParen(a:lnum, s:ParenStart, s:ParenStop, v:true)
      if curParen[0] != a:lnum
        let curParen = [0, 0]
      endif
    endif
    " we would want to reduce our indent to original level
    if prevParen == [0, 0] || prevParen == curParen
      let prevIndent = indent(prevNonEmpty)
    else
      let prevIndent = indent(prevParen[0])
    endif
    let curLine = s:getLineNoComments(a:lnum)
    let curIndent = indent(a:lnum)

    if prevNonEmptyLine =~ '\v%(\=|:)\s*$'
      " handle
      " proc test(a,
      "           b) {.pragma.} =
      "   ^
      " proc test(a,
      "           b): seq[int] =
      "   ^
      " proc test(a,
      "           b)
      "          {.pragma.} =
      "   ^
      if prevParen != [0, 0]
        if prevNonEmptyLine[prevParen[1] - 1:prevParen[1]] == '{.' ||
        \  prevNonEmptyLine[prevParen[1] - 1] == '['
          call cursor(prevParen[0], prevParen[1])
          let nonPragPrevParen = s:lookupBaseParen(prevNonEmpty, s:ParenStart, s:ParenStop, v:true, v:false)
          if nonPragPrevParen != [0, 0]
            let prevIndent = indent(nonPragPrevParen[0])
          elseif prevNonEmptyLine =~ '=\s*$' &&
          \      prevNonEmptyLine[prevParen[1] - 1:prevParen[1]] == '{.'
            let nonPragPrev = s:prevNonEmptyNorComments(prevParen[0] - 1)
            let nonPragPrevLine = s:getLineNoComments(nonPragPrev)
            if nonPragPrevLine =~ ')\s*$'
              let nonPragPrevParen = s:lookupBaseParen(nonPragPrev, '(', ')')
              if nonPragPrevParen != [0, 0]
                let prevIndent = indent(nonPragPrevParen[0])
              endif
            endif
          endif
        endif
      endif
      return prevIndent + shiftwidth()
    endif

    " Some implict blocks
    if prevNonEmptyLine =~ '^\s*\(const\|enum\|let\|type\|var\)\>\s*$' ||
          \ prevNonEmptyLine =~ '=\s*case\>.*$' ||
          \ prevNonEmptyLine =~ '=\s*\(enum\|tuple\)\>\s*$' ||
          \ prevNonEmptyLine =~ '=\s*\(ptr\|ref\)\=\s\+object\(\s\+of\s\+\a\w*\)\=\>\s*$' ||
          \ prevNonEmptyLine =~ '=\s*concept\>.*$'
      " Keep indent if the line before the block is empty
      return len(getline(a:lnum - 1)) > 0 ? prevIndent + shiftwidth() : -1
    endif

    " If the previous line was a stop-execution statement
    if prevNonEmptyLine =~ '^\s*\(\(break\|continue\|raise\)\>$\|return\)\>'
      " See if the user has already dedented
      if curIndent > prevIndent - shiftwidth()
        " Recommend one dedent
        return prevIndent - shiftwidth()
      else
        return -1
      endif
    endif

    " Dedent if current line begins with a header keyword
    if curLine =~ '^\s*\(elif\|else\|except\|finally\|of\)\>'
      " Unless the previous line was a one-liner
      " Or the user has already dedented
      " Or it's a case expression
      if (prevNonEmptyLine =~ '^\s*\(case\|if\|when\|try\|of\)\>') ||
            \ (curIndent <= prevIndent - shiftwidth())
        return -1
      else
        return prevIndent - shiftwidth()
      endif
    endif

    " Dedent paren-like structure
    " [
    "   { something }
    " ] <-- auto dedented
    if curLine =~ '^\s*\%(' . s:ParenStop . '\)$' && curParen != [0, 0]
      let end = curLine[len(curLine) - 1]
      let start = ''
      if end == ')'
        let start = '('
      elseif end == ']'
        let start = '['
      elseif end == '}'
        let start = '{'
      endif
      let parenLine = s:getLineNoComments(curParen[0])
      if len(parenLine) == curParen[1] && parenLine[curParen[1] - 1] == start
        let curParenIndent = indent(curParen[0])
        return curParenIndent < curIndent ? curParenIndent : -1
      else
        return -1
      endif
    endif

    " Special indent for pragma after proc params
    " proc p(a,
    "        b)
    "       {.noSideEffects.} <-- aligned with the proc open params
    if curLine =~ '^\s*{\.' && prevParen != [0, 0]
      let parenLine = s:getLineNoComments(prevParen[0])
      if parenLine[prevParen[1] - 1] == '('
        let result = prevParen[1] - 1
        return result < curIndent ? result : curIndent
      endif
    endif

    " Generates indent like in NEP #1:
    " proc something(a: string,
    "                ^
    if curParen[0] == prevNonEmpty
      if prevNonEmptyLine =~ '\.*\%(' . s:ParenStart . '\)$'
        " Special indent rules:
        " (
        "   indent
        "   ^
        " )
        return prevIndent + shiftwidth()
      elseif s:lookupBaseParen(a:lnum, s:ParenStartDot, s:ParenStopDot) != [0, 0]
        " Handle {.
        return curParen[1] + 1
      else
        return curParen[1]
      endif
    else
      " only use previous indent if this is the outermost level
      return curParen == [0, 0] && prevIndent < curIndent ? prevIndent : -1
    endif
endfunction
