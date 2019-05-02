### Nim language plugin for NeoVim

This plugin is still pretty much a work-in-progress.

[![asciicast](https://asciinema.org/a/223646.svg)](https://asciinema.org/a/223646)

#### Requirements

- neovim >= 0.3.0 (nimsuggest integration requires TCP byte sockets)
- Latest development version of nimsuggest (`--autobind` is required, you can
  use [choosenim] to install this version)

**Note**: The current stable version (0.19.x) will not work with this plugin.

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

#### Usage

See the project's [wiki][1] for more information.

[0]: https://github.com/prabirshrestha/asyncomplete.vim
[1]: https://github.com/alaviss/nim.nvim/wiki
[choosenim]: https://github.com/dom96/choosenim
[vim-packager]: https://github.com/kristijanhusak/vim-packager
[vim-plug]: https://github.com/junegunn/vim-plug
