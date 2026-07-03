local M = {}

M.config = {
	keymaps = {},
	attachMode = "internal",
}

local state = require("neovim-remote.state")
local mount = require("neovim-remote.mount")
local sshfs = require("neovim-remote.sshfs")
local terminal = require("neovim-remote.terminal")
local remote_terminal = require("neovim-remote.remote_terminal")

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
	terminal.setup({ mode = M.config.attachMode })
	state.init()

	local augroup = vim.api.nvim_create_augroup("NeovimRemote", { clear = true })

	vim.api.nvim_create_autocmd("VimEnter", {
		group = augroup,
		callback = function()
			state.cleanup_stale()
		end,
	})

	local actions = {
		toggle = M.remote_terminal_toggle,
		attach = M.picker_attach,
		detach = M.picker_detach,
		list = M.list_sessions_ui,
		clear = M.clear_all_sessions,
	}

	require("neovim-remote.keymaps").setup(M.config.keymaps, actions)
end

function M.remote_terminal_toggle()
	local cwd = vim.fn.getcwd()
	local mount_base = vim.fn.stdpath("data") .. "/neovim-remote/mounts/"

	if not vim.startswith(cwd, mount_base) then
		vim.notify("Not in a remote mount.", vim.log.levels.INFO)
		return
	end

	local hash = vim.fn.fnamemodify(cwd, ":t")
	local session = state.get(hash)
	if not session then
		vim.notify("No session found for this mount", vim.log.levels.WARN)
		return
	end

	local alias, path = session.remote_path:match("^([^:]+):(.+)$")
	if not alias then
		vim.notify("Could not parse remote path", vim.log.levels.WARN)
		return
	end

	remote_terminal.toggle(hash, alias, path)
end

function M.attach(remote_path)
	local hash = vim.fn.sha256(remote_path)
	local mount_path = mount.get_path(hash)

	if mount.is_mounted(mount_path) then
		if not state.has(hash) then
			state.add(hash, remote_path)
		end
		terminal.open(mount_path)
		return
	end

	if state.has(hash) then
		state.remove(hash)
	end

	mount.ensure_dir(hash)

	sshfs.mount(remote_path, mount_path, function(success, err_type, err_msg)
		if not success then
			vim.notify(err_msg or "Mount failed", vim.log.levels.ERROR)
			mount.cleanup(hash)
			return
		end

		state.add(hash, remote_path)
		terminal.open(mount_path)
	end)
end

function M.detach(hash)
	if not state.has(hash) then
		vim.notify("No session for hash: " .. hash:sub(1, 8), vim.log.levels.WARN)
		return
	end

	remote_terminal.kill(hash)

	mount.cleanup(hash, function(success)
		vim.schedule(function()
			if success then
				state.remove(hash)
				vim.notify("Detached " .. hash:sub(1, 8), vim.log.levels.INFO)
			else
				vim.notify("Unmount failed for " .. hash:sub(1, 8), vim.log.levels.ERROR)
			end
		end)
	end)
end

function M.clear_all_sessions()
	local sessions = state.get_all()
	local hashes = vim.tbl_keys(sessions)

	if #hashes == 0 then
		vim.notify("No sessions to clear.", vim.log.levels.INFO)
		return
	end

	local count = 0
	for _, hash in ipairs(hashes) do
		M.detach(hash)
		count = count + 1
	end

	vim.notify("Cleared " .. count .. " session(s).", vim.log.levels.INFO)
end

function M.list_sessions()
	local result = {}
	for hash, session in pairs(state.get_all()) do
		table.insert(result, {
			hash = hash,
			remote_path = session.remote_path,
			last_used = session.last_used,
		})
	end
	return result
end

function M.list_sessions_ui()
	local sessions = M.list_sessions()

	if #sessions == 0 then
		print("No remote sessions.")
		return
	end

	print("Remote Sessions:")
	print(string.rep("-", 60))
	for _, s in ipairs(sessions) do
		print(string.format("  %s", s.remote_path))
	end
end

function M.picker_attach()
	require("neovim-remote.picker").open({ action = "attach" })
end

function M.picker_detach()
	require("neovim-remote.picker").open({ action = "detach" })
end

return M
