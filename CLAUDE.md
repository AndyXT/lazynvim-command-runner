# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build/Lint/Test Commands
- Code formatting: `stylua .`
- There are no explicit test commands in this Neovim plugin

## Code Style Guidelines
- Formatting: 2-space indentation, 120 column width, Unix line endings
- Use StyLua config from stylua.toml
- Naming: Use snake_case for variables and functions
- Module pattern: Use `local M = {}` and return M at end of file
- Error handling: Use pcall for error-prone operations 
- Imports: Require modules at the top of files
- Keymaps: Define vim.keymap.set in UI component initialization
- Comments: Add clear comments for function behavior
- Functions: Local functions for implementation, exposed via M table
- Async: Use vim.system for asynchronous command execution
- UI Components: Follow existing UI patterns - popup windows with keymaps
- Validation: Include validation for user inputs