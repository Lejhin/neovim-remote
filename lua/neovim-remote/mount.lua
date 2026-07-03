local M = {}

local mouting_base = vim.fn.stdpath("data") .. "/neovim-remote/mounts/"

function M.get_path(hash)
	return mouting_base .. hash
end

function M.is_mounted(path)
	local stat = vim.loop.fs_stat(path)
	if not stat then
		return false
	end

	local handle = vim.loop.fs_scandir(path)
	if not handle then
		return false
	end

	local name, type = vim.loop.fs_scandir_next(handle)
	return name ~= nil
end

function M.ensure_dir(hash)
	local path = M.get_path(hash)
	if vim.fn.isdirectory(path) == 0 then
		vim.fn.mkdir(path, "p")
	end
	return path
end

function M.unmount_async(path, on_done)
	if not M.is_mounted(path) then
		if on_done then
			on_done(true)
		end
		return
	end

	vim.fn.jobstart({ "fusermount", "-uz", path }, {
		on_exit = function(_, code)
			local success = (code == 0)
			if not success then
				vim.schedule(function()
					vim.notify("fusermount failed for " .. path, vim.log.levels.ERROR)
				end)
			end
			if on_done then
				on_done(success)
			end
		end,
	})
end

function M.cleanup(hash, on_done)
	local path = M.get_path(hash)

	local function after_unmount(success)
		if vim.fn.isdirectory(path) == 1 and not M.is_mounted(path) then
			vim.fn.delete(path, "rf")
		end
		if on_done then
			on_done(success)
		end
	end

	if M.is_mounted(path) then
		M.unmount_async(path, after_unmount)
	else
		after_unmount(true)
	end
end

return M
