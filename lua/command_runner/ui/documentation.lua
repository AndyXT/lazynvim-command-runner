local M = {}

function M.show_documentation_window(cmd_table)
  local lines = {}
  
  if cmd_table.expected_output then
    table.insert(lines, "Expected Output:")
    table.insert(lines, string.rep("-", 20))
    table.insert(lines, cmd_table.expected_output)
    table.insert(lines, "")
  end
  
  if cmd_table.explanation then
    table.insert(lines, "Explanation:")
    table.insert(lines, string.rep("-", 20))
    
    -- Split explanation into lines if it's long
    local explanation_lines = vim.split(cmd_table.explanation, "\n", { plain = true })
    vim.list_extend(lines, explanation_lines)
  end
  
  if #lines == 0 then
    return -- Nothing to show
  end
  
  local width = math.floor(vim.o.columns * 0.4)
  local height = math.min(#lines, math.floor(vim.o.lines * 0.3))
  local row = 1
  local col = math.floor((vim.o.columns - width) / 2)
  
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  
  -- Buffer options
  local buf_opts = {
    modifiable = false,
    bufhidden = "wipe",
    buftype = "nofile",
    swapfile = false,
  }
  for opt, value in pairs(buf_opts) do
    vim.api.nvim_buf_set_option(buf, opt, value)
  end
  
  -- Window options
  local win_opts = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = "Command Documentation",
    title_pos = "center",
  }
  
  local win_id = vim.api.nvim_open_win(buf, false, win_opts)
  vim.api.nvim_win_set_option(win_id, "winhl", "Normal:FloatBorder")
  
  -- Close the window when output window is closed
  return {
    buf = buf,
    win_id = win_id,
    close = function()
      if vim.api.nvim_win_is_valid(win_id) then
        vim.api.nvim_win_close(win_id, true)
      end
    end
  }
end

return M