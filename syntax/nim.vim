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

syntax match nimComment      "#.*$" contains=nimTodo,@Spell
syntax region nimLongDocComment start='##\[' end=']##' contains=nimTodo,nimLongDocComment,@Spell
syntax region nimLongComment start='#\[' end=']#' contains=nimTodo,nimLongComment,nimLongDocComment,@Spell
syntax keyword nimTodo       FIXME NOTE NOTES TODO XXX contained

syntax region nimString
      \ matchgroup=nimQuote
      \ start=+"+ skip=+\\"+ end=+"+
      \ contains=nimEscapeStr,nimEscapeChar,nimEscapeQuote,@Spell
      \ oneline
syntax region nimString
      \ matchgroup=nimTripleQuote
      \ start=+"""+ end=+"*\zs"""+
      \ contains=nimEscapeStr,nimEscapeChar,@Spell
syntax region nimRawString
      \ matchgroup=nimQuote
      \ start='\k\+"' end='"'
      \ contains=@Spell
      \ oneline
syntax region nimRawString
      \ matchgroup=nimTripleQuote
      \ start='\k\+"""' end='"*\zs"""'
      \ contains=@Spell
syntax match nimCharacter +'\%(\\\%([rcnlftv\\"'abe]\|x\x\{2}\|\d\+\)\|.\)'+ contains=nimEscapeChar,nimEscapeQuote

syntax match nimEscapeChar  +\\[rcnlftv\\'abe]+ contained
syntax match nimEscapeChar  "\\\d\+" contained
syntax match nimEscapeChar  "\\\x\x\{2}" contained
syntax match nimEscapeQuote +\\"+ contained
syntax match nimEscapeStr   "\\p" contained
syntax match nimEscapeStr   "\\u\%(\x\{4}\|{\x\+}\)" contained

syntax match nimNumber display "\<\d\+\%(_\d\+\)*\%('\=[iIuU]\%(8\|16\|32\|64\)\)\=\>"
syntax match nimNumber display "\<0[xX]\x\+\%(_\x\+\)*\%('\=[iIuU]\%(8\|16\|32\|64\)\)\=\>"
syntax match nimNumber display "\<0o\o\+\%(_\o\+\)*\%('\=[iIuU]\%(8\|16\|32\|64\)\)\=\>"
syntax match nimNumber display "\<0[bB][01]\+\%(_[01]\+\)*\%('\=[iIuU]\%(8\|16\|32\|64\)\)\=\>"

" floats are evil
" if have float suffix
syntax match nimFloat display "\<\d\+\%(_\d\+\)*'\=\%([fF]\%(32\|64\)\=\|[dD]\)\>"
syntax match nimFloat display "\<0[xX]\x\+\%(_\x\+\)*'\%([fF]\%(32\|64\)\=\|[dD]\)\>"
syntax match nimFloat display "\<0o\o\+\%(_\o\+\)*'\=\%([fF]\%(32\|64\)\=\|[dD]\)\>"
syntax match nimFloat display "\<0[bB][01]\+\%(_[01]\+\)*'\=\%([fF]\%(32\|64\)\=\|[dD]\)\>"
" if have fractional part and optionally exponent
syntax match nimFloat display "\<\d\+\%(_\d\+\)*\%(\.\d\+\%(_\d\+\)*\)\%([eE][+-]\=\d\+\%(_\d\+\)*\)\=\%('\=\%([fF]\%(32\|64\)\=\|[dD]\)\)\=\>"
" if have exponent
syntax match nimFloat display "\<\d\+\%(_\d\+\)*\%([eE][+-]\=\d\+\%(_\d\+\)*\)\%('\=\%([fF]\%(32\|64\)\=\|[dD]\)\)\=\>"

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

syntax region nimPragmaList
      \ start=+{\.+ end=+\.\?}+
      \ contains=nimPragma,nimString,nimRawString

" sync at the beginning of functions definition
syntax sync match nimSync grouphere NONE "^\%(proc\|func\|iterator\|method\)\s\+\a\w*\s*[(:=]"
" sync at some special places
syntax sync match nimSync grouphere NONE "^\%(discard\|let\|var\|const\|type\)"
" sync at long string start
syntax sync match nimSyncString grouphere nimString "^\%(discard\|asm\)\s\+\"\{3}"
syntax sync match nimSyncString grouphere nimRawString "r\"\{3}"

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
highlight default link nimPragma          PreProc
" semantic highlighter, straight from the compiler
" TSymKind in compiler/ast.nim, sk prefix replaced with nimSug
highlight default link nimSugUnknown Error
highlight default link nimSugParam Identifier
highlight default link nimSugModule Identifier
highlight default link nimSugType Type
highlight default link nimSugGenericParam Type
highlight default link nimSugVar Identifier
highlight default link nimSugGlobalVar Identifier
highlight default link nimSugLet Identifier
highlight default link nimSugGlobalLet Identifier
highlight default link nimSugConst Constant
highlight default link nimSugResult Special
highlight default link nimSugProc Function
highlight default link nimSugFunc Function
highlight default link nimSugMethod Function
highlight default link nimSugIterator Function
highlight default link nimSugConverter Macro
highlight default link nimSugMacro Macro
highlight default link nimSugTemplate Macro
highlight default link nimSugField Identifier
highlight default link nimSugEnumField Constant
highlight default link nimSugForVar Identifier
highlight default link nimSugLabel Identifier
