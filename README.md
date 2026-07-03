# neovim-remote

> **ATTENTION**
> This Plugin is my first exposure to the neovim plugin eco-system. 
> Use on your own risk, but it seems to work just fine for now

> **Why its great**
> You dont have to copy or install neovim on the server. Your config just works
> like it is local. Just attach to your server via ssh or create ssh configs.
> The keys + configs get generated without a headache and public key gets
> transfered to the server. You only have to type in your password once during
> creation. You can use the profile externaly as the config is generic.
> Integrated Remote Terminal Wraps the SSH-connection on spawn-up so you can
> interact with the server inside neovim. Just like vscode. 

## Requirements

- Neovim >= 0.10
- sshfs
- ssh with key-based authentication (password prompts are not supported in floating terminals)
- sshpass to send the generated ssh-key to the server for a smooth connection workflow

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
  attachMode = "internal" | "external"
})
```

attachMode is a fix for WSL. internal changes saves the current workspace and changes internally while triggering
the **snacks**.dashboard, if installed. The Mode "external" opens an entire new window, just like vscode.
Default mode is internal. If you want an external window, feel free to change the config.

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

Press `<leader>ra` to open the picker. Select an SSH host or create a new one.
Enter the remote path (absolute, e.g. `/home/user/project`). SSHFS mounts the
directory and changes directory to the mount point (or opens external terminal with neovim launched in the session-path)

### 2. Edit locally

Work in Neovim as usual. LSP, treesitter, and all plugins function normally because the files are local.

### 3. Remote terminal

Press `<leader>rt` inside a mounted directory. A floating window opens, connects via SSH, and changes to the remote directory. Press `<leader>rt` again to close it. The buffer is preserved.

### 4. Detach

Press `<leader>rd` to open the detach picker and select a mount to unmount. Press `<leader>rC` to unmount all sessions.

### 5. List

Press `<leader>tl`  to see a list of all mounted directories to get an overview 

## Troubleshooting

**"Not in a remote mount"**

You are not inside a mounted directory. Check active sessions with `<leader>rl`.

**Mount cannot be detached**

manually unmount the folders (make sure to delete the unmounted folder afterwards).

```bash
umount ~/.local/share/nvim/neovim-remote/mounts/<folder> 
rm -rf <folder>

```

**SSHPASS not installed**

ssh-config entry is written into  ~/.ssh/config and private + public is
generated without the public key being transfered to the server. 

fixes: 

- You have to manually remove the keys + config entry after installing sshpass and try again 
- push the public key to the server by yourself

# License

APACHE 2.0
