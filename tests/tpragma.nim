proc longProc(a: int,
              b: string) {.noSideEffect.} =
  #! 2

proc longProc(a: int,
              b: string): seq[int]
             {.noSideEffect, #! 13
               #[! 15]#inline.} =
  #! 2

proc longProc(a: int,
              b: string): owned(ref int) = discard

{ #! -1

proc longProc(a: int,
              b: string): int =
  { #! 2

{.somePragma().}
{ #! -1
