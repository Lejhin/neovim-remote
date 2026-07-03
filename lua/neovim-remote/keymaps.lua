local M = {}

M.defaults = {
	toggle = { lhs = "<leader>rt", mode = { "n", "t" }, opts = { desc = "Remote: Toggle Terminal" } },
	attach = { lhs = "<leader>ra", mode = "n", opts = { desc = "Remote: Attach" } },
	detach = { lhs = "<leader>rd", mode = "n", opts = { desc = "Remote: Detach" } },
	list = { lhs = "<leader>rl", mode = "n", opts = { desc = "Remote: List Sessions" } },
	clear = { lhs = "<leader>rC", mode = "n", opts = { desc = "Remote: Clear All" } },
}

function M.setup(user_maps, actions)
	if user_maps == false then
		return
	end

	local maps = vim.tbl_deep_extend("force", {}, M.defaults)
	if user_maps then
		for action, map in pairs(user_maps) do
			if map == false then
				maps[action] = nil
			else
				maps[action] = vim.tbl_deep_extend("force", maps[action] or {}, map)
			end
		end
	end

	for action, map in pairs(maps) do
		if map and map.lhs and actions[action] then
			local modes = type(map.mode) == "table" and map.mode or { map.mode or "n" }
			local lhs = map.lhs
			local rhs = actions[action]
			local opts = map.opts or { desc = "Remote: " .. action }

			for _, mode in ipairs(modes) do
				vim.keymap.set(mode, lhs, rhs, opts)
			end
		end
	end

	vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
end

return M
