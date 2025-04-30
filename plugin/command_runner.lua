-- Ensure plugin runs once
if vim.g.loaded_command_runner == 1 then
  return
end
vim.g.loaded_command_runner = 1

-- Create the command with default options
vim.api.nvim_create_user_command("CommandRunner", function(opts)
  require("command_runner.core.command").run(opts)
end, {
  nargs = "?",
  desc = "Run commands from a JSON file (accepts optional file path)",
  complete = "file"
})