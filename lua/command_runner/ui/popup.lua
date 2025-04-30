-- popup.lua
-- Popup window UI components for Command Runner

local M = {}
local config = require("command_runner.core.config")
local command = require("command_runner.core.command")
local status = require("command_runner.ui.status")

-------------------------------------------------------------------------------
-- Footer helper
-------------------------------------------------------------------------------
local function create_footer(parent_win, parent_opts, keymaps)
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

-------------------------------------------------------------------------------
-- Generic popup creator
-------------------------------------------------------------------------------
M.create_popup = function(lines, keymaps_fn, opts)
  opts = opts or {}
  local width = opts.width or math.floor(vim.o.columns * config.options.popup_width)
  local height = opts.height or math.floor(vim.o.lines * config.options.popup_height)
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
    border = opts.border or config.options.popup_border,
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
    keymaps_fn(buf, win_id, win_opts)
  end

  return buf, win_id
end

-------------------------------------------------------------------------------
-- Show command list
-------------------------------------------------------------------------------
function M.show_command_list()
  local display_lines = {}
  for i, cmd in ipairs(command.COMMANDS) do
    local prefix = (#command.LAST_OUTPUT > 0) and "📎 " or "  "
    local cmd_str = table.concat(cmd.command, " ")
    local desc = cmd.description or ""
    display_lines[i] = string.format("%s%-30s │ %s", prefix, cmd_str, desc)
  end

  local function keymaps(buf, win_id, opts)
    local keymap_list = {
      { "⏎", "Run command" },
      { "c", "Clear pipe" },
      { "q", "Quit" },
    }

    local footer_win = create_footer(win_id, opts, keymap_list)
    vim.b[buf].footer_win = footer_win

    local function close_windows()
      if vim.api.nvim_win_is_valid(footer_win) then
        vim.api.nvim_win_close(footer_win, true)
      end
      vim.api.nvim_win_close(win_id, true)
    end

    vim.keymap.set("n", "<Esc>", close_windows, { buffer = buf, noremap = true, silent = true })
    vim.keymap.set("n", "q", close_windows, { buffer = buf, noremap = true, silent = true })

    -- History navigation
    vim.keymap.set("n", "p", function()
      if #command.COMMAND_HISTORY > 0 then
        if command.HISTORY_INDEX < #command.COMMAND_HISTORY then
          command.HISTORY_INDEX = command.HISTORY_INDEX + 1
        end
        local hist_cmd = command.COMMAND_HISTORY[command.HISTORY_INDEX]
        if hist_cmd then
          for idx, c in ipairs(command.COMMANDS) do
            local arr = c.command or c
            if vim.deep_equal(arr, hist_cmd) then
              vim.api.nvim_win_set_cursor(win_id, { idx, 0 })
              break
            end
          end
        end
      end
    end, { buffer = buf, noremap = true, silent = true })

    vim.keymap.set("n", "n", function()
      if #command.COMMAND_HISTORY > 0 and command.HISTORY_INDEX > 1 then
        command.HISTORY_INDEX = command.HISTORY_INDEX - 1
        local hist_cmd = command.COMMAND_HISTORY[command.HISTORY_INDEX]
        if hist_cmd then
          for idx, c in ipairs(command.COMMANDS) do
            local arr = c.command or c
            if vim.deep_equal(arr, hist_cmd) then
              vim.api.nvim_win_set_cursor(win_id, { idx, 0 })
              break
            end
          end
        end
      end
    end, { buffer = buf, noremap = true, silent = true })

    -- Run command under cursor
    vim.keymap.set("n", "<CR>", function()
      local cursor = vim.api.nvim_win_get_cursor(win_id)
      local row = cursor[1]
      local selected_cmd = command.COMMANDS[row]
      if selected_cmd then
        local cmd_arr = selected_cmd.command
        command.add_to_history(cmd_arr)
        close_windows()
        command.run_selected_command(cmd_arr, function()
          M.show_command_list()
        end)
      end
    end, { buffer = buf, noremap = true, silent = true })

    -- Clear piped data
    vim.keymap.set("n", "c", function()
      command.LAST_OUTPUT = {}
      status.show_status("Cleared piped data", "info")
      close_windows()
      M.show_command_list()
    end, { buffer = buf, noremap = true, silent = true })
  end

  local popup_opts = {
    title = "Command List",
    title_pos = "center",
    width = math.floor(vim.o.columns * config.options.popup_width),
    height = math.floor(vim.o.lines * config.options.popup_height),
    border = config.options.popup_border,
  }

  M.create_popup(display_lines, keymaps, popup_opts)
end

return M