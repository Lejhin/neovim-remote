local M = {}

local state_file = vim.fn.stdpath("data") .. "/neovim-remote/neovim-remote_sessions.json"
local mouting_base = vim.fn.stdpath("data") .. "/neovim-remote/mounts/"

local sessions = {}
local first_toggle = {}
local initialized = false

function M.init()
	if initialized then
		return
	end
	initialized = true

	vim.fn.mkdir(vim.fn.fnamemodify(state_file, ":h"), "p")
	vim.fn.mkdir(mouting_base, "p")

	if vim.fn.filereadable(state_file) == 0 then
		return
	end

	local content = vim.fn.readfile(state_file)
	if #content == 0 then
		return
	end

	local ok, decoded = pcall(vim.json.decode, table.concat(content, "\n"))
	if not ok or type(decoded) ~= "table" then
		return
	end

	for k, v in pairs(decoded) do
		if type(k) == "number" and type(v) == "string" then
			sessions[v] = { remote_path = nil, password = nil }
		elseif type(k) == "string" and type(v) == "table" then
			sessions[k] = v
		end
	end
end

local function persist()
	local ok, encoded = pcall(vim.json.encode, sessions)
	if not ok then
		vim.notify("Failed to encode sessions", vim.log.levels.ERROR)
		return
	end
	vim.fn.writefile({ encoded }, state_file)
end

function M.add(hash, remote_path)
	M.init()
	sessions[hash] = {
		remote_path = remote_path,
		last_used = os.time(),
	}
	first_toggle[hash] = true
	persist()
end

function M.remove(hash)
	M.init()
	sessions[hash] = nil
	first_toggle[hash] = nil
	persist()
end

function M.has(hash)
	M.init()
	return sessions[hash] ~= nil
end

function M.get(hash)
	M.init()
	return sessions[hash]
end

function M.get_all()
	M.init()
	return sessions
end

function M.is_first_toggle(hash)
	return first_toggle[hash] == true
end

function M.mark_toggled(hash)
	first_toggle[hash] = nil
end

function M.cleanup_stale()
	M.init()
	local mount = require("neovim-remote.mount")
	for hash, _ in pairs(sessions) do
		local path = mount.get_path(hash)
		if not mount.is_mounted(path) then
			M.remove(hash)
		end
	end
end

return M
