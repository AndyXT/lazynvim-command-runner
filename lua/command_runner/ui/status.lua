local M = {}

local STATUS_WINDOW = nil

function M.show(msg, level)
  local config = require("command_runner.core.config").options
  
  if not config.status.show then
    return
  end

  if STATUS_WINDOW and vim.api.nvim_win_is_valid(STATUS_WINDOW) then
    vim.api.nvim_win_close(STATUS_WINDOW, true)
  end

  local lines = { msg }
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Create a small floating window for status
  STATUS_WINDOW = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = #msg + 2,
    height = 1,
    row = vim.o.lines - 2,
    col = 0,
    style = "minimal",
    border = "single",
  })

  -- Auto-close after configured duration
  vim.defer_fn(function()
    if STATUS_WINDOW and vim.api.nvim_win_is_valid(STATUS_WINDOW) then
      vim.api.nvim_win_close(STATUS_WINDOW, true)
      STATUS_WINDOW = nil
    end
  end, config.status.duration)
end

return M