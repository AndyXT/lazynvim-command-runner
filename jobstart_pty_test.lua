-- Simple test script for jobstart with PTY functionality
-- Run with: nvim -u NONE -l jobstart_pty_test.lua

-- Debug logging
local debug_mode = true
local function debug_print(msg)
  if debug_mode then
    -- Using nvim_out_write to make sure debug output doesn't interfere with the terminal
    vim.api.nvim_out_write(msg .. "\n")
  end
end

-- Function to open a terminal with jobstart and PTY
local function test_jobstart_pty()
  -- Create a buffer for the terminal
  local buf = vim.api.nvim_create_buf(false, true)
  
  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, "buflisted", false)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile") -- Important: don't set filetype=terminal yet
  vim.api.nvim_buf_set_name(buf, "Jobstart PTY Test")
  
  -- Create a window - bottom split
  vim.cmd('botright 15split')
  local win = vim.api.nvim_get_current_win()
  
  -- Set the buffer in the window
  vim.api.nvim_win_set_buf(win, buf)
  
  -- Set window options
  vim.api.nvim_win_set_option(win, "number", false)
  vim.api.nvim_win_set_option(win, "relativenumber", false)
  vim.api.nvim_win_set_option(win, "signcolumn", "no")
  
  -- Get user's shell instead of hardcoding a command
  local shell = vim.o.shell or "sh"
  
  -- Command to run (prioritize using the shell for better compatibility)
  local cmd
  if vim.fn.executable("python3") == 1 then
    debug_print("Using python3")
    cmd = {"python3"}
  elseif vim.fn.executable("python") == 1 then
    debug_print("Using python")
    cmd = {"python"}
  else
    debug_print("Python not found, using shell")
    cmd = {shell}
  end
  
  debug_print("Command: " .. table.concat(cmd, " "))
  
  -- Job options with PTY support
  local job_opts = {
    pty = true,       -- This is the key option for PTY support
    stdin = "pipe",   -- Allow sending input to the command
    width = vim.api.nvim_win_get_width(win),  -- Match window width
    height = vim.api.nvim_win_get_height(win) -- Match window height
  }
  
  -- Don't add stdout/stderr handlers as they can interfere with terminal display
  -- We'll rely on the terminal buffer to show output directly
  
  -- Add the on_exit handler
  job_opts.on_exit = function(_, code)
    debug_print("Command exited with code: " .. code)
  end
  
  -- Start job with jobstart
  local job_id
  
  -- Use pcall to handle errors
  local ok, result = pcall(function()
    return vim.fn.jobstart(cmd, job_opts)
  end)
  
  if not ok then
    debug_print("Error starting job: " .. result)
    return
  end
  
  job_id = result
  
  if job_id <= 0 then
    debug_print("Failed to start job: " .. job_id)
    return
  end
  
  -- Now set the buffer's filetype to terminal after job is started
  vim.api.nvim_buf_set_option(buf, "filetype", "terminal")
  
  -- Store job_id in buffer variable
  vim.b[buf].terminal_job_id = job_id
  
  -- Map keys to interact with the terminal
  vim.api.nvim_buf_set_keymap(buf, 'n', 'i', 'i', {noremap = true, silent = true})
  vim.api.nvim_buf_set_keymap(buf, 't', '<ESC><ESC>', '<C-\\><C-n>', {noremap = true, silent = true})
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':q<CR>', {noremap = true, silent = true})
  
  -- Example function to send input to the command
  _G.send_to_terminal = function(input)
    if not vim.api.nvim_buf_is_valid(buf) then
      debug_print("Buffer no longer valid")
      return
    end
    
    -- Get terminal channel from buffer variable
    local term_chan = vim.b[buf].terminal_job_id
    if not term_chan then
      debug_print("Terminal channel not found")
      return
    end
    
    -- Send input with newline
    vim.api.nvim_chan_send(term_chan, input .. "\n")
    debug_print("Sent input: " .. input)
  end
  
  -- Enter terminal mode automatically
  vim.cmd('startinsert')
  
  debug_print("Terminal with jobstart+PTY created successfully")
  debug_print("Job ID: " .. job_id)
  
  return {
    buf = buf,
    win = win,
    job_id = job_id
  }
end

-- Run the test
local result = test_jobstart_pty()

-- Print instructions
vim.defer_fn(function()
  vim.api.nvim_out_write("\n")
  vim.api.nvim_out_write("Test terminal created.\n")
  vim.api.nvim_out_write("- Press i to enter terminal mode and interact with the process\n")
  vim.api.nvim_out_write("- Press <ESC><ESC> to exit terminal mode\n")
  vim.api.nvim_out_write("- Press q in normal mode to close the terminal\n")
  vim.api.nvim_out_write("- Run :lua send_to_terminal(\"print('test')\") to send commands programmatically\n")
end, 500) -- Small delay to make sure terminal is set up first 