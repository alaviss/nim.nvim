#!/bin/bash

cd -- "$(dirname -- "$0")"

readonly pluginPath=$(pwd)/../
failed=0

for f in t*.nim; do
  if ! nvim -es -c "let &runtimepath = '$pluginPath' . ',' . &rtp" \
                -c 'source tester.vim' \
                +'set filetype=nim' +'verbose call RunTests()' \
                +"exe g:test_exit . 'cq'" "$f" \
                -u NORC --noplugin; then
    failed=1
  fi
  echo # there won't be any newline after nvim script done executing
done

exit $failed
