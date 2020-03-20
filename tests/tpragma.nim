proc longProc(a: int,
              b: string) {.noSideEffects.} =
  #! 2

proc longProc(a: int,
              b: string): seq[int]
             {.noSideEffects.} = #! 13
  #! 2
