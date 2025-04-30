local M = {}

-- Create a footer window with keymap hints
function M.create_footer(parent_win, parent_opts, keymaps)
  local buf = vim.api.nvim_create_buf(false, true)

  -- Format keymap text
  local keymap_text = {}
  for _, map in ipairs(keymaps) do
    table.insert(keymap_text, string.format("%s: %s", map[1], map[2]))
  end
  local footer_text = table.concat(keymap_text, " | ")

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { footer_text })

  -- Get parent window position
  local win_config = vim.api.nvim_win_get_config(parent_win)
  local parent_row = type(win_config.row) == "number" and win_config.row or win_config.row[false]
  local parent_col = type(win_config.col) == "number" and win_config.col or win_config.col[false]
  local parent_height = win_config.height

  -- Create footer window just below the parent
  local footer_win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = parent_opts.width,
    height = 1,
    row = parent_row + parent_height + 1,
    col = parent_col,
    style = "minimal",
    border = "rounded",
    focusable = false,
    zindex = 100,
  })

  vim.api.nvim_win_set_option(footer_win, "winhl", "Normal:FloatBorder")
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

  return footer_win
end

-- Create a popup window with content and keymaps
function M.create(lines, keymaps_fn, opts)
  local config = require("command_runner.core.config").options
  
  opts = opts or {}
  local width = opts.width or math.floor(vim.o.columns * config.popup.width)
  local height = opts.height or math.floor(vim.o.lines * config.popup.height)
  local row = opts.row or math.floor((vim.o.lines - height) / 2)
  local col = opts.col or math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)

  -- Set content
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
    border = opts.border or config.popup.border,
  }

  -- Only add title options if title is set
  if opts.title then
    win_opts.title = opts.title
    win_opts.title_pos = opts.title_pos or "center"
  end

  local win_id = vim.api.nvim_open_win(buf, true, win_opts)

  -- Highlight
  if opts.highlight then
    vim.api.nvim_win_set_option(win_id, "winhl", "Normal:" .. opts.highlight)
  end

  -- Keymaps
  if keymaps_fn then
    keymaps_fn(buf, win_id, opts)
  end

  return buf, win_id
end

return M