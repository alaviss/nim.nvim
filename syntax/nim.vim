" Vim syntax file
" Language: Nim
" Author:   Leorize
" Credits:  Zvezdan Petkovic <zpetkovic@acm.org>
"
" The design of this syntax file is based on python.vim bundled within the
" default neovim installation

if exists("b:current_syntax")
  finish
endif

let chosen_syntax = get(g:, 'nim_emit_syntax', 'c')
if chosen_syntax is? 'c'
  syntax include @emitSyntax syntax/c.vim
elseif chosen_syntax =~? 'cpp\|c++'
  syntax include @emitSyntax syntax/cpp.vim
elseif chosen_syntax =~? 'js\|javascript'
  syntax include @emitSyntax syntax/javascript.vim
elseif chosen_syntax is? 'objc'
  syntax include @emitSyntax syntax/objc.vim
else
  execute 'syntax include @emitSyntax ' .. chosen_syntax
endif

let b:current_syntax = "nim"

" Keyword from the Manual, classified to different categories
syntax keyword nimKeywordOperator addr and as distinct div do in is isnot mod
syntax keyword nimKeywordOperator not notin of or ptr ref shl shr unsafeAddr xor
syntax keyword nimStatement       asm bind block break cast concept const
syntax keyword nimStatement       continue defer discard enum let mixin return
syntax keyword nimStatement       static type using var yield
syntax keyword nimStatement       converter func iterator macro method proc
syntax keyword nimStatement       template
syntax keyword nimConditional     case elif else if
syntax keyword nimKeyword         end interface out
syntax keyword nimException       except finally raise try
syntax keyword nimRepeat          for while
syntax keyword nimConstant        nil
syntax keyword nimPreCondit       when
syntax keyword nimInclude         export from import include
syntax keyword nimStructure       enum object tuple

syntax keyword nimPreProcStmt     alignof compiles defined sizeof

syntax cluster nimKeywordGroup contains=nimKeywordOperator,nimStatement,nimConditional,nimException,nimRepeat,nimConstant,nimPreCondit,nimInclude,nimStructure,nimPreProcStmt

syntax match nimComment      "#.*$" contains=nimTodo,@Spell
syntax region nimLongDocComment start='##\[' end=']##' contains=nimTodo,nimLongDocComment,@Spell
syntax region nimLongComment start='#\[' end=']#' contains=nimTodo,nimLongComment,nimLongDocComment,@Spell
syntax keyword nimTodo       FIXME NOTE NOTES TODO XXX contained

syntax cluster nimCommentGroup contains=nimComment,nimLongDocComment,nimLongComment

syntax region nimEscapedSymbol
      \ matchgroup=nimBacktick
      \ start='`' end='`'
      \ contains=@nimCommentGroup
      \ oneline

syntax region nimString
      \ matchgroup=nimQuote
      \ start=+"+ skip=+\\"+ end=+"+
      \ contains=nimEscapeStr,nimEscapeChar,nimEscapeQuote,@Spell
      \ oneline
syntax region nimRawString
      \ matchgroup=nimQuote
      \ start='\<\K\k*"' end='"'
      \ contains=@Spell
      \ oneline
syntax region nimRawString
      \ matchgroup=nimTripleQuote
      \ start='\%(\<\K\k*\)\?"""' end='"*\zs"""'
      \ contains=@Spell
syntax match nimCharacter +'\%(\\\%([rcnlftv\\"'abe]\|x\x\{2}\|\d\+\)\|.\)'+ contains=nimEscapeChar,nimEscapeQuote

syntax match nimEscapeChar  +\\[rcnlftv\\'abe]+ contained
syntax match nimEscapeChar  "\\\d\+" contained
syntax match nimEscapeChar  "\\\x\x\{2}" contained
syntax match nimEscapeQuote +\\"+ contained
syntax match nimEscapeStr   "\\p" contained
syntax match nimEscapeStr   "\\u\%(\x\{4}\|{\x\+}\)" contained

let nimDec = '\d\+\%(_\d\+\)*'
let nimHex = '0[xX]\x\+\%(_\x\+\)*'
let nimOct = '0o\o\+\%(_\o\+\)*'
let nimBin = '0[bB][01]\+\%(_[01]\+\)*'

let nimDecFloat = nimDec .. '\.' .. nimDec
let nimExpSuffix = '[eE][+-]\=' .. nimDec

let nimIntSuffix = '''\=[iIuU]\%(8\|16\|32\|64\)'
let nimFloatSuffix = '''\=\%([fF]\%(32\|64\|128\)\=\|[dD]\)'
let nimCustomSuffix = '''\K\+\k*'

function s:matchNumber(name, base, suffix) abort
  " base: [[regex: string, suffixOpt: bool?]]
  for [bregex, suffixOpt] in a:base
    " unary `-` is a part of a literal
    let regex = '\%(\<\|\%(\s\+\zs\|^\)\-\)' .. bregex
    if suffixOpt
      let regex .= '\%(' .. a:suffix .. '\)\='
    else
      let regex .= a:suffix
    endif
    let regex .= '\>'

    execute 'syntax match ' .. a:name .. ' display "' .. regex .. '"'
  endfor
endfunction

call s:matchNumber(
     \ 'nimNumber',
     \ [[nimDec, v:true], [nimHex, v:true], [nimOct, v:true], [nimBin, v:true]],
     \ nimIntSuffix
     \ )

call s:matchNumber(
     \ 'nimFloat',
     \ [[nimDec, v:false], [nimHex, v:false], [nimOct, v:false],
     \  [nimBin, v:false],
     \  [nimDecFloat .. '\%(' .. nimExpSuffix .. '\)\=', v:true],
     \  [nimDec .. nimExpSuffix, v:true]],
     \ nimFloatSuffix
     \ )

call s:matchNumber(
     \ 'nimCustomNumber',
     \ [[nimDec, v:false], [nimHex, v:false], [nimOct, v:false],
     \  [nimBin, v:false],
     \  [nimDecFloat .. '\%(' .. nimExpSuffix .. '\)\=', v:false],
     \  [nimDec .. nimExpSuffix, v:false]],
     \ nimCustomSuffix
     \ )

syntax cluster nimLiteralGroup contains=nimString,nimRawString,nimCharacter,nimNumber,nimFloat,nimCustomNumber

" pragmas in Nim are matched style-insensitively, so we need to create custom
" matches for them.
function! s:matchPragmas(pragmas) abort
  for i in a:pragmas
    execute 'syntax match nimPragma contained display ''\<' . nim#SearchIdentifierRegex(i) . '\>'''
  endfor
endfunction
" builtins pragma, these are not processed by nimsuggest highlighter
call s:matchPragmas(['deprecated', 'noSideEffect', 'compileTime', 'noReturn',
     \               'acyclic', 'final', 'shallow', 'pure', 'asmNoStackFrame',
     \               'error', 'fatal', 'warning', 'hint', 'line', 'linearScanEnd',
     \               'computedGoto', 'unroll', 'checks', 'boundChecks',
     \               'overflowChecks', 'nilChecks', 'assertions', 'warnings',
     \               'hints', 'optimization', 'patterns', 'callconv', 'push',
     \               'pop',' register', 'global', 'pragma', 'hint', 'used',
     \               'experimental', 'bitsize', 'voliatile', 'nodecl', 'header',
     \               'incompletestruct', 'compile', 'link', 'passC', 'passL',
     \               'emit', 'importcpp', 'importobjc', 'codegendecl',
     \               'injectstmt', 'intdefine', 'strdefine', 'cdecl', 'importc',
     \               'exportc', 'extern', 'bycopy', 'byref', 'varargs', 'union',
     \               'packed', 'dynlib', 'threadvar', 'gcsafe', 'locks', 'guard',
     \               'inline', 'borrow', 'booldefine', 'discardable', 'noInit',
     \               'requiresInit', 'closure', 'nimcall', 'stdcall', 'safecall',
     \               'fastcall', 'syscall', 'noconv', 'nanChecks', 'infChecks',
     \               'floatChecks', 'size', 'base', 'raises', 'tags', 'effects',
     \               'inject', 'gensym', 'explain', 'noRewrite', 'package',
     \               'inheritable', 'constructor'])

syntax region nimEmitString
      \ matchgroup=nimQuote
      \ start=+"+ skip=+\\"+ end=+"+
      \ contains=@emitSyntax,nimEscapeStr,nimEscapeChar,nimEscapeQuote
      \ oneline
      \ contained
      \ keepend
syntax region nimEmitRawString
      \ matchgroup=nimQuote
      \ start='\<\K\k*"' end='"'
      \ contains=@emitSyntax
      \ oneline
      \ contained
      \ keepend
syntax region nimEmitRawString
      \ matchgroup=nimTripleQuote
      \ start='\%(\<\K\k*\)\?"""' end='"*\zs"""'
      \ contains=@emitSyntax
      \ contained
      \ keepend

syntax region nimEmitArray
      \ start='\[' end=']'
      \ contains=@nimKeywordGroup,@nimLiteralGroup,@nimCommentGroup,nimEmitString,nimEmitRawString
      \ contained

execute 'syntax region nimEmit ' ..
      \ 'start=+\<\%(' .. nim#SearchIdentifierRegex('emit') .. '\|' .. nim#SearchIdentifierRegex('codegendecl') .. '\)\m\s*:+ ' ..
      \ 'end=+\ze\%(,\|\.\?}\)+ ' ..
      \ 'contains=@nimKeywordGroup,@nimLiteralGroup,@nimCommentGroup,nimPragma,nimEmit.\+ ' ..
      \ 'contained'

syntax region nimPragmaList
      \ start=+{\.+ end=+\.\?}+
      \ contains=@nimKeywordGroup,@nimLiteralGroup,@nimCommentGroup,nimPragma,nimEmit

" sync at the beginning of functions definition
syntax sync match nimSync grouphere NONE "^\%(proc\|func\|iterator\|method\)\s\+\a\w*\s*[(:=]"
" sync at some special places
syntax sync match nimSync grouphere NONE "^\%(discard\|let\|var\|const\|type\)"
" sync at long string start
syntax sync match nimSyncString grouphere nimString "^\%(discard\|asm\)\s\+\"\{3}"
syntax sync match nimSyncString grouphere nimRawString "r\"\{3}"

if has("nvim-0.9.0")
  highlight default link nimKeywordOperator @keyword.operator
  highlight default link nimStatement       @keyword
  highlight default link nimConditional     @conditional
  highlight default link nimKeyword         @keyword
  highlight default link nimException       @exception
  highlight default link nimRepeat          @repeat
  highlight default link nimConstant        @constant
  highlight default link nimPreCondit       @conditional
  highlight default link nimInclude         @include
  highlight default link nimStructure       @keyword
  highlight default link nimPreProcStmt     @function.builtin
  highlight default link nimComment         @comment
  highlight default link nimTodo            @text.todo
  highlight default link nimLongDocComment  @comment.documentation
  highlight default link nimLongComment     @comment.documentation
  highlight default link nimString          @string
  highlight default link nimEscapeStr       @string.escape
  highlight default link nimEscapeChar      @string.escape
  highlight default link nimEscapeQuote     @string.escape
  highlight default link nimRawString       @string
  highlight default link nimQuote           @string
  highlight default link nimTripleQuote     nimQuote
  highlight default link nimCharacter       @character
  highlight default link nimNumber          @number
  highlight default link nimFloat           @float
  highlight default link nimCustomNumber    @number
  highlight default link nimPragma          @preproc

  " semantic highlighter, straight from the compiler
  " TSymKind in compiler/ast.nim, sk prefix replaced with nimSug
  highlight default link nimSugUnknown      @error
  highlight default link nimSugParam        @parameter
  highlight default link nimSugModule       @namespace
  highlight default link nimSugType         @type
  highlight default link nimSugGenericParam @parameter
  highlight default link nimSugVar          @variable
  highlight default link nimSugGlobalVar    @variable
  highlight default link nimSugLet          @variable
  highlight default link nimSugGlobalLet    @variable
  highlight default link nimSugConst        @constant
  highlight default link nimSugResult       @variable.builtin
  highlight default link nimSugProc         @function.call
  highlight default link nimSugFunc         @function.call
  highlight default link nimSugMethod       @function.call
  highlight default link nimSugIterator     @function.call
  highlight default link nimSugConverter    @function.macro
  highlight default link nimSugMacro        @function.macro
  highlight default link nimSugTemplate     @function.macro
  highlight default link nimSugField        @field
  highlight default link nimSugEnumField    @constant
  highlight default link nimSugForVar       @parameter
  highlight default link nimSugLabel        @label
else
  highlight default link nimKeywordOperator Operator
  highlight default link nimStatement       Statement
  highlight default link nimConditional     Conditional
  highlight default link nimKeyword         Keyword
  highlight default link nimException       Exception
  highlight default link nimRepeat          Repeat
  highlight default link nimConstant        Constant
  highlight default link nimPreCondit       PreCondit
  highlight default link nimInclude         Include
  highlight default link nimStructure       Structure
  highlight default link nimPreProcStmt     Macro
  highlight default link nimComment         Comment
  highlight default link nimTodo            Todo
  highlight default link nimLongDocComment  Comment
  highlight default link nimLongComment     Comment
  highlight default link nimString          String
  highlight default link nimEscapeStr       SpecialChar
  highlight default link nimEscapeChar      SpecialChar
  highlight default link nimEscapeQuote     SpecialChar
  highlight default link nimRawString       String
  highlight default link nimQuote           String
  highlight default link nimTripleQuote     nimQuote
  highlight default link nimCharacter       Character
  highlight default link nimNumber          Number
  highlight default link nimFloat           Float
  highlight default link nimCustomNumber    Number
  highlight default link nimPragma          PreProc

  highlight default link nimSugUnknown      Error
  highlight default link nimSugParam        Identifier
  highlight default link nimSugModule       Identifier
  highlight default link nimSugType         Type
  highlight default link nimSugGenericParam Type
  highlight default link nimSugVar          Identifier
  highlight default link nimSugGlobalVar    Identifier
  highlight default link nimSugLet          Identifier
  highlight default link nimSugGlobalLet    Identifier
  highlight default link nimSugConst        Constant
  highlight default link nimSugResult       Special
  highlight default link nimSugProc         Function
  highlight default link nimSugFunc         Function
  highlight default link nimSugMethod       Function
  highlight default link nimSugIterator     Function
  highlight default link nimSugConverter    Macro
  highlight default link nimSugMacro        Macro
  highlight default link nimSugTemplate     Macro
  highlight default link nimSugField        Identifier
  highlight default link nimSugEnumField    Constant
  highlight default link nimSugForVar       Identifier
  highlight default link nimSugLabel        Identifier
endif
