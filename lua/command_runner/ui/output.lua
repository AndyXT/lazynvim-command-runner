-- output.lua
-- Output display functions for Command Runner

local M = {}
local config = require("command_runner.core.config")
local command = require("command_runner.core.command")
local status = require("command_runner.ui.status")

-------------------------------------------------------------------------------
-- Show error details
-------------------------------------------------------------------------------
local function show_error_details(result)
  local lines = {
    "Command failed with code: " .. tostring(result.code),
    "Error output:",
    "-------------------",
  }
  vim.list_extend(lines, vim.split(result.output, "\n", { plain = true }))

  local popup_opts = {
    title = "Error Details",
    title_pos = "center",
    width = math.floor(vim.o.columns * 0.6),
    height = math.min(#lines + 2, math.floor(vim.o.lines * 0.4)),
    border = "rounded",
    highlight = "ErrorFloat",
  }

  local function keymaps(buf, win_id, opts)
    local function close_win()
      vim.api.nvim_win_close(win_id, true)
    end
    vim.keymap.set("n", "<Esc>", close_win, { buffer = buf, noremap = true, silent = true })
    vim.keymap.set("n", "q", close_win, { buffer = buf, noremap = true, silent = true })
  end

  local popup = require("command_runner.ui.popup")
  popup.create_popup(lines, keymaps, popup_opts)
end

-------------------------------------------------------------------------------
-- Create a footer window with keymap hints
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

-- Using create_popup from popup.lua

-------------------------------------------------------------------------------
-- Show command output
-------------------------------------------------------------------------------
function M.show_output_popup(result, on_close)
  local lines = vim.split(result.output, "\n", { plain = true })
  local title = result.success and "Command Output" or "Command Failed"
  local highlight = result.success and config.options.highlight_success or config.options.highlight_error

  if not result.success then
    table.insert(lines, 1, "⚠️  Command failed with code " .. tostring(result.code) .. " (Press 'e' for details)")
    table.insert(lines, 2, string.rep("-", 50))
  end

  local function keymaps(buf, win_id, opts)
    local keymap_list = {
      { "p", "Pipe output" },
      { "n", "Skip pipe" },
      { "v", "Visual select" },
      { "q", "Quit" },
    }

    local footer_win = create_footer(win_id, opts, keymap_list)
    vim.b[buf].footer_win = footer_win

    vim.api.nvim_buf_set_option(buf, "modifiable", false)
    vim.api.nvim_win_set_cursor(win_id, { 1, 0 })

    local function close_windows()
      if vim.api.nvim_win_is_valid(footer_win) then
        vim.api.nvim_win_close(footer_win, true)
      end
      if on_close then
        on_close()
      end
      vim.api.nvim_win_close(win_id, true)
    end

    -- Close mappings
    vim.keymap.set("n", "<Esc>", close_windows, { buffer = buf, noremap = true, silent = true })
    vim.keymap.set("n", "q", close_windows, { buffer = buf, noremap = true, silent = true })

    -- Error details if failed
    if not result.success then
      vim.keymap.set("n", "e", function()
        show_error_details(result)
      end, { buffer = buf, noremap = true, silent = true })
    end

    -- Pipe output mapping
    vim.keymap.set({ "n", "v" }, "p", function()
      local choices = {
        "Line at cursor",
        "Entire output",
        "Visual selection",
      }

      vim.ui.select(choices, { prompt = "Select what to pipe:" }, function(choice)
        if choice then
          if choice == "Line at cursor" then
            local cpos = vim.api.nvim_win_get_cursor(win_id)
            local line = lines[cpos[1]] or ""
            command.LAST_OUTPUT = { line }
            status.show_status("Piping current line", "info")
          elseif choice == "Visual selection" then
            local start_pos = vim.fn.getpos("'<")
            local end_pos = vim.fn.getpos("'>")
            local selected_lines = vim.api.nvim_buf_get_lines(buf, start_pos[2] - 1, end_pos[2], false)
            command.LAST_OUTPUT = selected_lines
            status.show_status("Piping selection", "info")
          else
            command.LAST_OUTPUT = lines
            status.show_status("Piping all output", "info")
          end
          close_windows()
        end
      end)
    end, { buffer = buf, noremap = true, silent = true })

    -- Skip piping
    vim.keymap.set("n", "n", function()
      command.LAST_OUTPUT = {}
      status.show_status("Skipping pipe", "info")
      close_windows()
    end, { buffer = buf, noremap = true, silent = true })
  end

  local popup_opts = {
    title = title,
    title_pos = "center",
    highlight = highlight,
    width = math.floor(vim.o.columns * config.options.popup_width),
    height = math.floor(vim.o.lines * config.options.popup_height),
    border = config.options.popup_border,
  }

  local popup = require("command_runner.ui.popup")
  popup.create_popup(lines, keymaps, popup_opts)
end

return M