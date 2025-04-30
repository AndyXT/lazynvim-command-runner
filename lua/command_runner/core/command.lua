-- command.lua
-- Command execution and management for Command Runner

local M = {}
local config = require("command_runner.core.config")
local ui = require("command_runner.ui.status")

-- State variables
M.COMMANDS = {}
M.LAST_OUTPUT = {}
M.COMMAND_HISTORY = {}
M.HISTORY_INDEX = 1
M.JSON_FILE_PATH = nil

-------------------------------------------------------------------------------
-- Command history management
-------------------------------------------------------------------------------
function M.add_to_history(cmd)
  -- Add to front of history
  table.insert(M.COMMAND_HISTORY, 1, cmd)
  -- Trim history if needed
  if #M.COMMAND_HISTORY > config.options.max_history then
    table.remove(M.COMMAND_HISTORY)
  end
  M.HISTORY_INDEX = 1
end

-------------------------------------------------------------------------------
-- JSON loading
-------------------------------------------------------------------------------
function M.load_commands_from_json(json_file)
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

-------------------------------------------------------------------------------
-- Command file resolution
-------------------------------------------------------------------------------
function M.resolve_command_file(path, default_path)
  -- Allow providing a specific JSON file path
  local cmd_file
  
  if path and path ~= "" then
    -- Use provided file path
    cmd_file = path
  elseif M.JSON_FILE_PATH then
    -- Use cached file path
    cmd_file = M.JSON_FILE_PATH
  elseif default_path then
    -- Use configured default path
    cmd_file = default_path
  else
    -- Default to commands.json in current working directory
    cmd_file = vim.fn.getcwd() .. "/commands.json"
  end
  
  return cmd_file
end

-------------------------------------------------------------------------------
-- Command file loading
-------------------------------------------------------------------------------
function M.load_command_file(file_path)
  -- Store the path for future use
  M.JSON_FILE_PATH = file_path
  
  local list, err = M.load_commands_from_json(file_path)
  if err then
    vim.notify(err, vim.log.levels.ERROR)
    return false
  end

  M.COMMANDS = list
  if #M.COMMANDS == 0 then
    vim.notify("No commands found in JSON file: " .. file_path, vim.log.levels.WARN)
    return false
  end
  
  return true
end

-------------------------------------------------------------------------------
-- Async command execution
-------------------------------------------------------------------------------
function M.run_system_async(cmd_args, callback)
  ui.show_status("Running command...", "info")
  
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

-------------------------------------------------------------------------------
-- Run command with piping support
-------------------------------------------------------------------------------
function M.run_selected_command(cmd_table, on_done)
  local full_cmd
  if #M.LAST_OUTPUT > 0 then
    full_cmd = vim.list_extend(vim.deepcopy(cmd_table), M.LAST_OUTPUT)
  else
    full_cmd = cmd_table
  end

  M.run_system_async(full_cmd, function(result)
    local output_ui = require("command_runner.ui.output")
    output_ui.show_output_popup(result, on_done)
  end)
end

return M