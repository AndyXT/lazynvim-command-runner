local M = {}

local popup = require("command_runner.ui.popup")
local status = require("command_runner.ui.status")
local documentation = require("command_runner.ui.documentation")
local validation_core = require("command_runner.core.validation")

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
function M.show_output(result, cmd_table, on_close)
  local lines = vim.split(result.output, "\n", { plain = true })
  local title = result.success and "Command Output" or "Command Failed"
  local highlight = result.success and "Normal" or "ErrorFloat"
  
  -- Show documentation window if available
  local doc_window = nil
  if cmd_table.expected_output or cmd_table.explanation then
    doc_window = documentation.show_documentation_window(cmd_table)
  end

  if not result.success then
    table.insert(lines, 1, "⚠️  Command failed with code " .. tostring(result.code) .. " (Press 'e' for details)")
    table.insert(lines, 2, string.rep("-", 50))
  end
  
  -- Add validation results if present
  if result.validation_results and not result.validation_results.passed then
    table.insert(lines, 1, "❌ Validation failed (Press 'v' to view details)")
    table.insert(lines, 2, string.rep("-", 50))
    highlight = "WarningFloat"
  elseif result.validation_results and result.validation_results.passed then
    table.insert(lines, 1, "✅ Validation passed")
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
      if doc_window then
        doc_window.close()
      end
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
    
    -- Add keymapping for validation details
    if result.validation_results and not result.validation_results.passed then
      vim.keymap.set("n", "v", function()
        validation_core.show_validation_failures(result.validation_results, popup)
      end, { buffer = buf, noremap = true, silent = true })
    end

    -- Pipe output mapping
    vim.keymap.set({ "n", "v" }, "p", function()
      local choices = {
        "Line at cursor",
        "Entire output",
        "Visual selection",
        "Filtered by pattern",
        "Interactive selection"
      }

      vim.ui.select(choices, { prompt = "Select what to pipe:" }, function(choice)
        if choice then
          if choice == "Line at cursor" then
            local cpos = vim.api.nvim_win_get_cursor(win_id)
            local line = lines[cpos[1]] or ""
            LAST_OUTPUT = { line }
            -- Cache this for reference
            if require("command_runner.core.input") then
              require("command_runner.core.input").cache_value("last_pipe", line)
            end
            status.show("Piping current line", "info")
            close_windows()
          elseif choice == "Visual selection" then
            local start_pos = vim.fn.getpos("'<")
            local end_pos = vim.fn.getpos("'>")
            local selected_lines = vim.api.nvim_buf_get_lines(buf, start_pos[2] - 1, end_pos[2], false)
            LAST_OUTPUT = selected_lines
            -- Cache this for reference
            if require("command_runner.core.input") then
              require("command_runner.core.input").cache_value("last_pipe", table.concat(selected_lines, " "))
            end
            status.show("Piping selection", "info")
            close_windows()
          elseif choice == "Filtered by pattern" then
            -- Allow filtering by pattern
            vim.ui.input({
              prompt = "Enter pattern to filter lines: "
            }, function(pattern)
              if pattern and pattern ~= "" then
                local filtered = {}
                for _, line in ipairs(lines) do
                  if string.find(line, pattern) then
                    table.insert(filtered, line)
                  end
                end
                
                if #filtered > 0 then
                  LAST_OUTPUT = filtered
                  -- Cache this for reference
                  if require("command_runner.core.input") then
                    require("command_runner.core.input").cache_value("last_pipe", table.concat(filtered, " "))
                  end
                  status.show("Piping " .. #filtered .. " filtered lines", "info")
                else
                  status.show("No lines matched the pattern", "warn")
                  return
                end
              else
                return
              end
              close_windows()
            end)
          elseif choice == "Interactive selection" then
            -- Extract tokens from output and let user select
            local all_tokens = {}
            local token_map = {}
            
            -- Identify potential tokens (IDs, etc.)
            local patterns = {
              { pattern = "ID: ([%w%-_]+)", label = "ID" },
              { pattern = "([%w%-_]+)://[%w%.%-/]+", label = "Protocol" },
              { pattern = "([%d%.]+):(%d+)", label = "IP:Port" },
              { pattern = ": ([%w%d%.%-_]+)", label = "Value" },
              { pattern = "^%d+%. (.+)$", label = "List item" },
            }
            
            -- Extract all tokens
            for line_idx, line in ipairs(lines) do
              for _, pattern_info in ipairs(patterns) do
                for match in string.gmatch(line, pattern_info.pattern) do
                  local token = {
                    text = match,
                    line = line,
                    line_idx = line_idx,
                    type = pattern_info.label
                  }
                  
                  -- Only add if unique
                  local key = token.text .. "|" .. token.type
                  if not token_map[key] then
                    token_map[key] = true
                    table.insert(all_tokens, token)
                  end
                end
              end
            end
            
            if #all_tokens == 0 then
              -- No tokens found, just show lines instead
              local numbered_lines = {}
              for i, line in ipairs(lines) do
                if line ~= "" then
                  table.insert(numbered_lines, {
                    text = line,
                    line = line,
                    line_idx = i,
                    type = "Line " .. i
                  })
                end
              end
              all_tokens = numbered_lines
            end
            
            -- Let user select a token
            if #all_tokens > 0 then
              vim.ui.select(all_tokens, {
                prompt = "Select token to pipe:",
                format_item = function(item)
                  if #item.line > 60 then
                    return item.type .. ": " .. item.text .. " | " .. string.sub(item.line, 1, 57) .. "..."
                  else
                    return item.type .. ": " .. item.text .. " | " .. item.line
                  end
                end
              }, function(choice)
                if choice then
                  LAST_OUTPUT = { choice.text }
                  -- Cache this for reference
                  if require("command_runner.core.input") then
                    require("command_runner.core.input").cache_value("last_pipe", choice.text)
                    require("command_runner.core.input").cache_value("last_pipe_line", choice.line)
                  end
                  status.show("Piping token: " .. choice.text, "info")
                  close_windows()
                end
              end)
            else
              status.show("No tokens found in output", "warn")
            end
          else
            -- Entire output
            LAST_OUTPUT = lines
            -- Cache this for reference
            if require("command_runner.core.input") then
              require("command_runner.core.input").cache_value("last_pipe", table.concat(lines, " "))
            end
            status.show("Piping all output", "info")
            close_windows()
          end
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