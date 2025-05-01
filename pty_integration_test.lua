-- Test script to integrate the new PTY terminal with Command Runner
-- Run with: nvim -u NONE -l pty_integration_test.lua

-- Add basic vim.o utilities if running with -u NONE
if not vim.opt or not vim.keymap then
  vim.opt = {}
  vim.keymap = {}
  vim.keymap.set = vim.api.nvim_set_keymap
end

-- Debug logging
local debug_mode = true
local function debug_print(msg)
  if debug_mode then
    vim.api.nvim_out_write("PTY Test: " .. msg .. "\n")
  end
end

-- Load the new PTY terminal module with error handling
local pty_terminal
local ok, err = pcall(function()
  pty_terminal = dofile("lua/command_runner/core/pty_terminal.lua")
end)

if not ok then
  debug_print("Failed to load pty_terminal module: " .. err)
  vim.api.nvim_out_write("ERROR: Could not load the pty_terminal module!\n")
  vim.api.nvim_out_write("Reason: " .. err .. "\n")
  vim.api.nvim_out_write("Make sure the file exists at lua/command_runner/core/pty_terminal.lua\n")
  return
end

-- Sample configuration
local config = {
  terminal = {
    enabled = true,
    height = 15,
    auto_detect_interactive = true,
    force_terminal_commands = {
      "top", "htop", "nano", "vim", "ssh", 
      "mysql", "psql", "python", "node"
    },
    split_type = "bottom", -- Can be "bottom", "right", "float", or "tab"
    window_width = 0.5,     -- Width ratio for right split
    keep_focus = false,     -- Whether to keep focus on terminal
    close_on_exit = false,  -- Auto-close terminal on command exit
    preserve_window = true, -- Keep terminal window after command is done
    use_dedicated_tab = true -- Use a dedicated tab for terminal
  }
}

-- Mock the config module (needed by the terminal module)
package.loaded["command_runner.core.config"] = {
  options = config
}

-- Get a suitable command for testing
local function get_test_commands()
  local commands = {}
  
  -- Basic system commands
  commands.ls = {"ls", "-la"}
  
  -- Interactive shells
  if vim.fn.executable("python3") == 1 then
    commands.python = {"python3"}
  elseif vim.fn.executable("python") == 1 then
    commands.python = {"python"}
  else
    commands.python = nil
  end
  
  -- System monitoring
  if vim.fn.executable("top") == 1 then
    commands.top = {"top"}
  else
    commands.top = nil
  end
  
  -- Network tools
  if vim.fn.executable("ping") == 1 then
    commands.ping = {"ping", "-c", "5", "localhost"}
  else
    commands.ping = nil
  end
  
  -- Default shell
  commands.shell = {vim.o.shell}
  
  return commands
end

local test_commands = get_test_commands()

-- Function to test terminal with various commands
local function test_command(cmd, description)
  if not cmd then
    debug_print("Command not available, skipping test")
    return nil
  end
  
  vim.api.nvim_out_write("\n")
  vim.api.nvim_out_write("========================================\n")
  vim.api.nvim_out_write("Testing: " .. description .. "\n")
  vim.api.nvim_out_write("Command: " .. (type(cmd) == "table" and table.concat(cmd, " ") or cmd) .. "\n")
  vim.api.nvim_out_write("========================================\n")
  
  -- Run the command in a terminal
  local term_result = pty_terminal.run_in_terminal(cmd, {
    height = 15,
    autoclose = false,
    on_exit = function(code)
      debug_print("Command exited with code: " .. code)
    end,
    start_insert = true,
    auto_insert = true,
    keep_focus = true
  })
  
  if term_result then
    debug_print("Terminal created successfully with job_id: " .. term_result.job_id)
    
    -- If you want to send input to the terminal (example for Python REPL)
    if type(cmd) == "table" and (cmd[1] == "python3" or cmd[1] == "python") then
      vim.defer_fn(function()
        debug_print("Sending command to Python REPL: print('Hello from Python')")
        pty_terminal.send_input(term_result.id, "print('Hello from Python')\n")
      end, 1000)
    end
    
    return term_result
  else
    debug_print("Failed to create terminal")
    return nil
  end
end

-- Show menu to test different commands
local function show_test_menu()
  vim.api.nvim_out_write("\nChoose a command to test:\n")
  vim.api.nvim_out_write("1. Simple command (ls -la)\n")
  vim.api.nvim_out_write("2. Interactive command (python/shell)\n")
  vim.api.nvim_out_write("3. System monitoring (top)\n")
  vim.api.nvim_out_write("4. Network test (ping localhost)\n")
  vim.api.nvim_out_write("5. Default shell\n")
  vim.api.nvim_out_write("q. Quit\n")
  
  local choice = vim.fn.input("Enter choice: ")
  vim.api.nvim_out_write("\n")  -- Add newline after input
  
  if choice == "1" then
    test_command(test_commands.ls, "Simple directory listing")
  elseif choice == "2" then
    if test_commands.python then 
      test_command(test_commands.python, "Python REPL")
    else
      test_command(test_commands.shell, "Default shell")
    end
  elseif choice == "3" then
    if test_commands.top then
      test_command(test_commands.top, "System monitoring")
    else
      vim.api.nvim_out_write("Top command not available on this system\n")
      vim.defer_fn(show_test_menu, 1000)
    end
  elseif choice == "4" then
    if test_commands.ping then
      test_command(test_commands.ping, "Network test")
    else
      vim.api.nvim_out_write("Ping command not available on this system\n")
      vim.defer_fn(show_test_menu, 1000)
    end
  elseif choice == "5" then
    test_command(test_commands.shell, "Default shell")
  elseif choice:lower() == "q" then
    vim.api.nvim_out_write("Exiting test...\n")
    return
  else
    vim.api.nvim_out_write("Invalid choice, try again\n")
    vim.defer_fn(show_test_menu, 1000)
    return
  end
  
  -- Show menu again after a delay
  vim.defer_fn(function()
    vim.api.nvim_out_write("\nPress any key to return to the menu...")
    vim.fn.getchar()
    show_test_menu()
  end, 2000)
end

-- Main test function
local function main()
  vim.api.nvim_out_write("==== PTY Terminal Integration Test ====\n")
  vim.api.nvim_out_write("This test demonstrates the integration of the new PTY terminal\n")
  vim.api.nvim_out_write("module with Command Runner plugin.\n\n")
  
  -- Display detected commands
  vim.api.nvim_out_write("Detected commands on your system:\n")
  for name, cmd in pairs(test_commands) do
    if cmd then
      vim.api.nvim_out_write("- " .. name .. ": " .. table.concat(cmd, " ") .. "\n")
    end
  end
  
  -- Start the test menu
  show_test_menu()
end

-- Run the main test function
main() 