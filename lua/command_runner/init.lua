-- Command Runner Plugin for Neovim
-- A tool for running and managing shell commands from JSON configuration files

-- Module table
local M = {}

-- Import dependencies
local config = require("command_runner.core.config")
local command = require("command_runner.core.command")
local ui = require("command_runner.ui.popup")

-------------------------------------------------------------------------------
-- Main entry point
-------------------------------------------------------------------------------
function M.run(opts)
  -- Parse options
  local cmd_file = command.resolve_command_file(opts and opts.args, config.options.default_json_path)
  
  -- Load commands and show UI
  local success = command.load_command_file(cmd_file)
  if success then
    ui.show_command_list()
  end
end

-------------------------------------------------------------------------------
-- Setup function for plugin configuration
-------------------------------------------------------------------------------
function M.setup(opts)
  -- Apply user configuration
  config.setup(opts or {})
  
  -- Return the module for chaining
  return M
end

-- Return module
return M