" Vim indent plugin
" Language: Nim
" Author:   Leorize

if exists("b:did_indent")
  finish
endif
let b:did_indent = v:true

setlocal autoindent
setlocal indentexpr=GetNimIndent(v:lnum)
setlocal indentkeys=!^F,o,O,0{,0),0],0},<:>

" regex used to match all comment group names.
let s:CommentGroups = 'Comment'
" regex used to match all string group names.
let s:StringGroups = 'String\|Quote'
" regex used to match all character group names.
let s:CharGroups = 'Character'
" paired operators start/end patterns
let s:PairStart = '(\|\[\|{'
let s:PairStop = '}\|]\|)'

" insert-mode/virtualedit aware col().
function! s:icol(expr) abort
  let oldve = &l:virtualedit
  setlocal virtualedit=
  let result = col(a:expr)
  let &l:virtualedit = oldve
  return result
endfunction

" get the syntax item name of the character under the cursor
function! s:syntaxName(lnum, col) abort
  return synIDattr(synID(a:lnum, a:col, v:false), 'name')
endfunction

" check if the given cursor position is a part of indent-insignificant syntax
" groups.
function! s:ignorePos(lnum, col) abort
  let syntax = s:syntaxName(a:lnum, a:col)
  return (syntax isnot# '' && syntax !~# '^nim') ||
        \syntax =~# '\%(' .. s:CommentGroups .. '\|' .. s:StringGroups ..
        \           '\|' .. s:CharGroups .. '\)'
endfunction

" get the byte indices containing the beginning and end of the comments on the
" line.
" returns [-1, -1] if none could be found.
function! s:findComment(lnum) abort
  if a:lnum > 0
    let oldPos = getcurpos()
    call cursor(a:lnum, 1)
    let start = 1 " starts at the first cursor column
    while start isnot 0 && s:syntaxName(a:lnum, start) !~# s:CommentGroups
      " unless the line is made of comments (as we checked before the loop
      " body), a nim comment starts with `#`
      let [_, start] = searchpos('\m#', 'z', a:lnum)
    endwhile
    let end = 0
    if start isnot 0
      " look for the end of the long comment in the current line.
      " since the search looks for the end of the current pair, it will
      " return nothing if the current position is not part of a pair
      let [_, end] = searchpairpos('#\[', '', ']#', 'nW',
                                  \{-> s:syntaxName(a:lnum, s:icol('.')) !~# s:CommentGroups},
                                  \a:lnum)
      if end == 0
        " if we can't find the end, make it the end of line.
        let end = col([a:lnum, '$'])
      endif
    endif
    " cursor column is 1-indexed
    let end -= 1
    let start -= 1
    call setpos('.', oldPos)
    return [start, end]
  else
    return [-1, -1]
  endif
endfunction

" get the line at lnum without comments & trimmed
function! s:getCleanLine(lnum) abort
  let result = getline(a:lnum)
  let [cstart, cend] = s:findComment(a:lnum)
  if cstart > 0
    " remove the comment out of the line. if any of the index expression
    " exceeds the bounds, an empty string will be returned so we don't have
    " to do too many checks here.
    " we also added a space to accomodate for the gap a long comment would
    " left behind.
    let result = result[: cstart - 1] .. ' ' .. result[cend + 1 :]
  endif
  " trim whitespaces
  let result = trim(result)
  return result
endfunction

" get the first line that's non-blank and not made with comments/strings
" above the given line number. Any comments/trailling whitespace in the line
" will also be stripped.
" returns [line number, line content], [0, ''] is returned if no such lines
" were found.
function! s:prevCleanLine(lnum) abort
  let lnum = a:lnum
  let line = ''
  while lnum > 0 && line is ''
    let lnum = prevnonblank(lnum - 1)
    if !s:ignorePos(lnum, 1) " check the entire line
      let line = s:getCleanLine(lnum)
    endif
  endwhile
  return [lnum, line]
endfunction

" a small wrapper around searchpairpos()
"
" the cursor will be moved to lnum, col before the search, and will be
" restored after the search.
"
" flags are additional flags to the function.
" these flags are always passed: 'nW'.
"
" A timeout of 2ms is enforced to avoid stalling the user.
function! s:findPair(lnum, col, startPattern, endPattern, flags, stopline) abort
  let oldPos = getcurpos()[1:]
  call cursor(a:lnum, a:col)
  let flags = substitute(a:flags, 'n\|W', '', 'g')
  let result = searchpairpos(a:startPattern, '', a:endPattern, flags .. 'nW',
                            \{-> s:ignorePos(line('.'), s:icol('.'))},
                            \a:stopline, 2)
  call cursor(oldPos)
  return result
endfunction

" wrapper around searchpos() to search but will verify result with
" ignorePos() before returning.
"
" the cursor will be moved to lnum, col before the search, and will be
" restored after.
"
" flags are additional flags to the function.
" the following are always passed: 'W'.
" 'n' flag is always ignored.
"
" pattern will always be treated as if magic is set.
"
" this function have no timeout guarantee, stopline should always be used to
" avoid going too far.
function! s:findClean(lnum, col, pattern, flags, stopline) abort
  let oldPos = getcurpos()[1:]
  call cursor(a:lnum, a:col)
  let result = [a:lnum, a:col]
  let flags = substitute(a:flags, 'n\|W', '', 'g')
  let pattern = '\m' .. '\%(' .. a:pattern .. '\)'
  while result != [0, 0]
    let result = searchpos(pattern, flags .. 'W', a:stopline, 2)
    " remove 'accept at cursor' flag after first search to avoid
    " infinite loops from matched but ignored positions.
    let flags = substitute(flags, 'c', '', 'g')
    if !s:ignorePos(result[0], result[1])
      break
    endif
  endwhile
  call cursor(oldPos)
  return result
endfunction

" returns the indentation for this line
"
" for simplicity we assume that the written Nim prior to this line is
" syntactically correct.
function! GetNimIndent(lnum) abort
  let result = -1 " don't change the indentation

  if !s:ignorePos(a:lnum, s:icol('.')) && !s:ignorePos(a:lnum, 1)
    let fullLine = getline(a:lnum)
    let line = s:getCleanLine(a:lnum)
    let indent = indent(a:lnum)
    let [prevLnum, prevLine] = s:prevCleanLine(a:lnum)
    let prevIndent = indent(prevLnum)

    " filter `<:>` trigger so that it's only considered to be active when
    " it's at EOL
    if fullLine[s:icol('.') - 1] is# ':'
      if fullLine[s:findClean(a:lnum, col([a:lnum, '$']), '\S', 'b', a:lnum)[1] - 1] is# ':'
        " elif-else/except/finally
        " except when next to one-liner of/if/elif/except/try
        " except when right after a case stmt
        if line =~# '^\%(el\%(se\|if\)\|except\|finally\)\>'
              \&& prevLine !~# '^\%(case\|of\|\%(el\)\?if\|except\|try\)\>'
          let result = prevIndent - shiftwidth()
          " if user already dedented
          if result >= indent
            let result = -1
          endif
        endif
      else
        " <:> activated in the middle of the line, ignore
      endif
    " implicit blocks
    " incl.
    " = enum
    " = concept x, y, z
    elseif prevLine =~# '^\%(type\|const\|let\|var\)\>$' ||
          \prevLine =~# '=\s*\%(concept\>.*\|enum\>\)$'
      let result = prevIndent + shiftwidth()
    " = (ptr|ref) (object (of smt) | tuple)
    " but only if the previous line wasn't empty
    elseif prevLine =~# '=\s*\%(ptr\|ref\)\?\s*\%(object\>\|tuple\>$\)' &&
          \(prevLnum is a:lnum - 1 || s:getCleanLine(a:lnum - 1) isnot# '')
      let result = prevIndent + shiftwidth()
    " noreturn statements
    elseif prevLine =~# '^\%(break\|continue\|return\|raise\)\>'
      let result = prevIndent - shiftwidth()
      " if user already dedented
      if result >= indent
        let result = -1
      endif
    " seperators that requires an indent afterwards
    elseif prevLine =~# ':$'
      "     \&& prevLine !~# '^\s*case\>'
      " uncomment the expression above if you like having your `case` ends
      " with a `:` but still want the next `of` to be on the same line.
      let result = prevIndent + shiftwidth()
      " we want to handle this kind of expression:
      "   if aLongCall("foo",
      "                1,
      "                2,
      "                3):
      "     |
      "
      " look for a close parenthesis from the end of the previous line.
      let [plnum, pcol] = s:findClean(prevLnum, col([prevLnum, '$']),
                                     \s:PairStop, 'b', prevLnum)
      if plnum isnot 0
        " found one, trace the opening
        let [plnum, pcol] = s:findPair(plnum, pcol, s:PairStart, s:PairStop,
                                      \'b', 0)
        if plnum isnot 0
          " use the indent of the opening line to produce the indent for this
          " line
          let result = indent(plnum) + shiftwidth()
        endif
      endif
    " handle a '=' after some tokens, but don't try if that '=' is standing
    " alone.
    elseif prevLine =~# '.\+=$'
      " indent by one shiftwidth by default
      let result = prevIndent + shiftwidth()
      " if it's not guaranteed to be a simple expression / assignment
      if prevLine !~# '\^\%(func\|proc\|method\|template\|macro\|let\|var\|const\)\>'
         \&& prevLine !~# '^\K\k*\s*=$'
        " could be a multi-line decl
        "
        " here's the monster that we will deal with
        "
        " keyword ident pattern? genericParamList? ( newlineInd?
        "   paramList ) : newLineInd? one-line-expr|type|type[..]?
        "     newlineInd? {. newlineInd?
        "       pragma list .?}? =
        "
        " newlineInd: newline w indent
        "
        " The actual grammar supported by Nim is much more flexible, but we
        " don't want to spend 90% of our time parsing Nim, we just want to
        " parse enough of it to recommend a good indentation. But if we parse
        " too little we won't have enough context to work with.
        "
        " let's deconstruct this
        " look for a close parenthesis from the end of the line.
        let [plnum, pcol] = s:findClean(prevLnum, col([prevLnum, '$']),
                                       \s:PairStop, 'b', prevLnum)
        if plnum isnot 0
          let pline = getline(plnum)
          if pline[pcol - 1] == '}'
            " possible pragma?
            let [plnum, pcol] = s:findPair(plnum, pcol, '{\.', '}', 'b', 0)
            if plnum is 0
              " not a pragma, so could be a pattern matching expression
              "
              " template optAdd{pattern} =
              "   |
              "
              " or
              "
              " let js{expr} =
              "   |
              "
              " Since these constructs might be multi-line, we trace the
              " opening curly bracket and use that line indentation as our
              " basis.
              let [plnum, pcol] = s:findPair(plnum, pcol, '{', '}', 'b', 0)
              if plnum isnot 0
                let result = indent(plnum) + shiftwidth()
              endif
            else
              " find the next marker on the same line
              let [pplnum, ppcol] = s:findClean(plnum, pcol, ')\|]', 'b', plnum)
              if pplnum isnot 0
                " the next marker is on the same line
                let [plnum, pcol, pline] = [pplnum, ppcol, getline(pplnum)]
              else
                " a pragma right below the proc definition?
                " look up the previous line for possible closing parenthesis
                let [pplnum, _] = s:prevCleanLine(plnum)
                if pplnum isnot 0
                  " there's a line before, try to find a closing parenthesis
                  let [pplnum, ppcol] = s:findClean(pplnum, col([pplnum, '$']),
                                                   \')\|]', 'cb', pplnum)
                endif
                if pplnum is 0
                  " looks like it's not a proc definition, follow the pragma
                  " opening indentation
                  let result = indent(plnum) + shiftwidth()
                  " disable the following logic
                  let [plnum, pcol] = [0, 0]
                else
                  " found a closing parenthesis, forward the data to
                  " the following handlers
                  let [plnum, pcol, pline] = [pplnum, ppcol, getline(pplnum)]
                endif
              endif
            endif
          endif
          if pline[pcol - 1] == ']'
            " possible return type with generics? or long tuple definition?
            " find starting point
            let [plnum, pcol] = s:findPair(plnum, pcol, '\[', ']', 'b', 0)
            if plnum isnot 0
              " try to find a closing parenthesis on the same line
              let [pplnum, ppcol] = s:findClean(plnum, pcol, ')', 'b', plnum)
              if pplnum is 0
                " not a proc, but use the opening braket to calculate
                " our indent
                "
                " ie.
                "
                " let a [someLongExpression(a,
                "                           b,
                "                           c)] =
                "   | <- cursor should be here
                let result = indent(plnum) + shiftwidth()
              else
                " can be:
                "
                " - a proc
                "
                " or
                "
                " procRetVar(a,
                "            b,
                "            c)[expr] =
                "   | <-
                let [plnum, pcol, pline] = [pplnum, ppcol, getline(pplnum)]
              endif
            endif
          endif
          if pline[pcol - 1] == ')'
            " possible proc closing parenthesis? or a type expression?
            " find the starting paren
            let [pplnum, ppcol] = s:findPair(plnum, pcol, '(', ')', 'b', 0)
            if pplnum isnot 0
              if pline[pcol - 1 :] =~# '^)\s*:'
                " a proc! use the opening parenthesis line as indent
                let result = indent(pplnum) + shiftwidth()
              else
                " might not be the actual proc, but a type expression
                "
                " proc something(a: string): owned(
                "   expr
                " ) =
                "   |
                "
                let [plnum, pcol] = s:findClean(pplnum, ppcol, ')\s*:', 'b', pplnum)
                if plnum isnot 0
                  " maybe this is our proc, find the opening paren and use its
                  " indent.
                  let [plnum, pcol] = s:findPair(plnum, pcol, '(', ')', 'b', 0)
                  if plnum isnot 0
                    let result = indent(plnum) + shiftwidth()
                  endif
                else
                  " might be this:
                  "
                  " proc something(a: string,
                  "                b: int):
                  "   owned(expr) =
                  "   |
                  "
                  let [plnum, pline] = s:prevCleanLine(pplnum)
                  if pline =~# ')\s*:$'
                    " seems likely
                    " locate the real position of the closing paren
                    let [_, pcol] = s:findClean(plnum, col([plnum, '$']), ')', 'b', plnum)
                    " then find the starting parenthesis and use that line indent.
                    let [plnum, pcol] = s:findPair(plnum, pcol, '(', ')', 'b', 0)
                    if plnum isnot 0
                      let result = indent(plnum) + shiftwidth()
                    endif
                  else
                    " might be this then?
                    "
                    " proc something(a: string,
                    "                b: int) =
                    "   |
                    "
                    " or
                    "
                    " proc something: owned(
                    "   expr
                    " ) =
                    "   |
                    "
                    "
                    " seems safe enough to just use the opening as our indent
                    let result = indent(pplnum) + shiftwidth()
                  endif
                endif
              endif
            endif
          endif
        endif
      endif
    " a lone opening curly
    elseif line =~# '^{'
      " this is for handling:
      "
      " proc foo(a: string,
      "          b: int): something
      "         { <-
      "
      " as in NEP-1
      " first find the closing paren in the upper line
      let [plnum, pcol] = s:findClean(prevLnum, col([prevLnum, '$']),
                                     \')', 'cb', prevLnum)
      if plnum isnot 0
        let [skiplnum, _] = s:findClean(prevLnum, col([prevLnum, '$']),
                                       \'=\|{\.', 'cb', prevLnum)
        if skiplnum isnot 0
          " handling:
          "
          " proc foo(a: string,
          "          b: int) =
          "
          " proc foo(a: string,
          "          b: int) = discard
          "
          " proc foo(a: string,
          "          b: int) {.importc.}
          "
          " do nothing here
        else
          " then find the opening
          let [plnum, pcol] = s:findPair(plnum, pcol, '(', ')', 'b', 0)
          " verify that we are dealing with a routine
          let pline = s:getCleanLine(plnum)
          if pline =~# '^\%(proc\|func\|method\|iterator\|template\)'
            " it's a routine declaration.
            "
            " align with the opening paren.
            let result = pcol - 1
          endif
        endif
      endif
    " a lone closing parenthesis
    elseif line =~# '^\%(' .. s:PairStop .. '\)$'
      " find the opening
      let [plnum, pcol] = s:findPair(a:lnum, 1,
                                    \s:PairStart, s:PairStop,
                                    \'b', 0)
      if plnum isnot 0 && plnum isnot a:lnum
        let pline = s:getCleanLine(plnum)
        if pline =~# '\%(' .. s:PairStart .. '\)$'
          " if the opening is followed by a newline
          "
          " ie.
          "   let something = Obj(
          "
          "   ) <- we would want the closing paren to follow the opening
          "        indent
          let result = indent(plnum)
        else
          " otherwise this our case might be:
          "   tuple[a: string,
          "         b: int
          "        ] <- we would want the closing paren to be parallel with
          "             the opening
          " align the closing parenthesis with the opening
          let result = pcol - 1
        endif
        " if user already dedented
        if result >= indent
          let result = -1
        endif
      endif
    " our limited set of triggers should prevent these rules from being too
    " invasive.
    else
      " look backward to see if we are in a parenthesis
      let [plnum, pcol] = s:findPair(a:lnum, s:icol('.'),
                                    \s:PairStart, s:PairStop,
                                    \'b', 0)
      " if we are in a parenthesis, and the opening is on the previous line,
      " recommend lining up with the opening parenthesis.
      " we only do this when the previous line is matched, since autoindent will
      " copy the indent to the next line, allowing us to respect the user's
      " decision should the actual indent be smaller.
      "
      " ie.
      "
      " procCall(paramA,
      "          | <- where the cursor should be
      if plnum is prevLnum
        if prevLine =~# '\%(' .. s:PairStart .. '\)$'
          " but if the previous line ends on a parenthesis opening, then
          " just recommend an indent
          "
          " ie.
          " let obj = Obj(
          "   | <-- we would want our cursor there.
          let result = prevIndent + shiftwidth()
        else
          let result = pcol
          " can't use prevLine here since we need the full, unmodified line
          if getline(plnum)[pcol] is# '.'
            " {.inline,
            "   | <- we want our cursor here
            let result += 1
          endif
        endif
      " no parenthesis found, and the previous line ended in a comma
      elseif plnum is 0 && prevLine =~# ',$'
        " get the exact column of the trailing comma
        let [_, ccol] = s:findClean(prevLnum, col([prevLnum, '$']), ',', 'b',
                                   \prevLnum)
        " get the parenthesis surrounding the comma
        let [plnum, _] = s:findPair(prevLnum, ccol,
                                   \s:PairStart, s:PairStop,
                                   \'b', 0)
        " if the comma is not inside a parenthesis
        if plnum is 0
          let [clnum, cline] = s:prevCleanLine(prevLnum)
          if cline =~# ',$'
            " the previous line is probably a part of an ongoing trail of
            " parameters
            "
            " ie.
            "
            " foo a,
            "     b,
            "     | <-
            "
            " don't touch the indent
          else
            " otherwise this might be in a command call
            "
            " echo a,
            "      | <- we want our cursor to be right below the first param
            "
            " thanks to the syntax limitation, we can safely assume that
            " the line has to be something like this:
            "
            "   identifier variable-space param,
            "
            " to qualify as a command call with multiple parameters
            if prevLine =~# '^\K\k*\s\+.\+,$'
              " assign directly to result because we know the first match will
              " definitely be a part of what we matched.
              let [_, result] = s:findClean(prevLnum, 1, '\K\k*\s\+', 'e', prevLnum)
            endif
          endif
        endif
      endif
    endif
  endif

  return result
endfunction
