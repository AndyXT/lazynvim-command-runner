-- Simple test script for terminal functionality
-- Run with: nvim -u NONE -l terminal_test.lua

-- Function to open a simple terminal
local function test_terminal()
  -- Create a buffer for output
  local buf = vim.api.nvim_create_buf(false, true)
  
  -- Create a split
  vim.cmd('botright 15split')
  local win = vim.api.nvim_get_current_win()
  
  -- Set the buffer in the window
  vim.api.nvim_win_set_buf(win, buf)
  
  -- Try to open a terminal
  vim.cmd('terminal python3')
  
  -- Enter insert mode
  vim.cmd('startinsert')
  
  -- Print results
  print("Terminal window created")
  
  -- Add mapping to close
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':q<CR>', {noremap = true, silent = true})
end

-- Run the test
test_terminal()

-- Sleep a bit to see the results
vim.cmd('sleep 10000m')