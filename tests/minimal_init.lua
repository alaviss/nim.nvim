vim.opt.runtimepath:prepend('.')

-- Load plenary testing harness
vim.opt.runtimepath:append('tests/plenary.nvim')

vim.api.nvim_create_user_command(
  'RunTests',
  function ()
    require('plenary.test_harness').test_directory(
      'tests/nim.nvim',
      {minimal_init = 'tests/minimal_init.lua'}
    )
  end,
  {desc = 'Run nim.nvim tests'}
)
