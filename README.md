# Command Runner for Neovim

A powerful plugin for running shell commands from JSON configuration files with output capture, piping, and more.

![Command Runner Screenshot](https://github.com/yourusername/command-runner.nvim/assets/screenshot.png)

## Features

- 📋 Run predefined shell commands from a JSON config file
- 📎 Pipe command output between commands
- 📝 View command outputs in floating windows 
- 🕒 Command execution history
- 🔄 Configurable UI and behavior

## Installation

### Using LazyVim

```lua
{
  "yourusername/command-runner.nvim",
  event = "VeryLazy",
  config = function()
    require("command_runner").setup({
      -- your configuration here
    })
    
    -- Add keymapping
    vim.keymap.set("n", "<leader>cr", "<cmd>CommandRunner<cr>", 
      { desc = "Run commands from JSON file" })
  end,
}
```

### Using Packer

```lua
use {
  'yourusername/command-runner.nvim',
  config = function()
    require("command_runner").setup({
      -- your configuration here
    })
    
    -- Add keymapping
    vim.keymap.set("n", "<leader>cr", "<cmd>CommandRunner<cr>", 
      { desc = "Run commands from JSON file" })
  end
}
```

## Configuration

### Default Configuration

```lua
require("command_runner").setup({
  command_name = "CommandRunner",  -- The name of the command
  default_json_path = nil,         -- Default path to commands.json (nil = use CWD)
  max_history = 50,                -- Number of commands to keep in history
  popup_width = 0.5,               -- Width of popup windows (0-1)
  popup_height = 0.4,              -- Height of popup windows (0-1)
  popup_border = "rounded",        -- Border style for popups
  highlight_success = "Normal",    -- Highlight group for success
  highlight_error = "ErrorFloat",  -- Highlight group for errors
  highlight_warning = "WarningFloat", -- Highlight group for warnings
})
```

## Usage

### Basic Usage

1. Create a `commands.json` file in your project directory:

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
    }
  ]
}
```

2. Run `:CommandRunner` to show the command list
3. Select a command with the cursor and press Enter to run
4. View command output in a popup window
5. Optionally pipe output to another command

### Piping Output Between Commands

After running a command, you can pipe its output to another command:

1. Press `p` in the output window
2. Choose what to pipe (current line, selection, or all output)
3. The output will be piped to the next command you run
4. Commands with piped input show a 📎 icon

### Command JSON Format

```json
{
  "commands": [
    {
      "command": ["executable", "arg1", "arg2"],
      "description": "Human readable description"
    }
  ]
}
```

- Each command is an array of strings, just like you would type in a terminal
- The first element is the executable, followed by arguments
- The description appears in the UI

## Keyboard Shortcuts

### Command List Window

- `Enter` - Run selected command
- `c` - Clear piped data
- `p` - Previous command in history
- `n` - Next command in history
- `q` - Close window

### Output Window

- `p` - Pipe output
- `n` - Skip pipe
- `v` - Visual select for piping
- `e` - Show error details (for failed commands)
- `q` - Close window

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.