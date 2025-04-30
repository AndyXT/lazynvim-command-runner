local M = {}

M.defaults = {
  command_name = "CommandRunner",
  default_json_path = nil, -- Will use CWD by default
  max_history = 50,
  popup = {
    width = 0.5, -- 50% of screen width
    height = 0.4, -- 40% of screen height
    border = "rounded",
  },
  status = {
    show = true,
    duration = 3000, -- milliseconds
  }
}

M.options = {}

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

return M