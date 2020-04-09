proc longProc(a: int,
              b: string) {.noSideEffect.} =
  #! 2

proc longProc(a: int,
              b: string): seq[int]
             {.noSideEffect, #! 13
               inline.} = #! 15
  #! 2
