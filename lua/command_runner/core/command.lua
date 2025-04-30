local M = {}

local status = require("command_runner.ui.status")
local output_ui = require("command_runner.ui.output")
local popup = require("command_runner.ui.popup")

-- Command history
local COMMAND_HISTORY = {}
local HISTORY_INDEX = 1
local COMMANDS = {}
local JSON_FILE_PATH = nil

-- Add command to history
local function add_to_history(cmd)
  local config = require("command_runner.core.config").options
  local max_history = config.max_history or 50
  
  -- Add to front of history
  table.insert(COMMAND_HISTORY, 1, cmd)
  -- Trim history if needed
  if #COMMAND_HISTORY > max_history then
    table.remove(COMMAND_HISTORY)
  end
  HISTORY_INDEX = 1
end

-- Read commands from JSON file
local function load_commands_from_json(json_file)
  -- Attempt to read the file
  local ok, lines = pcall(vim.fn.readfile, json_file)
  if not ok then
    return nil, ("Failed to read file: %s"):format(json_file)
  end

  -- Combine lines and decode JSON
  local content = table.concat(lines, "\n")
  local ok_decode, data = pcall(vim.fn.json_decode, content)
  if not ok_decode then
    return nil, ("Failed to parse JSON in %s"):format(json_file)
  end

  -- Validate structure
  if not data.commands or type(data.commands) ~= "table" then
    return nil, ("JSON file %s doesn't contain a valid 'commands' array"):format(json_file)
  end

  -- Return the commands directly
  return data.commands, nil
end

-- Run system command asynchronously
local function run_system_async(cmd_args, callback)
  vim.system(cmd_args, { text = true }, function(obj)
    vim.schedule(function()
      if obj.code ~= 0 then
        callback({
          success = false,
          output = obj.stderr or "Command failed with no error output",
          code = obj.code,
        })
      else
        callback({
          success = true,
          output = obj.stdout == "" and "Command completed with no output" or obj.stdout,
          code = 0,
        })
      end
    end)
  end)
end

-- Execute the selected command
local function run_selected_command(cmd_table, on_done)
  status.show("Running command...", "info")

  local full_cmd
  local last_output = output_ui.get_last_output()
  
  if #last_output > 0 then
    full_cmd = vim.list_extend(vim.deepcopy(cmd_table.command), last_output)
  else
    full_cmd = cmd_table.command
  end

  run_system_async(full_cmd, function(result)
    output_ui.show_output(result, on_done)
  end)
end

-- Display the command list UI
local function show_command_list()
  local display_lines = {}
  local last_output = output_ui.get_last_output()
  
  for i, cmd in ipairs(COMMANDS) do
    local prefix = (#last_output > 0) and "📎 " or "  "
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

    local footer_win = popup.create_footer(win_id, opts, keymap_list)
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
      if #COMMAND_HISTORY > 0 then
        if HISTORY_INDEX < #COMMAND_HISTORY then
          HISTORY_INDEX = HISTORY_INDEX + 1
        end
        local hist_cmd = COMMAND_HISTORY[HISTORY_INDEX]
        if hist_cmd then
          for idx, c in ipairs(COMMANDS) do
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
      if #COMMAND_HISTORY > 0 and HISTORY_INDEX > 1 then
        HISTORY_INDEX = HISTORY_INDEX - 1
        local hist_cmd = COMMAND_HISTORY[HISTORY_INDEX]
        if hist_cmd then
          for idx, c in ipairs(COMMANDS) do
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
      local selected_cmd = COMMANDS[row]
      if selected_cmd then
        local cmd_arr = selected_cmd.command
        add_to_history(cmd_arr)
        close_windows()
        run_selected_command(selected_cmd, function()
          show_command_list()
        end)
      end
    end, { buffer = buf, noremap = true, silent = true })

    -- Clear piped data
    vim.keymap.set("n", "c", function()
      output_ui.clear_last_output()
      close_windows()
      show_command_list()
    end, { buffer = buf, noremap = true, silent = true })
  end

  local popup_opts = {
    title = "Command List",
    title_pos = "center",
    width = math.floor(vim.o.columns * 0.5),
    height = math.floor(vim.o.lines * 0.4),
    border = "rounded",
  }

  popup.create(display_lines, keymaps, popup_opts)
end

-- Main entry point
function M.run(opts)
  local config = require("command_runner.core.config").options
  
  -- Allow providing a specific JSON file path
  local cmd_file
  
  if opts and opts.args and opts.args ~= "" then
    -- Use provided file path
    cmd_file = opts.args
  elseif JSON_FILE_PATH then
    -- Use cached file path
    cmd_file = JSON_FILE_PATH
  elseif config.default_json_path then
    -- Use configured default path
    cmd_file = config.default_json_path
  else
    -- Default to commands.json in current working directory
    cmd_file = vim.fn.getcwd() .. "/commands.json"
  end
  
  -- Store the path for future use
  JSON_FILE_PATH = cmd_file
  
  local list, err = load_commands_from_json(cmd_file)
  if err then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  COMMANDS = list
  if #COMMANDS == 0 then
    vim.notify("No commands found in JSON file: " .. cmd_file, vim.log.levels.WARN)
    return
  end

  show_command_list()
end

return M