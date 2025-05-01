# Command Runner PTY Implementation Plan

This document outlines the plan for enhancing the LazyNvim Command Runner plugin to use Neovim's jobstart() with PTY support for better handling of interactive commands.

## Goals

- Replace `vim.system()` with `vim.fn.jobstart()` for command execution
- Add PTY support for interactive commands
- Display a terminal split below for interactive commands
- Maintain existing UI and features (description, validation, piping)
- Auto-detect interactive commands
- Improve the handling of command input

## Implementation Steps

### Phase 1: Research & Preparation

- [x] Research Neovim's jobstart() and its capabilities
- [x] Understand PTY options and how they work with jobstart()
- [x] Explore nvim_open_term() for terminal emulation
- [x] Review current implementation and identify change points
- [x] Document key APIs and functions needed

### Phase 2: Core Command Execution Changes

- [x] Refactor `run_system_async()` in `command.lua` to use jobstart()
  - [x] Create a basic implementation without PTY first
  - [x] Test with simple, non-interactive commands
  - [x] Add output collection and callback integration

- [x] Add PTY support in command execution
  - [x] Create terminal buffer and window for interactive commands
  - [x] Add detection logic for interactive commands
  - [x] Implement input forwarding to PTY
  - [x] Handle terminal cleanup when commands complete

### Phase 3: UI Integration

- [x] Update `output.lua` to support terminal integration
  - [x] Modify `show_output()` to display terminal status
  - [x] Keep regular output window for command summary
  - [x] Add keybindings for terminal interaction

- [x] Enhance command input handling
  - [x] Update dynamic input processing to work with jobstart
  - [x] Support real-time input for running commands
  - [ ] Test interactive input scenarios (pending)

### Phase 4: Edge Cases & Refinements

- [x] Handle validation for terminal commands
  - [x] Capture output for validation even with terminal display
  - [ ] Test validation with various command types (pending)

- [x] Handle window management
  - [x] Ensure proper sizing of terminal vs output windows
  - [x] Test window behavior when commands finish
  - [x] Add configuration options for window sizing

- [x] Error handling improvements
  - [x] Graceful handling of command not found
  - [x] Proper cleanup of resources on failure
  - [x] Error reporting in terminal context

### Phase 5: Testing & Documentation

- [ ] Test with various command types
  - [ ] Simple commands (ls, grep, etc.)
  - [ ] Interactive shell commands (bash, python repl)
  - [ ] Long-running commands with output (logs, monitoring)
  - [ ] Commands requiring input (password prompts, confirmations)

- [x] Update documentation
  - [x] Add terminal features to plugin docs
  - [x] Document new configuration options
  - [x] Add examples of terminal usage

- [x] Create example configuration
  - [x] Example JSON with interactive commands
  - [x] Document best practices for terminal commands

## Configuration Options to Add

- `use_terminal`: Boolean to enable/disable terminal features
- `terminal_height`: Number of lines for terminal window
- `auto_detect_interactive`: Boolean to auto-detect interactive commands
- `force_terminal_commands`: List of commands that should always use terminal
- `preserve_terminal`: Keep terminal open after command completes

## Technical Notes

### Key APIs

- `vim.fn.jobstart()`: Core function for starting jobs
- `vim.api.nvim_open_term()`: Creates a terminal in a buffer
- `vim.fn.chansend()`: Sends data to a job
- `vim.api.nvim_chan_send()`: Sends data to a terminal channel

### Interactive Command Detection

Interactive commands can be detected through:
- Command name (e.g., ssh, top, python, etc.)
- Command flags (e.g., -i, --interactive)
- Command-specific criteria

### Challenges

- Capturing output for validation while using a terminal
- Managing window layouts with split terminals
- Handling command termination and cleanup
- Supporting various input types in interactive mode

## Progress Tracking

### Completed
- Initial research and planning
- Understanding of jobstart() and PTY features
- Draft implementation plan
- Core command execution refactoring
- PTY support implementation
- UI integration
- Documentation updates
- Configuration options

### In Progress
- Testing interactive input scenarios
- Testing validation with terminal output

### Pending
- Testing with various command types