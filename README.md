# Fleet.nvim

A powerful enhancement layer for [Harpoon](https://github.com/ThePrimeagen/harpoon) that adds persistent file lists with project-based organization and enhanced navigation capabilities.

Fleet transforms Harpoon into a sophisticated file management system by adding:

- **Persistent lists** that survive Neovim sessions
- **Project-based organization** with automatic project detection
- **Multiple named lists** per project
- **Intuitive list management** with save, load, rename, and delete operations
- **Enhanced UI** with custom menu titles and status line integration

## ✨ Features

### Core Functionality

- **Enhanced Harpoon Navigation** - All your favorite Harpoon features with persistence
- **Persistent Lists** - Your file lists survive restarts and are automatically saved
- **Project-Based Organization** - Lists are organized by project with Git repository detection
- **Named Lists** - Create multiple lists per project with custom names
- **Seamless Integration** - Works alongside existing Harpoon workflows

### List Management

- **Create New Lists** - Start fresh lists with auto-generated or custom names
- **Save/Load Lists** - Persist your work and switch between different file sets
- **Rename Lists** - Keep your lists organized with meaningful names
- **Delete Lists** - Clean up unused lists
- **Clear Lists** - Empty current list while preserving the list structure

### Navigation & UI

- **Enhanced Menu** - Shows current list name in the Harpoon menu
- **Status Line Integration** - Display current list and file count in your status line
- **Position Awareness** - Know exactly where you are in your current list
- **Fast Navigation** - Quick access to your most important files

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "VenkatRaman3103/fleet.nvim",
    dependencies = {
        "ThePrimeagen/harpoon"
    },
    config = function()
        require("fleet").setup({
            debug_mode = false,
            auto_save = true,
            keymaps = {
                toggle_menu = "<leader>ho",
                add_file = "<leader>a",
                new_list = "<leader>hn",
                remove_file = "<leader>hx",
                clear_list = "<leader>hc",
                save_list = "<leader>hs",
                load_list = "<leader>hl",
                delete_list = "<leader>hd",
                rename_list = "<leader>hr",
                where_am_i = "<leader>hw",
                nav_file_1 = "<leader>j",
                nav_file_2 = "<leader>k",
                nav_file_3 = "<leader>l",
                nav_file_4 = "<leader>;",
                nav_file_5 = "<leader>5",
                nav_next = "<S-j>",
                nav_prev = "<S-k>",
            },
            lualine_component = true,
        })
    end,
    keys = {
        { "<leader>ho", desc = "Fleet: Toggle Menu" },
        { "<leader>a",  desc = "Fleet: Add File" },
        { "<leader>hn", desc = "Fleet: New List" },
        { "<leader>hx", desc = "Fleet: Remove File" },
        { "<leader>hc", desc = "Fleet: Clear List" },
        { "<leader>hs", desc = "Fleet: Save List" },
        { "<leader>hl", desc = "Fleet: Load List" },
        { "<leader>hd", desc = "Fleet: Delete List" },
        { "<leader>hr", desc = "Fleet: Rename List" },
        { "<leader>hw", desc = "Fleet: Where Am I" },
        { "<leader>j",  desc = "Fleet: Nav File 1" },
        { "<leader>k",  desc = "Fleet: Nav File 2" },
        { "<leader>l",  desc = "Fleet: Nav File 3" },
        { "<leader>;",  desc = "Fleet: Nav File 4" },
        { "<leader>5",  desc = "Fleet: Nav File 5" },
        { "<S-j>",      desc = "Fleet: Next File" },
        { "<S-k>",      desc = "Fleet: Previous File" },
    },
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
    'VenkatRaman3103/fleet.nvim',
    requires = { 'ThePrimeagen/harpoon' },
    config = function()
        require('fleet').setup()
    end
}
```

## Configuration

Fleet comes with sensible defaults, but you can customize everything:

```lua
require("fleet").setup({
    -- Enable debug messages
    debug_mode = false,

    -- Automatically save lists when modified
    auto_save = true,

    -- Customize all keymaps
    keymaps = {
        toggle_menu = "<leader>ho",    -- Open Fleet menu
        add_file = "<leader>a",        -- Add current file to list
        new_list = "<leader>hn",       -- Create new empty list
        remove_file = "<leader>hx",    -- Remove current file from list
        clear_list = "<leader>hc",     -- Clear current list
        save_list = "<leader>hs",      -- Save current list
        load_list = "<leader>hl",      -- Load a saved list
        delete_list = "<leader>hd",    -- Delete a saved list
        rename_list = "<leader>hr",    -- Rename current list
        where_am_i = "<leader>hw",     -- Show position in current list

        -- Quick navigation to specific files
        nav_file_1 = "<leader>j",
        nav_file_2 = "<leader>k",
        nav_file_3 = "<leader>l",
        nav_file_4 = "<leader>;",
        nav_file_5 = "<leader>5",

        -- Cycle through files
        nav_next = "<S-j>",
        nav_prev = "<S-k>",
    },

    -- Enable lualine component
    lualine_component = true,
})
```

## Usage

### Basic Workflow

1. **Add files to your fleet**: Use `<leader>a` to add the current file
2. **Navigate your files**: Use `<leader>j`, `<leader>k`, etc., or cycle with `<S-j>`/`<S-k>`
3. **Open the menu**: Use `<leader>ho` to see all files with the current list name
4. **Save your work**: Lists are auto-saved, or manually save with `<leader>hs`

### List Management

#### Creating Lists

- `<leader>hn` - Create a new empty list
  - Choose between auto-generated names (`list_1`, `list_2`, etc.) or custom names
  - Lists are automatically associated with your current project

#### Loading Lists

- `<leader>hl` - Load a previously saved list
  - See all lists for your current project
  - Switch between different file sets instantly

#### Organizing Lists

- `<leader>hr` - Rename your current list for better organization
- `<leader>hd` - Delete lists you no longer need
- `<leader>hc` - Clear current list (with option to save the empty state)

### Project Detection

Fleet automatically detects your project using:

1. **Git repository** - Uses the repository name from `git remote`
2. **Directory structure** - Falls back to parent and current directory names
3. **Current working directory** - As a final fallback

This means your lists are automatically organized by project without any manual setup!

### Status Line Integration

If you use [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim), add Fleet's component:

```lua
require('lualine').setup {
    sections = {
        lualine_c = {
            require('fleet').lualine_component,  -- Shows "list_name"
        }
    }
}
```

## File Storage

Fleet stores your lists in Neovim's data directory:

- **Location**: `~/.local/share/nvim/fleet_lists/` (or equivalent on your system)
- **Format**: JSON files named by project and list
- **Naming**: `project_name:list_name.json` or `project_name.json` for default lists

## Commands

Fleet provides several commands for debugging and management:

- `:FleetProjectInfo` - Display current project information and available lists
- `:FleetListFiles` - Show all Fleet list files in the storage directory

## Integration with Harpoon

Fleet is designed to enhance, not replace, your Harpoon workflow:

- All existing Harpoon functionality remains unchanged
- Fleet adds an extra layer of persistence and organization
- You can use Fleet alongside your existing Harpoon keymaps
- The UI enhancements (menu titles, status line) provide better context

## Use Cases

### Development Workflows

- **Feature Development**: Create a list for each feature branch with relevant files
- **Bug Fixing**: Maintain separate lists for different bugs or issues
- **Code Review**: Organize files by pull request or review session

### Project Organization

- **Frontend/Backend**: Separate lists for different parts of your application
- **Documentation**: Keep docs, configs, and code in different lists
- **Testing**: Organize test files separately from implementation

### Learning & Exploration

- **Study Sessions**: Create focused lists for learning specific concepts
- **Refactoring**: Track files involved in large refactoring efforts
- **Research**: Organize files when investigating unfamiliar codebases

## Troubleshooting

### Lists Not Persisting

- Check that the data directory is writable: `:echo stdpath('data')`
- Enable debug mode: `debug_mode = true` in your config
- Use `:FleetProjectInfo` to verify project detection

### Project Detection Issues

- Ensure you're in a Git repository or the project root
- Check project ID with `:FleetProjectInfo`
- Clear cache by changing directories and returning

### Performance

- Fleet uses caching to minimize file system operations
- Cache is automatically cleared when changing projects
- Lists are loaded on-demand to maintain responsiveness

## License

MIT License - see LICENSE file for details.

## Acknowledgments

- [ThePrimeagen](https://github.com/ThePrimeagen) for creating the excellent Harpoon plugin
- The Neovim community for inspiration and feedback

## Related Projects

- [Harpoon](https://github.com/ThePrimeagen/harpoon) - The foundation that Fleet builds upon
- [Arrow.nvim](https://github.com/otavioschwanck/arrow.nvim) - Another Harpoon-inspired plugin
- [Bookmarks.nvim](https://github.com/crusj/bookmarks.nvim) - Alternative bookmark management

---

**Fleet.nvim** - Set sail with organized, persistent file navigation! ⚓
