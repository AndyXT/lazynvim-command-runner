# Command Runner

A Neovim plugin to run shell commands from a predefined JSON configuration. Command Runner provides a convenient UI for executing, managing, and piping command output between commands.

![Command Runner Demo](https://github.com/yourusername/command-runner.nvim/raw/main/assets/demo.gif)

## Features

- 📋 Run shell commands from a JSON configuration file
- 🔄 Pipe output between commands
- 📝 Store command history for easy reuse
- 🚨 Detailed error reporting and inspection
- 🎨 Clean, minimal UI with keybindings
- 🔧 Customizable configuration

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "yourusername/command-runner.nvim",
  event = "VeryLazy",
  config = function()
    require("command_runner").setup({
      -- options...
    })
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "yourusername/command-runner.nvim",
  config = function()
    require("command_runner").setup({
      -- options...
    })
  end,
}
```

## Configuration

### Default Configuration

```lua
require("command_runner").setup({
  command_name = "CommandRunner", -- The name of the command to use
  default_json_path = nil, -- Default path to commands.json (nil = use CWD)
  max_history = 50, -- Maximum number of commands to store in history
  popup = {
    width = 0.5, -- 50% of screen width
    height = 0.4, -- 40% of screen height
    border = "rounded",
  },
  status = {
    show = true,
    duration = 3000, -- milliseconds
  }
})
```

### Adding a Keymap

```lua
vim.keymap.set("n", "<leader>cr", "<cmd>CommandRunner<cr>", 
  { desc = "Run commands from JSON file" })
```

## Commands

- `:CommandRunner` - Opens the command list UI
- `:CommandRunner /path/to/commands.json` - Opens with a specific commands file

## Usage

### Commands JSON Format

Create a `commands.json` file in your project directory:

```json
{
  "commands": [
    {
      "command": ["ls", "-la"],
      "description": "List all files with details"
    },
    {
      "command": ["echo", "Hello", "World!"],
      "description": "Print greeting message"
    },
    {
      "command": ["git", "status"],
      "description": "View git status"
    }
  ]
}
```

### Command List UI

Press `<leader>cr` or run `:CommandRunner` to open the command list UI:

- `Enter` - Run the selected command
- `c` - Clear piped output
- `q` / `Esc` - Close the UI
- `p` / `n` - Navigate through command history

### Command Output UI

After running a command:

- `p` - Pipe output (with options: line, selection, all)
- `n` - Skip piping (clear pipe buffer)
- `e` - View error details (only if command failed)
- `q` / `Esc` - Close the output view

## Advanced Features

### Piping Between Commands

You can pipe output from one command to another:

1. Run a command
2. Press `p` to pipe the output
3. Select what to pipe (line at cursor, selection, or all)
4. Run another command that will receive the piped content as arguments

## Roadmap

- [ ] Command chains for executing sequences of commands
- [ ] Output validation to verify command results
- [ ] Variable extraction and substitution
- [ ] Enhanced UI with filtering and search
- [ ] Multiple configuration file support

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.

## License

MIT License - see [LICENSE](LICENSE) for details.