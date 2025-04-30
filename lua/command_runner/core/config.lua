-- config.lua
-- Configuration management for Command Runner

local M = {}

-- Default configuration
M.options = {
  command_name = "CommandRunner",
  default_json_path = nil, -- Default to CWD/commands.json
  max_history = 50,
  popup_width = 0.5,      -- Percentage of screen width
  popup_height = 0.4,     -- Percentage of screen height
  popup_border = "rounded",
  highlight_success = "Normal",
  highlight_error = "ErrorFloat",
  highlight_warning = "WarningFloat",
}

-- Setup function
function M.setup(opts)
  -- Merge user options with defaults
  for k, v in pairs(opts) do
    M.options[k] = v
  end
end

return M