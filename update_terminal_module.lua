-- Script to help integrate the PTY terminal module into Command Runner

-- Load required modules 
local pty_terminal = require("command_runner.core.pty_terminal")

-- Print header
print("\n=== Command Runner Terminal Module Integration ===\n")
print("This script demonstrates how to integrate the new PTY terminal module")
print("into your Command Runner plugin.")
print("\nMaking these changes to your code:")

-- 1. First integration point - in command.lua
print("\n1. In command.lua, replace the terminal creation code with:")
print([[
  -- For interactive commands, use the PTY terminal module
  if is_interactive then
    -- Debug notification
    vim.api.nvim_echo({{"Command Runner: Creating terminal for interactive command", "MoreMsg"}}, true, {})
    
    -- Use the proper terminal module to create a terminal window
    local term_opts = {
      height = terminal_config.height or 15,
      autoclose = terminal_config.close_on_exit or false,
      on_exit = function(code)
        vim.schedule(function()
          callback({
            success = code == 0,
            output = "Command executed in terminal window",
            code = code,
            terminal_used = true
          })
        end)
      end,
      start_insert = true,
      auto_insert = true,
      keep_focus = terminal_config.keep_focus or false
    }
    
    -- Use the pty_terminal module for better PTY support
    local term_result = pty_terminal.run_in_terminal(cmd_args, term_opts)
    
    if term_result then
      vim.api.nvim_echo({{"Command Runner: Terminal created successfully", "MoreMsg"}}, true, {})
      terminal_buf = term_result.buf
      term_win = term_result.win
      job_id = term_result.job_id
      
      if term_result.job_id then
        return term_result.job_id
      else
        return 9999 -- Placeholder ID if job_id not available
      end
    end
  }
]])

-- 2. Add the required module
print("\n2. Add this require at the top of command.lua:")
print([[
local pty_terminal = require("command_runner.core.pty_terminal")
]])

-- 3. Integration with UI module
print("\n3. In output.lua, add this function to focus the terminal when needed:")
print([[
function M.focus_terminal(term_buf, term_win)
  if term_win and vim.api.nvim_win_is_valid(term_win) then
    vim.api.nvim_set_current_win(term_win)
    if term_buf and vim.api.nvim_buf_is_valid(term_buf) then
      -- Also enter terminal mode
      vim.cmd("startinsert")
    end
  end
end
]])

-- 4. Add key mapping for the 't' key
print("\n4. In output.lua, add this key mapping to allow focusing the terminal:")
print([[
  -- Terminal focus
  if result.terminal_used and result.terminal_win then
    vim.keymap.set("n", "t", function()
      M.focus_terminal(result.terminal_buf, result.terminal_win)
    end, { buffer = buf, noremap = true, silent = true })
  end
]])

-- Key points
print("\n=== Key Points for Integration ===")
print("1. The pty_terminal.lua file should be placed in lua/command_runner/core/")
print("2. Make sure you're using vim.b[buf].terminal_job_id instead of vim.api.nvim_buf_set_var")
print("3. When creating a terminal, set buftype=nofile first, then filetype=terminal after jobstart")
print("4. Use the valid window dimensions for the terminal size")
print("5. Make sure to handle popup window contexts properly")

-- Test instructions
print("\n=== Testing Instructions ===")
print("1. Run the standalone tests with: nvim -u NONE -l jobstart_pty_test.lua")
print("2. Test the integration with: nvim -u NONE -l pty_integration_test.lua")
print("3. After integration, test with interactive commands like python, top, etc.")

print("\n=== End of Integration Guide ===\n")

return {
  pty_terminal = pty_terminal,
  
  -- Sample implementation to demonstrate sending input to a terminal
  send_input = function(term_id, input)
    return pty_terminal.send_input(term_id, input)
  end,
  
  -- Sample implementation to demonstrate creating a terminal
  create_terminal = function(cmd, opts)
    return pty_terminal.create_terminal(cmd, opts)
  end
} 