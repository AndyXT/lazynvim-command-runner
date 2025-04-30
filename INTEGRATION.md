# LazyVim Integration Guide

This guide explains how to integrate the Command Runner plugin into your existing LazyVim configuration.

## Option 1: Use as a Local Plugin (Recommended during development)

1. Add the plugin to your LazyVim plugin configuration in `~/.config/nvim/lua/plugins/command-runner.lua`:

```lua
return {
  -- Command Runner plugin (local development)
  {
    dir = vim.fn.expand("~/.config/lazynvim-command-runner"),
    name = "command-runner",
    event = "VeryLazy",
    config = function()
      require("command_runner").setup({
        -- Your custom configuration here
        command_name = "CommandRunner",
        default_json_path = nil, -- nil = use CWD/commands.json 
      })
      
      -- Add your preferred keymapping
      vim.keymap.set("n", "<leader>cr", "<cmd>CommandRunner<cr>", 
        { desc = "Run commands from JSON file" })
    end,
  },
}
```

2. Restart Neovim, and the plugin should be loaded.

## Option 2: Use from GitHub (Once you've published it)

Once you've pushed this plugin to GitHub, you can use it directly from there:

```lua
return {
  -- Command Runner plugin
  {
    "yourusername/command-runner.nvim",
    event = "VeryLazy",
    config = function()
      require("command_runner").setup({
        -- Your custom configuration here
      })
      
      vim.keymap.set("n", "<leader>cr", "<cmd>CommandRunner<cr>", 
        { desc = "Run commands from JSON file" })
    end,
  },
}
```

## Usage

1. Create a `commands.json` file in your project directory or specify a path when calling `:CommandRunner /path/to/commands.json`.
2. Press `<leader>cr` or run `:CommandRunner` to open the command list.
3. Select a command and press Enter to run it.
4. View the output and optionally pipe it to another command.

## Example commands.json

```json
{
  "commands": [
    {
      "command": ["ls", "-la"],
      "description": "List all files with details"
    },
    {
      "command": ["git", "status"],
      "description": "View git status"
    },
    {
      "command": ["grep", "-r", "--include=*.lua", "require", "."],
      "description": "Find all Lua requires"
    }
  ]
}
```

## Common Issues

1. **Plugin not loading**: Make sure the path in `dir` is correct and points to the plugin directory.
2. **Command not found**: Ensure the plugin is loaded properly and that `:CommandRunner` is available.
3. **No commands displayed**: Check that your `commands.json` file exists and has the correct format.

## Development Workflow

When making changes to the plugin:

1. Edit the files in `~/.config/lazynvim-command-runner/`
2. Commit your changes
3. Restart Neovim or reload the plugin to test your changes

Since the plugin is loaded from the local directory, any changes you make will be immediately available after restarting Neovim or reloading the plugin.