### Nim language plugin for NeoVim

This plugin is still pretty much a work-in-progress.

[![asciicast](https://asciinema.org/a/223646.svg)](https://asciinema.org/a/223646)

#### Requirements

- neovim >= 0.3.0 (nimsuggest integration requires TCP byte sockets)
- Latest development version of nimsuggest (--autobind is required, stable
  version 0.19.4 doesn't work, try using [choosenim to install devel
  version](https://github.com/dom96/choosenim))

#### Installation

- [vim-plug]:

      Plug 'alaviss/nim.nvim'

- [vim-packager]:

      call packager#add('alaviss/nim.nvim')

#### Features

- Semantic highlighting with nimsuggest. Highlight as you type (experimental)
- "Go to Definition" support using nimsuggest.
- Autocompletion using nimsuggest.
- Section movements!
- And more...

#### Auto completion

Install [`prabirshrestha/asyncomplete.vim`][0] and configure it to your liking.

Add this to your configuration file to register the autocomplete source:

```vim
au User asyncomplete_setup call asyncomplete#register_source({
    \ 'name': 'nim',
    \ 'whitelist': ['nim'],
    \ 'completor': {opt, ctx -> nim#suggest#sug#GetAllCandidates({start, candidates -> asyncomplete#complete(opt['name'], ctx, start, candidates)})}
    \ })
```

#### Basic go to definition usage

Once you have configured this plug-in following the steps above, create a file
`test.nim` with the following contents:

```
import strutils

proc testMe() =
  echo "test".toLower

proc main() =
  testMe()
  test_me()

when isMainModule:
  main()
```

Put your cursor on the first `testMe()` call inside the `main()` proc, and
while still in normal mode, type the default binding to jump to the definition
of the `testMe()` proc, which is `gd`. If the plugin is correctly installed and
nimsuggest is working, your cursor should jump to the sixth column of the third
line, where the proc is defined. Type `Ctrl+o` to jump back, and repeat the
same on the line below: since Nim syntax is case insensitive, the go to
definition command will work the same on the `test_me()` call.

Now position your cursor on the `toLower` call at the end of the fourth line
and repeat the go to definition command. Nimsuggest works across source files
and into Nim's own standard library, so you should end up looking at the
`toLower*(s: string)` proc, which at the moment of writing this is located on
[line 1546 of the lib/pure/unicode.nim
file](https://github.com/nim-lang/Nim/blob/aa072b952555804e516861d9ed62846e341f7938/lib/pure/unicode.nim#L1546).
You can even move your cursor a few lines below to the `convertRune(s,
toLower)` and nimsuggest will keep working. Type `Ctrl+o` (several times, if
needed) to jump back to your source file.

If you are working on a file, chances are it will be _dirty_ and not saved to
disk. In these situations, the go to definition command only works for your own
source. If you start any modification of the test file and try to go to the
definition of `toLower`, you will be greeted with the error `E37: No write
since last change (add ! to override)` because Neovim does not want to lose
your changes switching the current buffer. You can avoid this in two ways: save
the file before going to the definition, or typing the alternative mapping `gD`
(upper case `D`). This alternative mapping will split the current window and go
to the definition in the new window. Typing `Ctrl+o` now would bring you back
to your buffer and keep the split window, so you might as well close the window
directly typing `:q`.

If you look at the default plug-in key mappings at the end of
[ftplugin/nim.vim](ftplugin/nim.vim), you will see the
[gd](ftplugin/nim.vim#L63) and [gD](ftplugin/nim.vim#L64) mappings. If you
prefer splitting your window vertically, note that there is an orphan
[NimGoToDefVSplit](ftplugin/nim.vim#L61). You can use it adding the following
line to your Neovim `init.vim` file:

```
nmap gV <Plug>NimGoToDefVSplit
```


[0]: https://github.com/prabirshrestha/asyncomplete.vim
[vim-packager]: https://github.com/kristijanhusak/vim-packager
[vim-plug]: https://github.com/junegunn/vim-plug
