proc foo(a: int,
         b: string): owned(ref int) =
  #! 2

proc bar(a: int,
         c: proc(): int,
         b: string):
         owned(ref seq[int]) =
  #! 2
