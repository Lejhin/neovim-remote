local M = {}

function M.open(path)
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

	vim.notify("No terminal available", vim.log.levels.ERROR)
	return false
end

return M
