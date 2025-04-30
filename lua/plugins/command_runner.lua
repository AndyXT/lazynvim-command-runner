return {
  "command-runner",
  dir = vim.fn.expand("~/.config/lazynvim-command-runner"),
  event = "VeryLazy",
  config = function()
    require("command_runner").setup({
      -- Customize options here
      command_name = "CommandRunner", -- The name of the command to use
      default_json_path = nil, -- Default path to commands.json (nil = use CWD)
    })
    
    -- Add keymapping if desired
    vim.keymap.set("n", "<leader>cr", "<cmd>CommandRunner<cr>", 
      { desc = "Run commands from JSON file" })
  end,
}