local M = {}

local status = require("command_runner.ui.status")

-- Store input values to allow referencing previous inputs
local INPUT_CACHE = {}

-- Save a value in the input cache for later reference
function M.cache_value(key, value)
  if key and value then
    INPUT_CACHE[key] = value
  end
end

-- Get a cached value
function M.get_cached(key)
  return INPUT_CACHE[key]
end

-- Process dynamic inputs in command arguments
function M.process_dynamic_inputs(cmd_arr)
  local processed_cmd = {}
  local requires_input = false
  
  -- First check if any inputs are needed
  for _, part in ipairs(cmd_arr) do
    if type(part) == "string" and string.match(part, "^%[INPUT:.+%]$") then
      requires_input = true
      break
    end
  end
  
  -- If no inputs needed, return original command
  if not requires_input then
    return cmd_arr
  end
  
  -- Process each part of the command
  for _, part in ipairs(cmd_arr) do
    if type(part) == "string" and string.match(part, "^%[INPUT:.+%]$") then
      -- Extract the input specification
      local input_spec = string.match(part, "^%[INPUT:(.+)%]$")
      local input_parts = vim.split(input_spec, ":", { plain = true })
      
      local input_type = input_parts[1]
      local prompt = input_parts[2] or "Enter value:"
      local default = input_parts[3] or ""
      
      -- Allow referencing previous inputs with [INPUT:ref:name]
      if input_type == "ref" then
        local ref_name = input_parts[2] or ""
        if INPUT_CACHE[ref_name] then
          table.insert(processed_cmd, INPUT_CACHE[ref_name])
        else
          vim.notify("No input reference found for: " .. ref_name, vim.log.levels.WARN)
          table.insert(processed_cmd, "")
        end
      -- Multiple sequential inputs with [INPUT:multi:text:prompt1:default1:prompt2:default2]
      elseif input_type == "multi" then
        local sub_type = input_parts[2] or "text"
        local inputs = {}
        local i = 3
        
        -- Collect all prompt:default pairs
        while i < #input_parts do
          local prompt = input_parts[i] or "Enter value:"
          local default = input_parts[i+1] or ""
          table.insert(inputs, {prompt = prompt, default = default})
          i = i + 2
        end
        
        -- If no inputs defined, create at least one
        if #inputs == 0 then
          table.insert(inputs, {prompt = "Enter value:", default = ""})
        end
        
        -- Process each input sequentially
        local results = {}
        for idx, input_def in ipairs(inputs) do
          status.show("Waiting for input " .. idx .. "/" .. #inputs .. ": " .. input_def.prompt, "info")
          local input_value = vim.fn.input({
            prompt = input_def.prompt .. " ",
            default = input_def.default
          })
          
          if input_value and input_value ~= "" then
            table.insert(results, input_value)
            -- Cache each value with index and overall string
            INPUT_CACHE["multi_" .. idx] = input_value
          else
            table.insert(results, input_def.default)
            INPUT_CACHE["multi_" .. idx] = input_def.default
          end
        end
        
        -- Join with spaces for command line args
        local combined = table.concat(results, " ")
        table.insert(processed_cmd, combined)
        -- Also cache the whole thing
        INPUT_CACHE["multi"] = combined
        
      -- Regenerating file with [INPUT:regen_file:prompt:pattern:directory]
      elseif input_type == "regen_file" then
        local pattern = input_parts[3] or "*"
        local base_dir = input_parts[4] or vim.fn.getcwd()
        local regen_suffix = input_parts[5] or "_generate"
        
        -- Find most recent matching files
        local base_pattern, ext = string.match(pattern, "^(.+)%.(.+)$")
        if not base_pattern then
          base_pattern = pattern
          ext = "dat"
        end
        
        -- Create patterns that match various timestamp formats
        local ts_pattern = base_pattern .. "_[0-9]+" .. (ext ~= "" and ("." .. ext) or "")
        local glob_pattern = base_dir .. "/" .. ts_pattern
        
        -- Find matching files
        local matching_files = vim.fn.glob(glob_pattern, false, true)
        
        -- Also look for the generate placeholder
        local gen_pattern = base_pattern .. regen_suffix .. (ext ~= "" and ("." .. ext) or "")
        local gen_path = base_dir .. "/" .. gen_pattern
        
        -- Sort by modification time (newest first)
        table.sort(matching_files, function(a, b)
          return vim.fn.getftime(a) > vim.fn.getftime(b)
        end)
        
        -- Options for the user
        local options = {}
        
        -- Add regenerate option at the top
        table.insert(options, {
          display = "📝 Generate new file",
          value = gen_path,
          is_regen = true
        })
        
        -- Add existing files
        for _, file in ipairs(matching_files) do
          local filename = vim.fn.fnamemodify(file, ":t")
          local mtime = os.date("%Y-%m-%d %H:%M:%S", vim.fn.getftime(file))
          local size = vim.fn.getfsize(file)
          local size_str = ""
          
          -- Format file size nicely
          if size < 1024 then
            size_str = string.format("%d B", size)
          elseif size < 1024 * 1024 then
            size_str = string.format("%.1f KB", size / 1024)
          else
            size_str = string.format("%.1f MB", size / (1024 * 1024))
          end
          
          table.insert(options, {
            display = filename .. " (" .. mtime .. ", " .. size_str .. ")",
            value = file,
            is_regen = false
          })
        end
        
        if #options <= 1 then
          -- Only regenerate option, use it
          status.show("No existing files found. Will generate new file.", "info")
          table.insert(processed_cmd, gen_path)
        else
          -- Let user choose
          status.show("Select file or choose to generate new one...", "info")
          
          local selected = nil
          vim.ui.select(options, {
            prompt = prompt,
            format_item = function(item)
              return item.display
            end
          }, function(choice)
            if choice then
              selected = choice.value
              if choice.is_regen then
                status.show("Will generate new file", "info")
              else
                status.show("Selected: " .. vim.fn.fnamemodify(choice.value, ":t"), "info")
              end
            else
              -- Default to regenerating if cancelled
              selected = gen_path
              status.show("Selection cancelled, will generate new file", "info")
            end
          end)
          
          -- Wait for selection
          vim.wait(10000, function() return selected ~= nil end, 100)
          
          if selected then
            table.insert(processed_cmd, selected)
            -- Cache the selection
            INPUT_CACHE["regen_file"] = selected
          else
            table.insert(processed_cmd, gen_path)
            INPUT_CACHE["regen_file"] = gen_path
          end
        end
      
      elseif input_type == "text" then
        -- Simple text input
        status.show("Waiting for input: " .. prompt, "info")
        local input_value = vim.fn.input({
          prompt = prompt .. " ",
          default = default,
          completion = input_parts[4] -- Optional completion type
        })
        
        if input_value and input_value ~= "" then
          table.insert(processed_cmd, input_value)
          -- Cache the input value with the prompt as key (cleaned up)
          local cache_key = prompt:gsub("[ :?]", "_"):lower()
          INPUT_CACHE[cache_key] = input_value
          -- Also cache with index number for the current command
          local cmd_idx = #processed_cmd
          INPUT_CACHE["input_" .. cmd_idx] = input_value
        else
          table.insert(processed_cmd, default)
          local cache_key = prompt:gsub("[ :?]", "_"):lower()
          INPUT_CACHE[cache_key] = default
          local cmd_idx = #processed_cmd
          INPUT_CACHE["input_" .. cmd_idx] = default
        end
      elseif input_type == "file" then
        -- File selection with optional pattern
        local pattern = input_parts[3] or "*"
        local base_dir = input_parts[4] or vim.fn.getcwd()
        
        -- Find matching files
        local glob_pattern = base_dir .. "/" .. pattern
        local matching_files = vim.fn.glob(glob_pattern, false, true)
        
        if #matching_files == 0 then
          vim.notify("No files match pattern: " .. pattern, vim.log.levels.WARN)
          table.insert(processed_cmd, "") -- Empty string as fallback
        elseif #matching_files == 1 then
          -- Only one match, use it directly
          local file = matching_files[1]
          status.show("Selected file: " .. vim.fn.fnamemodify(file, ":t"), "info")
          table.insert(processed_cmd, file)
        else
          -- Multiple matches, let user select
          status.show("Waiting for file selection...", "info")
          
          -- Create a UI selector for choosing a file
          local chosen_file = nil
          vim.ui.select(matching_files, {
            prompt = prompt,
            format_item = function(item)
              return vim.fn.fnamemodify(item, ":t")
            end
          }, function(choice)
            if choice then
              chosen_file = choice
              status.show("Selected file: " .. vim.fn.fnamemodify(choice, ":t"), "info")
            else
              -- User cancelled, use default or empty
              chosen_file = default
              status.show("Selection cancelled, using default", "warn")
            end
          end)
          
          -- Wait for selection (this is synchronous)
          -- Since vim.ui.select is asynchronous but we need the result now
          vim.wait(10000, function() return chosen_file ~= nil end, 100)
          
          if chosen_file then
            table.insert(processed_cmd, chosen_file)
          else
            table.insert(processed_cmd, default)
          end
        end
      elseif input_type == "select" then
        -- Selection from predefined options
        local options = {}
        for i = 3, #input_parts do
          table.insert(options, input_parts[i])
        end
        
        if #options == 0 then
          vim.notify("No options provided for selection", vim.log.levels.WARN)
          table.insert(processed_cmd, default)
        else
          status.show("Waiting for selection...", "info")
          
          local chosen_option = nil
          vim.ui.select(options, {
            prompt = prompt
          }, function(choice)
            if choice then
              chosen_option = choice
              status.show("Selected: " .. choice, "info")
            else
              -- User cancelled, use default or first option
              chosen_option = default ~= "" and default or options[1]
              status.show("Selection cancelled, using default", "warn")
            end
          end)
          
          -- Wait for selection
          vim.wait(10000, function() return chosen_option ~= nil end, 100)
          
          if chosen_option then
            table.insert(processed_cmd, chosen_option)
          else
            table.insert(processed_cmd, default ~= "" and default or options[1])
          end
        end
      elseif input_type == "timestamp_file" then
        -- Special case for files with timestamps
        local pattern = input_parts[3] or "*"
        local base_dir = input_parts[4] or vim.fn.getcwd()
        local base_pattern, ext = string.match(pattern, "^(.+)%.(.+)$")
        
        if not base_pattern then
          base_pattern = pattern
          ext = ""
        end
        
        -- Create patterns that match various timestamp formats
        local patterns = {
          -- Format: name_20230101123045.ext (most common)
          base_pattern .. "_[0-9]+" .. (ext ~= "" and ("." .. ext) or ""),
          -- Format: name-2023-01-01-12-30-45.ext
          base_pattern .. "-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}" .. (ext ~= "" and ("." .. ext) or ""),
          -- Format: name-20230101_123045.ext
          base_pattern .. "-[0-9]{8}_[0-9]{6}" .. (ext ~= "" and ("." .. ext) or ""),
          -- Format: name_2023-01-01.ext
          base_pattern .. "_[0-9]{4}-[0-9]{2}-[0-9]{2}" .. (ext ~= "" and ("." .. ext) or ""),
          -- Format: name_timestamp_12345678.ext (unix timestamp)
          base_pattern .. "_timestamp_[0-9]+" .. (ext ~= "" and ("." .. ext) or "")
        }
        
        -- Try all patterns and collect files
        local matching_files = {}
        for _, pattern in ipairs(patterns) do
          local glob_pattern = base_dir .. "/" .. pattern
          local files = vim.fn.glob(glob_pattern, false, true)
          vim.list_extend(matching_files, files)
        end
        
        -- Remove duplicates
        local unique_files = {}
        local seen = {}
        for _, file in ipairs(matching_files) do
          if not seen[file] then
            seen[file] = true
            table.insert(unique_files, file)
          end
        end
        matching_files = unique_files
        
        -- Sort files by modification time (newest first)
        table.sort(matching_files, function(a, b)
          return vim.fn.getftime(a) > vim.fn.getftime(b)
        end)
        
        if #matching_files == 0 then
          vim.notify("No timestamp files match pattern: " .. ts_pattern, vim.log.levels.WARN)
          table.insert(processed_cmd, "") -- Empty string as fallback
        elseif #matching_files == 1 or input_parts[5] == "latest" then
          -- Only one match or explicitly requesting latest, use it directly
          local file = matching_files[1]
          status.show("Selected latest file: " .. vim.fn.fnamemodify(file, ":t"), "info")
          table.insert(processed_cmd, file)
        else
          -- Multiple matches, let user select
          status.show("Waiting for file selection...", "info")
          
          local chosen_file = nil
          vim.ui.select(matching_files, {
            prompt = prompt,
            format_item = function(item)
              local filename = vim.fn.fnamemodify(item, ":t")
              local mtime = os.date("%Y-%m-%d %H:%M:%S", vim.fn.getftime(item))
              local size = vim.fn.getfsize(item)
              local size_str = ""
              
              -- Format file size nicely
              if size < 1024 then
                size_str = string.format("%d B", size)
              elseif size < 1024 * 1024 then
                size_str = string.format("%.1f KB", size / 1024)
              else
                size_str = string.format("%.1f MB", size / (1024 * 1024))
              end
              
              -- Get first line of the file for preview (if text file)
              local preview = ""
              local file_content = ""
              local ok, lines = pcall(function()
                return vim.fn.readfile(item, "", 1)
              end)
              
              if ok and #lines > 0 then
                file_content = lines[1]
                if #file_content > 40 then
                  file_content = string.sub(file_content, 1, 37) .. "..."
                end
                preview = " | " .. file_content
              end
              
              return filename .. " (" .. mtime .. ", " .. size_str .. ")" .. preview
            end
          }, function(choice)
            if choice then
              chosen_file = choice
              status.show("Selected file: " .. vim.fn.fnamemodify(choice, ":t"), "info")
            else
              -- User cancelled, use latest by default
              chosen_file = matching_files[1]
              status.show("Selection cancelled, using latest file", "info")
            end
          end)
          
          -- Wait for selection
          vim.wait(10000, function() return chosen_file ~= nil end, 100)
          
          if chosen_file then
            table.insert(processed_cmd, chosen_file)
          else
            table.insert(processed_cmd, matching_files[1])
          end
        end
      end
    else
      -- Regular command part, just pass through
      table.insert(processed_cmd, part)
    end
  end
  
  return processed_cmd
end

return M