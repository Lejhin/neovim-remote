local M = {}

M.config = {
	mode = "internal",
}

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

function M.open(path)
	if M.config.mode == "internal" then
		return M.open_terminal_intern(path)
	elseif M.config.mode == "external" then
		return M.open_terminal_extern(path)
	else
		vim.notify(
			"Config mismatch: attachMode must be 'internal' or 'external' (default: internal)",
			vim.log.levels.ERROR
		)
		return false
	end
end

function M.open_terminal_intern(path)
	vim.cmd("wa")
	vim.cmd("cd " .. vim.fn.fnameescape(path))

	vim.defer_fn(function()
		local ok, snacks = pcall(require, "snacks")
		if ok and snacks.dashboard then
			pcall(function()
				snacks.dashboard()
			end)
		end
	end, 50)

	vim.notify("Switched to " .. path, vim.log.levels.INFO)
	return true
end
function M.open_terminal_extern(path)
	local terminals = {
		{ cmd = "kitty", args = { "--directory", path, "nvim" } },
		{ cmd = "alacritty", args = { "--working-directory", path, "-e", "nvim" } },
		{ cmd = "wezterm", args = { "start", "--cwd", path, "--", "nvim" } },
		{ cmd = "gnome-terminal", args = { "--working-directory=" .. path, "--", "nvim" } },
		{ cmd = "foot", args = { "-D", path, "nvim" } },
		{ cmd = "xterm", args = { "-e", "sh", "-c", string.format("cd %s && nvim", vim.fn.shellescape(path)) } },
	}

	for _, term in ipairs(terminals) do
		if vim.fn.executable(term.cmd) == 1 then
			local full_cmd = vim.deepcopy(term.args)
			table.insert(full_cmd, 1, term.cmd)
			vim.fn.jobstart(full_cmd, { detach = true })
			return true
		end
	end

	vim.notify("No terminal available. Use attachMode = 'internal'", vim.log.levels.ERROR)
	return false
end

return M
