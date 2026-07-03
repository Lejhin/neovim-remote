vim.api.nvim_create_user_command("RemoteAttach", function()
	require("neovim-remote").picker_attach()
end, {})

vim.api.nvim_create_user_command("RemoteDetach", function()
	require("neovim-remote").picker_detach()
end, {})

vim.api.nvim_create_user_command("RemoteList", function()
	local sessions = require("neovim-remote").list_sessions()
	for _, s in ipairs(sessions) do
		local status = s.mounted and "● mounted" or "✗ offline"
		print(string.format("%s %s %s", status, s.hash:sub(1, 8), s.remote_path or "unknown"))
	end
end, {})

vim.api.nvim_create_user_command("RemoteClearAll", function()
	require("neovim-remote").clear_all_sessions()
end, {})

vim.api.nvim_create_user_command("RemoteTerminalToggle", function()
	require("neovim-remote").remote_terminal_toggle()
end, { desc = "Toggle SSH Terminal for remote mount" })
