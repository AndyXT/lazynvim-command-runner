local M = {}

function M.validate_command_output(result, validation_rules)
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

function M.show_validation_failures(validation_results, popup_module)
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

  popup_module.create(lines, keymaps, popup_opts)
end

return M