proc longProc(a: int,
              b: string) {.noSideEffects.} =
  #! 2

proc longProc(a: int,
              b: string)
             {.noSideEffects.} = #! 13
  #! 2 disabled
