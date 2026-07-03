# neovim-remote

Mount remote directories via SSHFS and work on them as local files in Neovim. Open SSH terminals in floating windows that automatically connect and change to the remote directory.

## Requirements

- Neovim >= 0.10
- SSHFS in `$PATH`
- SSH with key-based authentication (password prompts are not supported in floating terminals)
- Optional: [snacks.nvim](https://github.com/folke/snacks.nvim) for external terminal opening

## Installation

### lazy.nvim

```lua
{
  "Lejhin/neovim-remote",
  dependencies = {
    "folke/snacks.nvim",
  },
  config = function()
    require("neovim-remote").setup()
  end,
}
```

### Manual

```bash
git clone https://github.com/Lejhin/neovim-remote.git \\
  ~/.local/share/nvim/site/pack/plugins/start/neovim-remote
```

```lua
require("neovim-remote").setup()
```

## Configuration

### Minimal

```lua
require("neovim-remote").setup()
```

### With custom keymaps

```lua
require("neovim-remote").setup({
  keymaps = {
    toggle = { lhs = "<leader>rt", mode = { "n", "t" } },
    attach = { lhs = "<leader>ra" },
    detach = { lhs = "<leader>rd" },
    list   = { lhs = "<leader>rl" },
    clear  = { lhs = "<leader>rC" },
  }
})
```

### Disable all keymaps

```lua
require("neovim-remote").setup({
  keymaps = false,
})
```

### Override or disable individual keymaps

```lua
require("neovim-remote").setup({
  keymaps = {
    toggle = { lhs = "<C-t>", mode = { "n", "t" } },
    detach = false,
  }
})
```

## Default Keymaps

| Keymap | Mode | Action | Description |
|--------|------|--------|-------------|
| `<leader>rt` | `n`, `t` | toggle | Open or close the remote terminal |
| `<leader>ra` | `n` | attach | Open picker to attach a new remote mount |
| `<leader>rd` | `n` | detach | Detach a mount via picker |
| `<leader>rl` | `n` | list | Print all active sessions |
| `<leader>rC` | `n` | clear | Detach all sessions |

In terminal mode (`t`), `<Esc>` is mapped to `<C-\\><C-n>` to exit terminal insert mode.

## Commands

| Command | Description |
|---------|-------------|
| `:RemoteTerminalOpen` | Open SSH terminal for current mount |
| `:RemoteTerminalToggle` | Toggle SSH terminal (open/close) |
| `:RemoteTerminalClose` | Hide SSH terminal |
| `:RemoteTerminalShow` | Show hidden SSH terminal |
| `:RemoteTerminalKill` | Kill SSH terminal process |

## Usage

### 1. Attach

Press `<leader>ra` to open the picker. Select an SSH host or create a new one. Enter the remote path (absolute, e.g. `/home/user/project`). SSHFS mounts the directory and opens an external terminal in the mount point.

### 2. Edit locally

Work in Neovim as usual. LSP, treesitter, and all plugins function normally because the files are local.

### 3. Remote terminal

Press `<leader>rt` inside a mounted directory. A floating window opens, connects via SSH, and changes to the remote directory. Press `<leader>rt` again to close it. The buffer is preserved.

### 4. Detach

Press `<leader>rd` to open the detach picker and select a mount to unmount. Press `<leader>rC` to unmount all sessions.

## Troubleshooting

**"Not in a remote mount"**

You are not inside a mounted directory. Check active sessions with `<leader>rl`.

**SSH hangs or password prompt**

Remote terminals do not support interactive password input. Use SSH keys or ssh-agent.

**Mount cannot be detached**

```bash
# Check active mounts
mount | grep neovim-remote

# Manual unmount
fusermount3 -u ~/.local/share/nvim/neovim-remote/mounts/<hash>
```

**Picker is empty**

Ensure snacks.nvim is installed and the picker module is available.

## License

APACHE 2.0
