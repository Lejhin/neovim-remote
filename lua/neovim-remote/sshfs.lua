local M = {}

function M.mount(remote_path, mount_path, on_result)
	local stderr_lines = {}
	local timeout_timer = nil

	local expanded_remote = remote_path
	local alias, path = remote_path:match("^([^:]+):(.+)$")
	if path == "~" then
		expanded_remote = alias
	end

	local args = {
		"sshfs",
		expanded_remote,
		mount_path,
		"-o",
		"IdentitiesOnly=yes",
		"-o",
		"StrictHostKeyChecking=accept-new",
	}

	if alias then
		local ssh_config = require("neovim-remote.ssh-config")
		local identity_file = ssh_config.get_identity_file(alias)
		if vim.fn.filereadable(identity_file) == 1 then
			table.insert(args, "-o")
			table.insert(args, "IdentityFile=" .. identity_file)
		end
	end

	local job = vim.fn.jobstart(args, {
		on_stderr = function(_, data)
			if not data then
				return
			end
			for _, line in ipairs(data) do
				if line ~= "" then
					table.insert(stderr_lines, line)
				end
			end
		end,
		on_exit = function(_, exit_code)
			if timeout_timer then
				timeout_timer:stop()
				timeout_timer:close()
			end

			vim.schedule(function()
				if exit_code ~= 0 then
					local err = table.concat(stderr_lines, " | ")
					local err_type = "MOUNT_FAILED"
					if err:match("permission denied") or err:match("auth") or err:match("password") then
						err_type = "AUTH_FAILED"
					end
					on_result(false, err_type, err)
					return
				end

				local mount = require("neovim-remote.mount")
				if mount.is_mounted(mount_path) then
					on_result(true, nil, nil)
				else
					on_result(false, "MOUNT_FAILED", "Mount not detected")
				end
			end)
		end,
	})

	if job <= 0 then
		on_result(false, "START_FAILED", "Failed to start sshfs")
		return nil
	end

	timeout_timer = vim.loop.new_timer()
	timeout_timer:start(
		30000,
		0,
		vim.schedule_wrap(function()
			vim.fn.jobstop(job)
			on_result(false, "TIMEOUT", "sshfs timed out after 30s")
		end)
	)

	return job
end

return M
