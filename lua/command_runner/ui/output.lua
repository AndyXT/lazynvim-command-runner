local M = {}

local popup = require("command_runner.ui.popup")
local status = require("command_runner.ui.status")

-- Global output state
local LAST_OUTPUT = {}

function M.get_last_output()
  return LAST_OUTPUT
end

function M.clear_last_output()
  LAST_OUTPUT = {}
  status.show("Cleared piped data", "info")
end

-- Show error details popup
function M.show_error_details(result)
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

  popup.create(lines, keymaps, popup_opts)
end

-- Show output popup after running a command
function M.show_output(result, on_close)
  local lines = vim.split(result.output, "\n", { plain = true })
  local title = result.success and "Command Output" or "Command Failed"
  local highlight = result.success and "Normal" or "ErrorFloat"

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

    local footer_win = popup.create_footer(win_id, opts, keymap_list)
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
        M.show_error_details(result)
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
            LAST_OUTPUT = { line }
            status.show("Piping current line", "info")
          elseif choice == "Visual selection" then
            local start_pos = vim.fn.getpos("'<")
            local end_pos = vim.fn.getpos("'>")
            local selected_lines = vim.api.nvim_buf_get_lines(buf, start_pos[2] - 1, end_pos[2], false)
            LAST_OUTPUT = selected_lines
            status.show("Piping selection", "info")
          else
            LAST_OUTPUT = lines
            status.show("Piping all output", "info")
          end
          close_windows()
        end
      end)
    end, { buffer = buf, noremap = true, silent = true })

    -- Skip piping
    vim.keymap.set("n", "n", function()
      LAST_OUTPUT = {}
      status.show("Skipping pipe", "info")
      close_windows()
    end, { buffer = buf, noremap = true, silent = true })
  end

  local popup_opts = {
    title = title,
    title_pos = "center",
    highlight = highlight,
    width = math.floor(vim.o.columns * 0.5),
    height = math.floor(vim.o.lines * 0.4),
    border = "rounded",
  }

  popup.create(lines, keymaps, popup_opts)
end

return M