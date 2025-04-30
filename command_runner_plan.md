# Command Runner Plugin Enhancement Plan

## Overview

This document outlines a comprehensive plan to enhance the existing Command Runner Neovim plugin, adding new functionality to improve integration testing workflows. The plugin will allow users to run shell commands from a predefined list, validate output, pipe data between commands, and organize workflows into sequences.

## Core Enhancement Areas

1. **Validation System**: Verify command outputs against expected patterns
2. **Variable Substitution**: Extract and reuse data between commands
3. **Command Chains**: Create sequences of dependent commands
4. **Multiple JSON Configuration Files**: Support different test suites
5. **Enhanced UI**: Better filtering, navigation, and visual feedback
6. **Command Output Documentation**: Show expected outputs and explanations

## Implementation Phases

### Phase 1: Validation System

#### Implementation Details

Add a validation system to verify command outputs meet expected criteria:

```lua
-- Add to your plugin
local function validate_command_output(result, validation_rules)
  if not validation_rules then return true end
  
  local validation_results = {
    passed = true,
    failures = {}
  }
  
  -- Simple text search validation
  if validation_rules.contains then
    for _, pattern in ipairs(validation_rules.contains) do
      if not string.find(result.output, pattern) then
        validation_results.passed = false
        table.insert(validation_results.failures, {
          type = "contains",
          pattern = pattern,
          message = "Expected output to contain: " .. pattern
        })
      end
    end
  end
  
  -- Regular expression validation
  if validation_rules.matches then
    for _, pattern in ipairs(validation_rules.matches) do
      if not string.match(result.output, pattern) then
        validation_results.passed = false
        table.insert(validation_results.failures, {
          type = "matches",
          pattern = pattern,
          message = "Expected output to match pattern: " .. pattern
        })
      end
    end
  end
  
  -- Exit code validation
  if validation_rules.exit_code and result.code ~= validation_rules.exit_code then
    validation_results.passed = false
    table.insert(validation_results.failures, {
      type = "exit_code",
      expected = validation_rules.exit_code,
      actual = result.code,
      message = "Expected exit code " .. validation_rules.exit_code .. " but got " .. result.code
    })
  end
  
  -- Line count validation
  if validation_rules.line_count then
    local lines = vim.split(result.output, "\n", { plain = true })
    local line_count = #lines
    
    if type(validation_rules.line_count) == "number" then
      if line_count ~= validation_rules.line_count then
        validation_results.passed = false
        table.insert(validation_results.failures, {
          type = "line_count",
          expected = validation_rules.line_count,
          actual = line_count,
          message = "Expected " .. validation_rules.line_count .. " lines but got " .. line_count
        })
      end
    elseif type(validation_rules.line_count) == "table" then
      -- Handle range: {min = x, max = y}
      if validation_rules.line_count.min and line_count < validation_rules.line_count.min then
        validation_results.passed = false
        table.insert(validation_results.failures, {
          type = "line_count_min",
          expected = validation_rules.line_count.min,
          actual = line_count,
          message = "Expected at least " .. validation_rules.line_count.min .. " lines but got " .. line_count
        })
      end
      
      if validation_rules.line_count.max and line_count > validation_rules.line_count.max then
        validation_results.passed = false
        table.insert(validation_results.failures, {
          type = "line_count_max",
          expected = validation_rules.line_count.max,
          actual = line_count,
          message = "Expected at most " .. validation_rules.line_count.max .. " lines but got " .. line_count
        })
      end
    end
  end
  
  return validation_results
end
```

#### JSON Format Update

```json
{
  "commands": [
    {
      "command": ["ls", "-la"],
      "description": "List files with details",
      "validation": {
        "contains": ["total", ".git"],
        "matches": ["d[rwx-]{9}"],
        "exit_code": 0,
        "line_count": {
          "min": 5
        }
      },
      "expected_output": "Should list all files including hidden ones with details like permissions",
      "explanation": "The command should show the .git directory if we're in a git repository"
    }
  ]
}
```

#### Update Command Execution

```lua
local function run_selected_command(cmd_table, on_done)
  show_status("Running command...", "info")

  local full_cmd
  if #LAST_OUTPUT > 0 then
    full_cmd = vim.list_extend(vim.deepcopy(cmd_table.command), LAST_OUTPUT)
  else
    full_cmd = cmd_table.command
  end

  run_system_async(full_cmd, function(result)
    -- Add validation logic
    if cmd_table.validation then
      local validation_results = validate_command_output(result, cmd_table.validation)
      result.validation_results = validation_results
      
      if not validation_results.passed then
        result.validation_failed = true
        -- Keep original success status for the command itself
      end
    end
    
    show_output_popup(result, cmd_table, on_done)
  end)
end
```

#### Show Validation Results in UI

```lua
local function show_output_popup(result, cmd_table, on_close)
  local lines = vim.split(result.output, "\n", { plain = true })
  local title = result.success and "Command Output" or "Command Failed"
  local highlight = result.success and "Normal" or "ErrorFloat"
  
  -- Show documentation window
  if cmd_table.expected_output or cmd_table.explanation then
    show_documentation_window(cmd_table)
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

  -- Rest of your existing function...
  
  -- Add keymapping for validation details
  if result.validation_results and not result.validation_results.passed then
    vim.keymap.set("n", "v", function()
      show_validation_failures(result.validation_results)
    end, { buffer = buf, noremap = true, silent = true })
  end
}
```

#### Show Validation Failures UI

```lua
local function show_validation_failures(validation_results)
  local lines = {
    "Validation Failures",
    string.rep("=", 50)
  }
  
  for _, failure in ipairs(validation_results.failures) do
    table.insert(lines, "- " .. failure.message)
  end
  
  local popup_opts = {
    title = "Validation Failures",
    title_pos = "center",
    width = math.floor(vim.o.columns * 0.5),
    height = math.min(#lines + 2, math.floor(vim.o.lines * 0.3)),
    border = "rounded",
    highlight = "WarningFloat",
  }

  local function keymaps(buf, win_id, opts)
    local function close_win()
      vim.api.nvim_win_close(win_id, true)
    end
    vim.keymap.set("n", "<Esc>", close_win, { buffer = buf, noremap = true, silent = true })
    vim.keymap.set("n", "q", close_win, { buffer = buf, noremap = true, silent = true })
  end

  create_popup(lines, keymaps, popup_opts)
end
```

### Phase 2: Documentation Window

#### Implementation Details

Add a documentation window to show expected output and explanations:

```lua
local function show_documentation_window(cmd_table)
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
```

#### Update Output Popup to Manage Documentation Window

```lua
local function show_output_popup(result, cmd_table, on_close)
  local lines = vim.split(result.output, "\n", { plain = true })
  local title = result.success and "Command Output" or "Command Failed"
  local highlight = result.success and "Normal" or "ErrorFloat"
  
  -- Show documentation window
  local doc_window = nil
  if cmd_table.expected_output or cmd_table.explanation then
    doc_window = show_documentation_window(cmd_table)
  end

  -- ... rest of function ...

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

  -- ... rest of function ...
}
```

### Phase 3: Variable Substitution System

#### Implementation Details

```lua
-- Add to your plugin
local VARIABLES = {}

local function substitute_variables(cmd_arr)
  local result = {}
  for _, part in ipairs(cmd_arr) do
    -- Check if this is a variable reference
    if type(part) == "string" and string.match(part, "^%${.+}$") then
      local var_name = string.match(part, "^%${(.+)}$")
      if VARIABLES[var_name] then
        table.insert(result, VARIABLES[var_name])
      else
        -- Keep original if variable not found
        table.insert(result, part)
      end
    else
      table.insert(result, part)
    end
  end
  return result
end

local function extract_variables(result, extraction_rules)
  if not extraction_rules then return end
  
  local extracted = {}
  for var_name, pattern in pairs(extraction_rules) do
    local match = string.match(result.output, pattern)
    if match then
      VARIABLES[var_name] = match
      extracted[var_name] = match
      show_status("Extracted " .. var_name .. " = " .. match, "info")
    end
  end
  
  return extracted
end

-- Add a function to show current variables
local function show_variables()
  local lines = {}
  table.insert(lines, "Current Variables")
  table.insert(lines, string.rep("=", 30))
  
  local has_variables = false
  for name, value in pairs(VARIABLES) do
    has_variables = true
    table.insert(lines, string.format("%s = %s", name, value))
  end
  
  if not has_variables then
    table.insert(lines, "No variables defined")
  end
  
  local popup_opts = {
    title = "Variables",
    title_pos = "center",
    width = math.floor(vim.o.columns * 0.4),
    height = math.min(#lines + 2, 20),
    border = "rounded",
  }

  local function keymaps(buf, win_id, opts)
    local function close_win()
      vim.api.nvim_win_close(win_id, true)
    end
    
    -- Close window mappings
    vim.keymap.set("n", "<Esc>", close_win, { buffer = buf, noremap = true, silent = true })
    vim.keymap.set("n", "q", close_win, { buffer = buf, noremap = true, silent = true })
    
    -- Add mapping to clear all variables
    vim.keymap.set("n", "c", function()
      VARIABLES = {}
      close_win()
      show_status("All variables cleared", "info")
    end, { buffer = buf, noremap = true, silent = true })
  end

  create_popup(lines, keymaps, popup_opts)
end
```

#### Update Run Command Function

```lua
local function run_selected_command(cmd_table, on_done)
  show_status("Running command...", "info")

  -- Perform variable substitution
  local cmd_with_vars = substitute_variables(cmd_table.command)
  
  local full_cmd
  if #LAST_OUTPUT > 0 then
    full_cmd = vim.list_extend(vim.deepcopy(cmd_with_vars), LAST_OUTPUT)
  else
    full_cmd = cmd_with_vars
  end

  run_system_async(full_cmd, function(result)
    -- Apply validation if present
    if cmd_table.validation then
      local validation_results = validate_command_output(result, cmd_table.validation)
      result.validation_results = validation_results
      
      if not validation_results.passed then
        result.validation_failed = true
      end
    end
    
    -- Extract variables if present
    if cmd_table.extract then
      local extracted = extract_variables(result, cmd_table.extract)
      result.extracted_variables = extracted
    end
    
    show_output_popup(result, cmd_table, on_done)
  end)
end
```

#### Update Command List UI

```lua
local function show_command_list()
  -- ... existing code ...
  
  -- Add 'v' keymapping to show variables
  vim.keymap.set("n", "v", function()
    show_variables()
  end, { buffer = buf, noremap = true, silent = true })
  
  -- Update footer to include the variables keymapping
  local keymap_list = {
    { "⏎", "Run command" },
    { "c", "Clear pipe" },
    { "v", "Show variables" },
    { "q", "Quit" },
  }
  
  -- ... rest of function ...
}
```

#### JSON Format Update

```json
{
  "commands": [
    {
      "command": ["git", "rev-parse", "HEAD"],
      "description": "Get current commit hash",
      "extract": {
        "COMMIT_HASH": "([a-f0-9]+)"
      },
      "expected_output": "A git commit hash (SHA-1)",
      "explanation": "This extracts the current git commit hash and stores it in COMMIT_HASH variable"
    },
    {
      "command": ["git", "show", "${COMMIT_HASH}"],
      "description": "Show commit details",
      "expected_output": "Details of the commit including author, date, and changes"
    }
  ],
  "variables": {
    "BASE_URL": "http://localhost:3000"
  }
}
```

### Phase 4: Command Chains

#### Implementation Details

```lua
local function run_command_chain(chain, final_callback)
  if not chain or not chain.sequence or #chain.sequence == 0 then
    show_status("Invalid chain configuration", "error")
    if final_callback then final_callback() end
    return
  end
  
  -- Find command objects based on their identifiers
  local commands_to_run = {}
  for _, cmd_id in ipairs(chain.sequence) do
    local found = false
    for _, cmd in ipairs(COMMANDS) do
      if cmd.id == cmd_id then
        table.insert(commands_to_run, cmd)
        found = true
        break
      end
    end
    
    if not found then
      show_status("Command '" .. cmd_id .. "' not found", "error")
      if final_callback then final_callback() end
      return
    end
  end
  
  -- Function to run commands sequentially
  local function run_next(index)
    if index > #commands_to_run then
      show_status("Chain completed", "info")
      if final_callback then final_callback() end
      return
    end
    
    local cmd = commands_to_run[index]
    show_status(string.format("Running chain step %d/%d: %s", 
                             index, #commands_to_run, cmd.description or ""), "info")
    
    run_selected_command(cmd, function()
      -- Continue with next command after a brief pause
      vim.defer_fn(function()
        run_next(index + 1)
      end, 500)
    end)
  end
  
  -- Start the chain
  run_next(1)
end
```

#### Add Chain Selection UI

```lua
local function show_chain_list()
  if not LOADED_CONFIG.chains or vim.tbl_isempty(LOADED_CONFIG.chains) then
    show_status("No command chains defined", "warn")
    return
  end
  
  local display_lines = {}
  local chains = {}
  
  for id, chain in pairs(LOADED_CONFIG.chains) do
    local desc = chain.description or ""
    local count = #chain.sequence
    table.insert(display_lines, string.format("%-20s │ %d commands │ %s", id, count, desc))
    table.insert(chains, { id = id, chain = chain })
  end
  
  local function keymaps(buf, win_id, opts)
    local keymap_list = {
      { "⏎", "Run chain" },
      { "q", "Quit" },
    }
    
    local footer_win = create_footer(win_id, opts, keymap_list)
    
    local function close_windows()
      if vim.api.nvim_win_is_valid(footer_win) then
        vim.api.nvim_win_close(footer_win, true)
      end
      vim.api.nvim_win_close(win_id, true)
    end
    
    vim.keymap.set("n", "<Esc>", close_windows, { buffer = buf, noremap = true, silent = true })
    vim.keymap.set("n", "q", close_windows, { buffer = buf, noremap = true, silent = true })
    
    -- Run chain under cursor
    vim.keymap.set("n", "<CR>", function()
      local cursor = vim.api.nvim_win_get_cursor(win_id)
      local row = cursor[1]
      local selected = chains[row]
      if selected then
        close_windows()
        run_command_chain(selected.chain, function()
          show_command_list()
        end)
      end
    end, { buffer = buf, noremap = true, silent = true })
  end
  
  local popup_opts = {
    title = "Command Chains",
    title_pos = "center",
    width = math.floor(vim.o.columns * 0.5),
    height = math.min(#display_lines + 2, math.floor(vim.o.lines * 0.4)),
    border = "rounded",
  }
  
  create_popup(display_lines, keymaps, popup_opts)
end
```

#### Update Main Menu UI to Include Chains

```lua
local function show_command_list()
  -- ... existing code ...
  
  -- Add 'h' keymapping to show chains
  vim.keymap.set("n", "h", function()
    show_chain_list()
  end, { buffer = buf, noremap = true, silent = true })
  
  -- Update footer to include the chains keymapping
  local keymap_list = {
    { "⏎", "Run command" },
    { "c", "Clear pipe" },
    { "v", "Show variables" },
    { "h", "Command chains" },
    { "q", "Quit" },
  }
  
  -- ... rest of function ...
}
```

#### JSON Format Update

```json
{
  "commands": [
    {
      "id": "build",
      "command": ["npm", "run", "build"],
      "description": "Build the project"
    },
    {
      "id": "test",
      "command": ["npm", "test"],
      "description": "Run tests"
    },
    {
      "id": "deploy",
      "command": ["./scripts/deploy.sh"],
      "description": "Deploy to staging"
    }
  ],
  "chains": {
    "full-ci": {
      "description": "Full CI pipeline",
      "sequence": ["build", "test", "deploy"],
      "stop_on_error": true
    }
  }
}
```

### Phase 5: Multiple Configuration Files

#### Implementation Details

```lua
-- Store configurations with their file paths
local CONFIGS = {}
local CURRENT_CONFIG = nil

local function load_config(file_path)
  if CONFIGS[file_path] then
    -- Config already loaded, just switch to it
    COMMANDS = CONFIGS[file_path].commands
    LOADED_CONFIG = CONFIGS[file_path]
    CURRENT_CONFIG = file_path
    JSON_FILE_PATH = file_path
    show_status("Switched to configuration: " .. file_path, "info")
    return true
  end
  
  -- Attempt to load the config
  local commands, err = load_commands_from_json(file_path)
  if err then
    vim.notify(err, vim.log.levels.ERROR)
    return false
  end
  
  -- Read the entire config (not just commands)
  local ok, lines = pcall(vim.fn.readfile, file_path)
  if not ok then
    vim.notify("Failed to read file: " .. file_path, vim.log.levels.ERROR)
    return false
  end
  
  local content = table.concat(lines, "\n")
  local ok_decode, data = pcall(vim.fn.json_decode, content)
  if not ok_decode then
    vim.notify("Failed to parse JSON in " .. file_path, vim.log.levels.ERROR)
    return false
  end
  
  -- Store the entire config
  CONFIGS[file_path] = data
  COMMANDS = commands
  LOADED_CONFIG = data
  CURRENT_CONFIG = file_path
  JSON_FILE_PATH = file_path
  
  -- Initialize global variables from config if present
  if data.variables then
    for name, value in pairs(data.variables) do
      VARIABLES[name] = value
    end
  end
  
  show_status("Loaded configuration: " .. file_path, "info")
  return true
end

local function show_config_list()
  local paths = vim.tbl_keys(CONFIGS)
  if #paths == 0 then
    show_status("No configurations loaded", "warn")
    return
  end
  
  -- Add option to load a new config
  table.insert(paths, "[Load new configuration]")
  
  vim.ui.select(paths, {
    prompt = "Select configuration",
    format_item = function(item)
      if item == CURRENT_CONFIG then
        return item .. " (current)"
      elseif item == "[Load new configuration]" then
        return item
      else
        return item
      end
    end
  }, function(choice)
    if not choice then
      return
    end
    
    if choice == "[Load new configuration]" then
      vim.ui.input({
        prompt = "Enter configuration file path:",
        completion = "file"
      }, function(input)
        if input and input ~= "" then
          if load_config(input) then
            show_command_list()
          end
        end
      end)
    else
      -- Switch to selected config
      load_config(choice)
      show_command_list()
    end
  end)
end
```

#### Update Command Entry Point

```lua
local function my_fancy_command(opts)
  -- Allow providing a specific JSON file path
  local cmd_file
  
  if opts and opts.args and opts.args ~= "" then
    -- Use provided file path
    cmd_file = opts.args
  elseif JSON_FILE_PATH then
    -- Use cached file path
    cmd_file = JSON_FILE_PATH
  else
    -- Default to commands.json in current working directory
    cmd_file = vim.fn.getcwd() .. "/commands.json"
  end
  
  if not load_config(cmd_file) then
    return
  end
  
  show_command_list()
end
```

#### Add Config Selection to Command List UI

```lua
local function show_command_list()
  -- ... existing code ...
  
  -- Add 'f' keymapping to switch configs
  vim.keymap.set("n", "f", function()
    show_config_list()
  end, { buffer = buf, noremap = true, silent = true })
  
  -- Update footer to include the config selection keymapping
  local keymap_list = {
    { "⏎", "Run command" },
    { "c", "Clear pipe" },
    { "v", "Show variables" },
    { "h", "Command chains" },
    { "f", "Switch config" },
    { "q", "Quit" },
  }
  
  -- ... rest of function ...
}
```

### Phase 6: Enhanced UI with Command Filtering

#### Implementation Details

```lua
local function show_command_list(filter_text)
  local display_lines = {}
  local filtered_commands = {}
  
  filter_text = filter_text or ""
  filter_text = string.lower(filter_text)
  
  for i, cmd in ipairs(COMMANDS) do
    local cmd_str = table.concat(cmd.command, " ")
    local desc = cmd.description or ""
    
    -- Apply filtering
    if filter_text == "" or 
       string.find(string.lower(cmd_str), filter_text) or
       string.find(string.lower(desc), filter_text) then
      
      local prefix = (#LAST_OUTPUT > 0) and "📎 " or "  "
      
      -- Add icons based on command properties
      if cmd.validation then
        prefix = prefix .. "✓ "
      else
        prefix = prefix .. "  "
      end
      
      if cmd.extract then
        prefix = prefix .. "🔍 "
      else
        prefix = prefix .. "  "
      end
      
      table.insert(display_lines, string.format("%s%-30s │ %s", prefix, cmd_str, desc))
      table.insert(filtered_commands, cmd)
    end
  end
  
  if #display_lines == 0 then
    table.insert(display_lines, "No commands match filter: " .. filter_text)
  end
  
  -- Rest of your function...
  
  -- Add search mapping
  vim.keymap.set("n", "/", function()
    vim.ui.input({
      prompt = "Filter commands: ",
      default = filter_text
    }, function(input)
      if input then
        close_windows()
        show_command_list(input)
      end
    end)
  end, { buffer = buf, noremap = true, silent = true })
}
```

### Phase 7: Command Output Processing

#### Implementation Details

```lua
local function process_command_output(result, processing_rules)
  if not processing_rules then return result end
  
  local processed = vim.deepcopy(result)
  
  -- Simple text transformations
  if processing_rules.grep and result.success then
    local pattern = processing_rules.grep
    local lines = vim.split(result.output, "\n", { plain = true })
    local filtered_lines = {}
    
    for _, line in ipairs(lines) do
      if string.find(line, pattern) then
        table.insert(filtered_lines, line)
      end
    end
    
    processed.output = table.concat(filtered_lines, "\n")
  end
  
  -- Filter output by line range
  if processing_rules.lines and result.success then
    local lines = vim.split(result.output, "\n", { plain = true })
    local selected_lines = {}
    
    if type(processing_rules.lines) == "table" then
      local start = processing_rules.lines.start or 1
      local stop = processing_rules.lines.stop or #lines
      
      -- Negative indices count from end
      if start < 0 then start = #lines + start + 1 end
      if stop < 0 then stop = #lines + stop + 1 end
      
      for i = start, stop do
        if lines[i] then
          table.insert(selected_lines, lines[i])
        end
      end
    elseif type(processing_rules.lines) == "number" then
      -- Just one line
      if lines[processing_rules.lines] then
        table.insert(selected_lines, lines[processing_rules.lines])
      end
    end
    
    processed.output = table.concat(selected_lines, "\n")
  end
  
  -- Replace text
  if processing_rules.replace and result.success then
    local output = processed.output
    for pattern, replacement in pairs(processing_rules.replace) do
      output = string.gsub(output, pattern, replacement)
    end
    processed.output = output
  end
  
  -- JSON processing
  if processing_rules.json and result.success then
    local ok, json_data = pcall(vim.fn.json_decode, result.output)
    if ok then
      if processing_rules.json.path then
        -- Extract specific path from JSON
        local path_parts = vim.split(processing_rules.json.path, '.', true)
        local current = json_data
        
        for _, part in ipairs(path_parts) do
          if current[part] then
            current = current[part]
          else
            -- Path not found
            current = nil
            break
          end
        end
        
        if current ~= nil then
          if type(current) == "table" then
            local ok, json_str = pcall(vim.fn.json_encode, current)
            if ok then
              processed.output = json_str
            else
              processed.output = "Error: Could not encode JSON result"
            end
          else
            processed.output = tostring(current)
          end
        else
          processed.output = "Error: JSON path not found"
        end
      end
    else
      processed.output = "Error: Invalid JSON in command output"
    end
  end
  
  -- Custom Lua function processing
  if processing_rules.lua_fn and result.success then
    local fn_code = processing_rules.lua_fn
    
    -- Create a safe environment for the function
    local env = {
      output = processed.output,
      lines = vim.split(processed.output, "\n", { plain = true }),
      string = string,
      table = table,
      math = math,
      pairs = pairs,
      ipairs = ipairs,
      tostring = tostring,
      tonumber = tonumber,
      type = type,
      print = function(...)
        -- Redirect print to a string
        local args = {...}
        local str_args = {}
        for i, v in ipairs(args) do
          table.insert(str_args, tostring(v))
        end
        return table.concat(str_args, "\t")
      end
    }
    
    -- Create the function
    local fn, err = loadstring("return function(output, lines) " .. fn_code .. " end")
    if not fn then
      processed.output = "Error in Lua function: " .. tostring(err)
      return processed
    end
    
    -- Set the environment and run
    setfenv(fn, env)
    
    local ok, result_or_err = pcall(fn(), processed.output, vim.split(processed.output, "\n", { plain = true }))
    if ok and result_or_err ~= nil then
      processed.output = tostring(result_or_err)
    elseif not ok then
      processed.output = "Error executing Lua function: " .. tostring(result_or_err)
    end
  end
  
  return processed
end
```

#### Update Run Command Function

```lua
local function run_selected_command(cmd_table, on_done)
  -- ... existing code ...
  
  run_system_async(full_cmd, function(result)
    -- Apply validation if present
    if cmd_table.validation then
      local validation_results = validate_command_output(result, cmd_table.validation)
      result.validation_results = validation_results
      
      if not validation_results.passed then
        result.validation_failed = true
      end
    end
    
    -- Process output if rules are defined
    if cmd_table.process then
      result = process_command_output(result, cmd_table.process)
    end
    
    -- Extract variables if present
    if cmd_table.extract then
      local extracted = extract_variables(result, cmd_table.extract)
      result.extracted_variables = extracted
    end
    
    show_output_popup(result, cmd_table, on_done)
  end)
}
```

#### JSON Format Update

```json
{
  "commands": [
    {
      "id": "get-api-response",
      "command": ["curl", "-s", "https://api.example.com/users"],
      "description": "Get user list from API",
      "process": {
        "json": {
          "path": "data.users"
        }
      },
      "expected_output": "A JSON array of users"
    },
    {
      "id": "count-files",
      "command": ["find", ".", "-type", "f"],
      "description": "Count files in directory",
      "process": {
        "lua_fn": "local count = #lines; return 'Found ' .. count .. ' files'"
      },
      "expected_output": "Number of files found"
    }
  ]
}
```

## Complete Example JSON Configurations

Here are complete example configurations for different testing scenarios:

### 1. Git Integration Testing

```json
{
  "name": "Git Workflow Tests",
  "description": "Commands for testing git integration workflows",
  "commands": [
    {
      "id": "git-status",
      "command": ["git", "status", "--porcelain"],
      "description": "Check git status",
      "validation": {
        "exit_code": 0
      },
      "expected_output": "Should be empty if working directory is clean",
      "explanation": "This command checks if there are any uncommitted changes"
    },
    {
      "id": "git-branch",
      "command": ["git", "branch", "--show-current"],
      "description": "Get current branch",
      "extract": {
        "CURRENT_BRANCH": "(.+)"
      },
      "expected_output": "The name of the current git branch"
    },
    {
      "id": "git-log",
      "command": ["git", "log", "--oneline", "-n", "5"],
      "description": "Recent commit history",
      "validation": {
        "line_count": {
          "min": 1,
          "max": 5
        }
      },
      "process": {
        "grep": "feature/"
      },
      "expected_output": "Recent commit history filtered to feature branches"
    },
    {
      "id": "git-files-changed",
      "command": ["git", "diff", "--name-only", "HEAD~1", "HEAD"],
      "description": "Files changed in last commit",
      "extract": {
        "LAST_FILE": "([^\\s]+)$"
      },
      "expected_output": "List of files modified in the last commit"
    },
    {
      "id": "git-show-file",
      "command": ["git", "show", "HEAD:${LAST_FILE}"],
      "description": "Show content of changed file",
      "expected_output": "Content of the most recently changed file"
    }
  ],
  "chains": {
    "check-recent-changes": {
      "description": "Review recent changes in the repository",
      "sequence": ["git-status", "git-branch", "git-log", "git-files-changed", "git-show-file"],
      "stop_on_error": true
    }
  },
  "variables": {
    "GIT_DIR": ".git"
  }
}
```

### 2. API Testing

```json
{
  "name": "API Testing Suite",
  "description": "Commands for testing RESTful APIs",
  "commands": [
    {
      "id": "api-health",
      "command": ["curl", "-s", "http://localhost:3000/health"],
      "description": "Check API health",
      "validation": {
        "contains": ["status", "up"],
        "exit_code": 0
      },
      "process": {
        "json": {
          "path": "status"
        }
      },
      "expected_output": "Should return 'up' if the API is healthy",
      "explanation": "This endpoint provides the current health status of the API"
    },
    {
      "id": "api-users",
      "command": ["curl", "-s", "http://localhost:3000/api/users"],
      "description": "List all users",
      "validation": {
        "contains": ["data", "users"]
      },
      "process": {
        "json": {
          "path": "data.users"
        }
      },
      "extract": {
        "USER_ID": "\"id\":\\s*\"([^\"]+)\""
      },
      "expected_output": "List of user objects with id, name, email fields",
      "explanation": "This request returns all users in the system"
    },
    {
      "id": "api-user-details",
      "command": ["curl", "-s", "http://localhost:3000/api/users/${USER_ID}"],
      "description": "Get user details",
      "validation": {
        "contains": ["${USER_ID}"]
      },
      "expected_output": "Detailed information about the specified user",
      "explanation": "This uses the extracted USER_ID variable from the previous command"
    },
    {
      "id": "api-create-user",
      "command": ["curl", "-s", "-X", "POST", "-H", "Content-Type: application/json", "-d", "{\"name\":\"Test User\",\"email\":\"test@example.com\"}", "http://localhost:3000/api/users"],
      "description": "Create new user",
      "validation": {
        "contains": ["success", "true"]
      },
      "extract": {
        "NEW_USER_ID": "\"id\":\\s*\"([^\"]+)\""
      },
      "expected_output": "Confirmation of user creation with new user ID",
      "explanation": "This creates a test user and extracts the new user ID"
    },
    {
      "id": "api-delete-user",
      "command": ["curl", "-s", "-X", "DELETE", "http://localhost:3000/api/users/${NEW_USER_ID}"],
      "description": "Delete test user",
      "validation": {
        "contains": ["success", "true"]
      },
      "expected_output": "Confirmation of user deletion",
      "explanation": "Cleans up by removing the test user we created"
    }
  ],
  "chains": {
    "user-crud-flow": {
      "description": "Test complete user CRUD operations",
      "sequence": ["api-health", "api-users", "api-user-details", "api-create-user", "api-delete-user"],
      "stop_on_error": true
    },
    "api-health-check": {
      "description": "Quick API health verification",
      "sequence": ["api-health"],
      "stop_on_error": false
    }
  },
  "variables": {
    "API_URL": "http://localhost:3000"
  }
}
```

### 3. Database Testing

```json
{
  "name": "Database Testing Suite",
  "description": "Commands for testing database operations",
  "commands": [
    {
      "id": "db-version",
      "command": ["psql", "-t", "-c", "SELECT version();"],
      "description": "Check PostgreSQL version",
      "validation": {
        "contains": ["PostgreSQL"]
      },
      "expected_output": "PostgreSQL version information",
      "explanation": "Verifies database connection and shows version"
    },
    {
      "id": "db-tables",
      "command": ["psql", "-t", "-c", "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';"],
      "description": "List all tables",
      "process": {
        "lua_fn": "return 'Found ' .. #lines .. ' tables'"
      },
      "expected_output": "List of all tables in the public schema",
      "explanation": "Should show the core application tables"
    },
    {
      "id": "db-user-count",
      "command": ["psql", "-t", "-c", "SELECT count(*) FROM users;"],
      "description": "Count users",
      "extract": {
        "USER_COUNT": "\\s*(\\d+)"
      },
      "expected_output": "Number of users in the database",
      "explanation": "Extract user count into USER_COUNT variable"
    },
    {
      "id": "db-create-test-user",
      "command": ["psql", "-t", "-c", "INSERT INTO users(name, email) VALUES ('Test User', 'test@example.com') RETURNING id;"],
      "description": "Create test user",
      "extract": {
        "TEST_USER_ID": "\\s*(\\d+)"
      },
      "expected_output": "ID of the newly created test user",
      "explanation": "Creates a test user and captures the new ID"
    },
    {
      "id": "db-query-test-user",
      "command": ["psql", "-t", "-c", "SELECT * FROM users WHERE id = ${TEST_USER_ID};"],
      "description": "Query test user",
      "validation": {
        "contains": ["Test User"]
      },
      "expected_output": "Details of the test user we just created",
      "explanation": "Uses the TEST_USER_ID variable to query the specific user"
    },
    {
      "id": "db-delete-test-user",
      "command": ["psql", "-t", "-c", "DELETE FROM users WHERE id = ${TEST_USER_ID};"],
      "description": "Delete test user",
      "expected_output": "Confirmation of deletion",
      "explanation": "Cleans up by removing the test user"
    }
  ],
  "chains": {
    "db-sanity-check": {
      "description": "Basic database verification",
      "sequence": ["db-version", "db-tables", "db-user-count"]
    },
    "db-user-crud": {
      "description": "Test user CRUD operations",
      "sequence": ["db-user-count", "db-create-test-user", "db-query-test-user", "db-delete-test-user"]
    }
  },
  "variables": {
    "PGDATABASE": "myapp",
    "PGUSER": "postgres"
  }
}
```

## Implementation Timeline

1. **Week 1: Validation and Documentation**
   - Implement output validation system
   - Add documentation window feature
   - Update UI to show validation results
   - Refine JSON format to support these features

2. **Week 2: Variable System and Processing**
   - Implement variable extraction and substitution
   - Add variable management UI
   - Implement output processing features
   - Update command execution logic

3. **Week 3: Command Chains and Config Management**
   - Implement command chain execution
   - Add chain selection UI
   - Add support for multiple configuration files
   - Create configuration management UI

4. **Week 4: UI Enhancements and Refinement**
   - Add command filtering and search
   - Improve visual feedback with icons and colors
   - Polish the navigation experience
   - Add keyboard shortcuts for common actions

5. **Week 5: Testing and Documentation**
   - Create example configuration files
   - Write user documentation
   - Create test suites for each feature
   - Prepare for release

## Final Plugin Structure

```
.
├── lua/
│   └── my_cmd_runner/
│       ├── init.lua            # Main entry point
│       ├── command.lua         # Command execution logic
│       ├── ui.lua              # UI components
│       ├── validation.lua      # Validation system
│       ├── variables.lua       # Variable management
│       ├── processing.lua      # Output processing
│       ├── chains.lua          # Command chain execution
│       └── config.lua          # Configuration management
├── plugin/
│   └── my_cmd_runner.lua       # Plugin registration
├── doc/
│   └── my_cmd_runner.txt       # Documentation
└── examples/
    ├── git.json                # Git workflow example
    ├── api.json                # API testing example
    └── db.json                 # Database testing example
```

## Future Enhancement Ideas

1. **Command Templates**: Allow defining command templates with placeholders that can be filled in at runtime.

2. **Test Reports**: Generate HTML or Markdown reports of test runs with summaries of successes/failures.

3. **Timeline View**: Visual representation of command chain execution with timing information.

4. **Result Comparison**: Side-by-side comparison of expected vs. actual outputs.

5. **Custom Shell Integration**: Allow setting a specific shell for command execution instead of using the default.

6. **Auto Retry**: Automatically retry failed commands with configurable delay and attempt count.

7. **Remote Execution**: Run commands on remote servers via SSH.

8. **Parametrized Tests**: Run the same command with different parameters from a list.

9. **Interactive Commands**: Support for commands that require user input during execution.

10. **Schedule Integration**: Schedule command chains to run at specific times or intervals.

11. **Environment Management**: Switch between different environment configurations.

12. **Floating Terminal Integration**: Show command output in a floating terminal window instead of a popup.

13. **Plugin API**: Allow other Neovim plugins to register commands or hooks.

14. **Asynchronous Chains**: Run independent commands in parallel for faster execution.

15. **History Browser**: UI for viewing and managing command execution history.

## Conclusion

This enhancement plan provides a structured approach to adding powerful features to your Command Runner plugin. By implementing these features incrementally, you'll be able to maintain a stable and usable plugin throughout the development process.

The focus on validation, variable management, and command chaining will make your plugin particularly valuable for integration testing workflows, where verifying outputs and using results from one command as input to another is common.

The multiple configuration file support will allow you to organize commands for different testing scenarios, making it easier to focus on specific aspects of your system during testing.

Remember to maintain a consistent and intuitive UI throughout the development process. The user experience will be key to the success of your plugin, especially when it comes to complex features like command chains and variable management.
