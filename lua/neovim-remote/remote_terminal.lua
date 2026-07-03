local M = {}

local remote_terminals = {}

local function get_float_config()
	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.8)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	return {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
	}
end

function M.get_buf(hash)
	local buf = remote_terminals[hash]
	if buf and vim.api.nvim_buf_is_valid(buf) then
		return buf
	end
	remote_terminals[hash] = nil
	return nil
end

function M.is_visible(hash)
	local buf = M.get_buf(hash)
	if not buf then
		return false
	end
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_buf(win) == buf then
			return true
		end
	end
	return false
end

function M.open(hash, alias, path)
	if M.get_buf(hash) then
		vim.notify("Remote terminal already open.", vim.log.levels.INFO)
		M.show(hash)
		return
	end

	vim.notify("Connecting to " .. alias .. "...", vim.log.levels.INFO)

	local buf = vim.api.nvim_create_buf(false, true)
	local config = get_float_config()
	local win = vim.api.nvim_open_win(buf, true, config)

	local chan = vim.fn.termopen(vim.o.shell, {
		on_exit = function()
			remote_terminals[hash] = nil
		end,
	})

	vim.b[buf].remote_terminal_hash = hash

	remote_terminals[hash] = buf

	vim.defer_fn(function()
		if not vim.api.nvim_buf_is_valid(buf) then
			return
		end
		local ssh_cmd = string.format("ssh -tt %s 'cd %s && clear && exec $SHELL'\r", alias, path or ".")
		vim.api.nvim_chan_send(chan, ssh_cmd)
	end, 200)
end

function M.close(hash)
	local buf = M.get_buf(hash)
	if not buf then
		return
	end

	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_buf(win) == buf then
			vim.api.nvim_win_close(win, true)
			return
		end
	end
end

function M.show(hash)
	local buf = M.get_buf(hash)
	if not buf then
		vim.notify("No remote terminal. Use open first.", vim.log.levels.WARN)
		return
	end

	if M.is_visible(hash) then
		return
	end

	local config = get_float_config()
	vim.api.nvim_open_win(buf, true, config)
end

function M.toggle(hash, alias, path)
	if M.get_buf(hash) then
		if M.is_visible(hash) then
			M.close(hash)
		else
			M.show(hash)
		end
	else
		M.open(hash, alias, path)
	end
end

function M.kill(hash)
	local buf = M.get_buf(hash)
	if not buf then
		return
	end
	vim.api.nvim_buf_delete(buf, { force = true })
	remote_terminals[hash] = nil
end

return M
