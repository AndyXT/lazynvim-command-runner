-- command_runner.lua
-- Plugin registration for Command Runner

if vim.g.loaded_command_runner then
  return
end
vim.g.loaded_command_runner = true

-- Create user command
vim.api.nvim_create_user_command("CommandRunner", function(opts)
  require("command_runner").run(opts)
end, {
  nargs = "?",
  desc = "Run commands from a JSON file (accepts optional file path)",
  complete = "file"
})