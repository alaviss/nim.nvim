--- Regex to match the two forms of test specifications:
---
--- #[! <n indent> disabled?]
--- #! <n indent> disabled?
local testSpecRegex = vim.regex([[\%(#\[!.*\]#\)\|\%(#!.*$\)]])

describe('indent', function()
  local TestsDir = 'tests/nim.nvim/indent'
  local scanner = assert(vim.loop.fs_scandir(TestsDir))

  ---@class Spec
  ---@field pos number[] An array containing the position of the spec in the file: [lnum, startCol, endCol]
  ---@field expected number The amount of indentation expected
  ---@field disabled boolean Whether this test is disabled

  --- Parse a test file and return all tests within it
  ---@param test string The test spec file
  ---@return Spec[] spec
  local function parseTest(test)
    -- Load the test file into a buffer
    local buf = vim.fn.bufadd(test)
    vim.fn.bufload(buf)

    local result = {}
    vim.api.nvim_buf_call(buf, function()
      -- Move cursor to the start of the buffer
      vim.api.nvim_win_set_cursor(0, {1, 0})
      -- Scan test specs in the buffer
      while true do
        -- Get position of the spec
        --
        -- Note: This API returns 1-indexed positions
        local pos = vim.fn.searchpos([[\m#\[\?!]], 'zW')
        -- If a match is found
        if pos[1] > 0 then
          -- Correct positions to 0-indexed.
          pos = vim.tbl_map(function(x) return x - 1 end, pos)

          -- Store the end position (exclusive) of the spec
          pos[3] = select(2, testSpecRegex:match_line(
            0,
            pos[1]
          ))

          -- Get the text of the specification
          local spec = vim.api.nvim_buf_get_text(
            0, -- Get from current buffer
            pos[1], -- The starting line
            pos[2], -- Starting column
            pos[1], -- Ending line (inclusive)
            pos[3], -- Ending column (exclusive)
            {}
          )[1]
          result[#result + 1] = {
            pos = pos,
            expected = tonumber(string.match(spec, '(-?%d+)')),
            disabled = string.find(spec, 'disabled') ~= nil
          }
        else
          break
        end
      end
    end)

    return result
  end

  while true do
    local testFile = vim.loop.fs_scandir_next(scanner)
    testFile = testFile and TestsDir .. '/' .. testFile

    -- If there is a file
    if testFile then
      -- Only process files with 't*.nim' pattern
      if string.find(testFile, 't.*%.nim$') then
        local specs = parseTest(testFile)

        describe(testFile, function()
          -- Load the test file
          local buf = vim.fn.bufadd(testFile)
          vim.fn.bufload(buf)

          for _, spec in ipairs(specs) do
            -- A string describing the location of a test spec in the test file
            local posStr = string.format('(%d, %d)', unpack(
              -- Increment the indices by 1 as the stored position is 0-based
              vim.tbl_map(function(x) return x + 1 end, spec.pos)
            ))

            if not spec.disabled then
              it(posStr, function()
                vim.api.nvim_buf_call(buf, function()
                  -- Remove the test spec from the line.
                  --
                  -- This is due to test spec being a comment and comments have
                  -- indentation ignored.
                  vim.api.nvim_buf_set_text(
                    0, -- Current buffer
                    spec.pos[1], -- The spec line
                    spec.pos[2], -- The spec start column
                    spec.pos[1], -- The spec end line (inclusive?)
                    spec.pos[3], -- The spec end column (exclusive)
                    {}
                  )

                  -- Test the indent function.
                  --
                  -- Line number is increased by one as vimscript expects 1-based positions.
                  assert.are.equal(spec.expected, vim.fn.GetNimIndent(spec.pos[1] + 1))
                end)
              end)
            else
              -- Mark the test as disabled
              pending(posStr)
            end
          end

          vim.api.nvim_buf_delete(buf, {force = true})
        end)
      end
    else
      break
    end
  end
end)
