# Command Runner

A Neovim plugin to run shell commands from a predefined JSON configuration. Command Runner provides a convenient UI for executing, managing, and piping command output between commands.

![Command Runner Demo](https://github.com/yourusername/command-runner.nvim/raw/main/assets/demo.gif)

## Features

- 📋 Run shell commands from a JSON configuration file
- 🔄 Pipe output between commands
- 📝 Store command history for easy reuse
- 🚨 Detailed error reporting and inspection
- ✅ Command output validation against expected patterns
- 📖 Documentation for expected outputs and explanations
- 🔮 Dynamic inputs with text, file, and selection options
- 📅 Special handling for timestamped files
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
- `:CommandRunner examples/validation_example.json` - Opens with the validation examples
- `:CommandRunner examples/dynamic_inputs.json` - Opens with the dynamic input examples
- `:CommandRunner examples/advanced_inputs.json` - Opens with the advanced input examples

## Usage

### Commands JSON Format

Create a `commands.json` file in your project directory:

```json
{
  "commands": [
    {
      "command": ["ls", "-la"],
      "description": "List all files with details",
      "validation": {
        "contains": ["total", ".git"],
        "matches": ["d[rwx-]{9}"],
        "exit_code": 0,
        "line_count": {
          "min": 5
        }
      },
      "expected_output": "Should list all files including hidden ones with details",
      "explanation": "Shows all files in current directory with permissions and details"
    },
    {
      "command": ["echo", "Hello", "[INPUT:text:Enter your name:World!]"],
      "description": "Print greeting with your name",
      "validation": {
        "contains": ["Hello"],
        "exit_code": 0
      },
      "expected_output": "Outputs a greeting with the name you provide"
    },
    {
      "command": ["cat", "[INPUT:file:Select a file to view:*.md]"],
      "description": "View file content",
      "expected_output": "Content of the selected file"
    },
    {
      "command": ["git", "checkout", "[INPUT:select:Select branch:main:develop:feature/x]"],
      "description": "Checkout a git branch",
      "expected_output": "Switches to the selected git branch"
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
- `v` - View validation failures (only if validation failed)
- `q` / `Esc` - Close the output view

When a command has validation rules:
- ✅ Green checkmark indicates passed validation
- ❌ Red X indicates failed validation

When a command has documentation:
- A separate documentation window shows expected output and explanations

## Advanced Features

### Dynamic Inputs

Commands can include special placeholders that prompt for user input when the command runs:

1. **Text Input**: `[INPUT:text:Prompt:Default:Completion]`
   - Example: `[INPUT:text:Enter your name:User]`
   - Prompts for text with an optional default value
   - Input is cached for later reference

2. **File Selection**: `[INPUT:file:Prompt:Pattern:Directory]`
   - Example: `[INPUT:file:Select a file:*.lua:./lua]`
   - Shows a list of matching files to choose from

3. **Selection from Options**: `[INPUT:select:Prompt:Option1:Option2:Option3]`
   - Example: `[INPUT:select:Choose environment:dev:staging:prod]`
   - Shows a menu to select from predefined options

4. **Timestamped Files**: `[INPUT:timestamp_file:Prompt:Pattern:Directory:latest]`
   - Example: `[INPUT:timestamp_file:Select log:log_*.txt:./logs]`
   - Special handling for files with timestamps in the name
   - Supports multiple timestamp formats:
     - `name_20230101123045.ext`
     - `name-2023-01-01-12-30-45.ext`
     - `name_2023-01-01.ext`
   - Files are sorted by modification time (newest first)
   - Selection UI shows time, size, and file preview
   - With `:latest` suffix, automatically selects the newest file

5. **Multiple Sequential Inputs**: `[INPUT:multi:text:Prompt1:Default1:Prompt2:Default2]`
   - Example: `[INPUT:multi:text:Enter IP:127.0.0.1:Enter port:8080]`
   - Presents multiple input prompts in sequence
   - Each value is cached separately and the combined result is used

6. **Reference Previous Input**: `[INPUT:ref:input_name]`
   - Example: `[INPUT:ref:enter_ip_address]`
   - Reuses a previously entered value
   - Allows sharing values between commands

7. **File with Regeneration**: `[INPUT:regen_file:Prompt:Pattern:Directory:suffix]`
   - Example: `[INPUT:regen_file:Select data file:data_file:./examples:_generate]`
   - Special handling for files that need to be regenerated with timestamps
   - Provides an option to generate a new file with a timestamp if needed
   - Useful for working with files that get regenerated with new names

Try the examples in `examples/dynamic_inputs.json` and `examples/advanced_inputs.json` to see these in action.

### Piping Between Commands

You can pipe output from one command to another with enhanced selection options:

1. Run a command
2. Press `p` to pipe the output
3. Choose from multiple piping options:
   - **Line at cursor**: Just pipe the current line
   - **Entire output**: Pipe all output as arguments
   - **Visual selection**: Select specific lines first (using Vim's visual mode)
   - **Filtered by pattern**: Enter a pattern to filter which lines to pipe
   - **Interactive selection**: Automatically extracts tokens like IDs, values, etc. from the output and lets you choose one
4. Run another command that will receive the piped content as arguments

The piped output is also cached and can be referenced in subsequent commands using `[INPUT:ref:last_pipe]`.

## Roadmap

- [x] Output validation to verify command results
- [x] Dynamic input system for interactive commands
- [ ] Command chains for executing sequences of commands
- [ ] Variable extraction and substitution
- [ ] Enhanced UI with filtering and search
- [ ] Multiple configuration file support

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.

## License

MIT License - see [LICENSE](LICENSE) for details.