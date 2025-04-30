local M = {}

function M.setup(opts)
  -- Load configuration
  require("command_runner.core.config").setup(opts)
  
  -- Setup the command
  local config = require("command_runner.core.config").options
  local cmd_name = config.command_name or "CommandRunner"
  
  vim.api.nvim_create_user_command(cmd_name, function(cmd_opts)
    require("command_runner.core.command").run(cmd_opts)
  end, {
    nargs = "?",
    desc = "Run commands from a JSON file (accepts optional file path)",
    complete = "file"
  })
  
  return M
end

return M