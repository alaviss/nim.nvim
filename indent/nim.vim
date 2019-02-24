" Vim indent plugin
" Language: Nim
" Author:   Leorize

if exists("b:did_indent")
  finish
endif
let b:did_indent = v:true

setlocal autoindent
setlocal indentexpr=GetNimIndent(v:lnum)
setlocal indentkeys=!^F,o,O,<:>,=el,=of

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
    if synIDattr(synID(a:lnum, lineLen, v:true), "name") =~
          \ '\(Comments\|Todos\)$'
      return strpart(line, 0,
            \ s:binaryLook(1, lineLen,
            \              {x -> synIDattr(synID(a:lnum, x, v:true), "name") =~
            \              '\(Comments\|Todos\)$'}) - 1)
    else
      return line
    endif
endfunction

function GetNimIndent(lnum)
    " If we're in a multi-line string or comment, don't change the indent
    if synIDattr(synID(a:lnum, 1, v:true), "name") =~
          \ '\(Comments\|Strings\)$'
      return -1
    endif

    " Search backwards for a non-empty line
    let prevNonEmpty = s:prevNonEmptyNorComments(a:lnum - 1)

    if prevNonEmpty == 0
      " No indent for the first line
      return 0
    endif

    let prevNonEmptyLine = substitute(s:getLineNoComments(prevNonEmpty),
          \                           '\s\+$', '', '')
    let prevIndent = indent(prevNonEmpty)
    let curLine = getline(a:lnum)
    let curIndent = indent(a:lnum)

    if prevNonEmptyLine =~ '\v%(\=|:)\s*$'
      return prevIndent + shiftwidth()
    endif

    " Some implict blocks
    if prevNonEmptyLine =~ '^\s*\(const\|enum\|let\|type\|var\)\>\s*$' ||
          \ prevNonEmptyLine =~ '=\s*\(enum\|tuple\)\>\s*$' ||
          \ prevNonEmptyLine =~ '=\s*\(ptr\|ref\)\=\s\+object\(\s\+of\s\+\a\w*\)\=\>\s*$' ||
          \ prevNonEmptyLine =~ '=\s*concept\>.*$'
      return prevIndent + shiftwidth()
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
      if (prevNonEmptyLine =~ '^\s*\(case\|if\|when\|try\|of\)\>') ||
            \ (curIndent <= prevIndent - shiftwidth())
        return -1
      else
        return prevIndent - shiftwidth()
      endif
    endif

    return -1
endfunction
