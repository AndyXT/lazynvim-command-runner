return {
  "~/.config/lazynvim-command-runner", -- Local plugin path
  name = "command-runner",           -- Plugin name
  event = "VeryLazy",                -- Load when needed
  config = function()
    -- Load and configure the command runner
    require("command_runner").setup({
      -- Customize options here
      command_name = "CommandRunner", -- The name of the command to use
      default_json_path = nil,        -- Default path to commands.json (nil = use CWD)
      popup_width = 0.5,              -- Percentage of screen width
      popup_height = 0.4,             -- Percentage of screen height
      popup_border = "rounded",       -- Border style
    })
    
    -- Add keymapping if desired
    vim.keymap.set("n", "<leader>cr", "<cmd>CommandRunner<cr>", 
      { desc = "Run commands from JSON file" })
  end,
}