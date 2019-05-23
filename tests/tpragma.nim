proc longProc(a: int,
              b: string) {.noSideEffects.} =
  #! 2 disabled

proc longProc(a: int,
              b: string)
             {.noSideEffects.} = #! 7 disabled
  #! 2 disabled
