local M = {}

local state = require("neovim-remote.state")
local mount = require("neovim-remote.mount")
local terminal = require("neovim-remote.terminal")
local ssh_config = require("neovim-remote.ssh-config")

function M.open(opts)
	opts = opts or { action = "attach" }

	if opts.action == "attach" then
		M.open_ssh_config_picker()
	else
		M.open_detach_picker()
	end
end

function M.open_ssh_config_picker()
	local ok, snacks = pcall(require, "snacks")
	if not ok then
		vim.notify("snacks.nvim is required", vim.log.levels.ERROR)
		return
	end

	local hosts = ssh_config.list_hosts()
	local items = {}

	table.insert(items, {
		id = "new_config",
		alias = nil,
		text = "󰐕  Create new SSH config...",
		is_new_config = true,
		score = 999,
	})

	for _, host in ipairs(hosts) do
		local display = host.alias
		if host.hostname then
			display = display .. "  (" .. host.hostname .. ")"
		end
		if host.user then
			display = display .. "  user: " .. host.user
		end

		table.insert(items, {
			id = host.alias,
			alias = host.alias,
			hostname = host.hostname,
			user = host.user,
			identity = host.identity,
			text = "  " .. display,
			is_new_config = false,
			score = 0,
		})
	end

	snacks.picker.pick({
		title = "Select SSH Config",
		items = items,
		layout = { preset = "select" },

		format = function(item)
			if item.is_new_config then
				return { { item.text, "SnacksPickerDir" } }
			end
			return { { item.text, "SnacksPickerItem" } }
		end,

		confirm = function(picker, item)
			picker:close()

			local data = item and (item.item or item) or nil

			if not data or data.is_new_config then
				ssh_config.create_new_config(function(success, alias, hostname, user)
					if not success then
						return
					end
					M.open_path_picker(alias)
				end)
				return
			end

			if data.alias then
				M.open_path_picker(data.alias)
			end
		end,
	})
end

function M.open_path_picker(alias)
	local ok, snacks = pcall(require, "snacks")
	if not ok then
		vim.notify("snacks.nvim is required", vim.log.levels.ERROR)
		return
	end

	local items = {}
	local mounted_paths = {}

	for hash, session in pairs(state.get_all()) do
		local session_alias, path = session.remote_path:match("^([^:]+):(.+)$")
		if session_alias == alias then
			local mount_path = mount.get_path(hash)
			local is_mounted = mount.is_mounted(mount_path)

			table.insert(mounted_paths, {
				path = path,
				hash = hash,
				mounted = is_mounted,
			})
		end
	end

	table.insert(items, {
		id = "new_path",
		path = nil,
		text = "󰐕  New path...",
		is_new_path = true,
		score = 999,
	})

	for _, mp in ipairs(mounted_paths) do
		local status_icon = mp.mounted and "●" or "○"
		table.insert(items, {
			id = mp.hash,
			hash = mp.hash,
			path = mp.path,
			text = string.format("  %s  %s  %s", status_icon, mp.mounted and "mounted" or "offline", mp.path),
			mounted = mp.mounted,
			is_new_path = false,
			score = mp.mounted and 100 or 0,
		})
	end

	table.sort(items, function(a, b)
		if a.is_new_path then
			return true
		end
		if b.is_new_path then
			return false
		end
		return a.score > b.score
	end)

	snacks.picker.pick({
		title = "Select Path for " .. alias,
		items = items,
		layout = { preset = "select" },

		format = function(item)
			if item.is_new_path then
				return { { item.text, "SnacksPickerDir" } }
			end
			return {
				{ item.text, item.mounted and "SnacksPickerItemActive" or "SnacksPickerItemInactive" },
			}
		end,

		confirm = function(picker, item)
			picker:close()

			local data = item and (item.item or item) or nil

			if not data or data.is_new_path then
				M.ask_new_path(alias)
				return
			end

			if data.mounted then
				terminal.open(mount.get_path(data.hash))
				return
			end

			local remote_path = alias .. ":" .. data.path
			require("neovim-remote").attach(remote_path)
		end,
	})
end

function M.ask_new_path(alias)
	vim.ui.input({
		prompt = "Remote absolute path: ",
	}, function(path)
		if not path or path == "" then
			vim.notify("Path required", vim.log.levels.WARN)
			return
		end

		if not path:match("^/") then
			vim.notify("Absolute path required (must start with /)", vim.log.levels.WARN)
			return
		end

		local remote_path = alias .. ":" .. path
		require("neovim-remote").attach(remote_path)
	end)
end

function M.open_detach_picker()
	local ok, snacks = pcall(require, "snacks")
	if not ok then
		vim.notify("snacks.nvim is required", vim.log.levels.ERROR)
		return
	end

	local items = {}
	local all_sessions = state.get_all()

	for hash, session in pairs(all_sessions) do
		local mount_path = mount.get_path(hash)
		local is_mounted = mount.is_mounted(mount_path)

		table.insert(items, {
			hash = hash,
			text = string.format("%s  %s", is_mounted and "●" or "○", session.remote_path),
			mounted = is_mounted,
		})
	end

	if #items == 0 then
		vim.notify("No sessions to detach.", vim.log.levels.INFO)
		return
	end

	snacks.picker.select(items, {
		title = "Remote Detach",
		prompt = "Select session to detach",
		format_item = function(item)
			return item.text
		end,
	}, function(item)
		if not item then
			return
		end
		require("neovim-remote").detach(item.hash)
	end)
end

function M.format_remote_path(remote_path)
	local alias, path = remote_path:match("^([^:]+):(.+)$")
	if not alias then
		return remote_path
	end
	return alias .. "  " .. path
end

return M
