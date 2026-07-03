local M = {}

local ssh_dir = vim.fn.expand("~/.ssh")
local ssh_config = ssh_dir .. "/config"

function M.ensure_ssh_dir()
	vim.fn.mkdir(ssh_dir, "p", "0700")
end

function M.parse_remote_path(remote_path)
	local user, host, path
	local u, h, p = remote_path:match("^([^@]+)@([^:]+):?(.-)$")
	if u and h then
		user = u
		host = h
		path = p ~= "" and p or nil
	else
		h, p = remote_path:match("^([^:]+):?(.-)$")
		if h then
			host = h
			path = p ~= "" and p or nil
		end
	end
	return user, host, path
end

function M.sanitize_alias(alias)
	alias = vim.trim(alias)
	alias = alias:gsub("%s+", "-")
	alias = alias:gsub("[^a-zA-Z0-9_-]", "")
	return alias
end

function M.list_hosts()
	M.ensure_ssh_dir()

	local hosts = {}
	if vim.fn.filereadable(ssh_config) == 0 then
		return hosts
	end

	local lines = vim.fn.readfile(ssh_config)
	local current_host = nil

	for _, line in ipairs(lines) do
		local host_match = line:match("^Host%s+(.+)$")
		if host_match then
			current_host = {
				alias = vim.trim(host_match),
				hostname = nil,
				user = nil,
				identity = nil,
			}
			table.insert(hosts, current_host)
		elseif current_host then
			local hostname = line:match("%s*HostName%s+(.+)$")
			if hostname then
				current_host.hostname = vim.trim(hostname)
			end

			local user = line:match("%s*User%s+(.+)$")
			if user then
				current_host.user = vim.trim(user)
			end

			local identity = line:match("%s*IdentityFile%s+(.+)$")
			if identity then
				current_host.identity = vim.trim(identity)
			end
		end
	end

	return hosts
end

function M.host_exists(alias)
	local hosts = M.list_hosts()
	for _, h in ipairs(hosts) do
		if h.alias == alias then
			return true
		end
	end
	return false
end

function M.get_host(alias)
	local hosts = M.list_hosts()
	for _, h in ipairs(hosts) do
		if h.alias == alias then
			return h
		end
	end
	return nil
end

function M.get_identity_file(alias)
	return ssh_dir .. "/id_ed25519_" .. alias
end

function M.generate_key(alias, callback)
	M.ensure_ssh_dir()

	local identity_file = M.get_identity_file(alias)

	if vim.fn.filereadable(identity_file) == 1 then
		callback(true, identity_file)
		return
	end

	vim.notify("Generating SSH key for " .. alias .. "...", vim.log.levels.INFO)

	local job = vim.fn.jobstart({
		"ssh-keygen",
		"-t",
		"ed25519",
		"-a",
		"100",
		"-f",
		identity_file,
		"-N",
		"",
		"-C",
		string.format("%s@%s", vim.fn.getenv("USER") or "user", vim.fn.hostname()),
	}, {
		on_exit = function(_, code)
			vim.schedule(function()
				if code ~= 0 then
					vim.notify("Failed to generate SSH key", vim.log.levels.ERROR)
					callback(false, nil)
					return
				end
				vim.notify("SSH key generated: " .. identity_file, vim.log.levels.INFO)
				callback(true, identity_file)
			end)
		end,
	})

	if job <= 0 then
		callback(false, nil)
	end
end

function M.copy_key_to_server(alias, user, host, password, callback)
	local identity_file = M.get_identity_file(alias)
	local public_key = identity_file .. ".pub"

	if vim.fn.filereadable(public_key) == 0 then
		callback(false)
		return
	end

	local pub_key_lines = vim.fn.readfile(public_key)
	if #pub_key_lines == 0 then
		callback(false)
		return
	end
	local pub_key_content = vim.trim(pub_key_lines[1])

	if not password or password == "" then
		M.show_manual_copy_instructions(alias, user, host, identity_file)
		callback(false)
		return
	end

	if vim.fn.executable("sshpass") == 0 then
		vim.notify("sshpass not installed. Please install it or copy key manually.", vim.log.levels.WARN)
		M.show_manual_copy_instructions(alias, user, host, identity_file)
		callback(false)
		return
	end

	vim.notify("Copying SSH key to " .. host .. "...", vim.log.levels.INFO)

	local cmd = string.format(
		"sshpass -p %s ssh -tt "
			.. "-o StrictHostKeyChecking=accept-new "
			.. "-o PasswordAuthentication=yes "
			.. "-o PubkeyAuthentication=no "
			.. "-o ConnectTimeout=10 "
			.. "%s@%s "
			.. "\"mkdir -p ~/.ssh && chmod 700 ~/.ssh && printf '%%s\\n' %s >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys\"",
		vim.fn.shellescape(password),
		user,
		host,
		vim.fn.shellescape(pub_key_content)
	)

	local result = vim.fn.system(cmd)

	if vim.v.shell_error == 0 then
		vim.notify("SSH key copied to " .. host, vim.log.levels.INFO)
		callback(true)
	else
		vim.notify("Failed to copy key: " .. vim.trim(result), vim.log.levels.WARN)
		M.show_manual_copy_instructions(alias, user, host, identity_file)
		callback(false)
	end
end

function M.show_manual_copy_instructions(alias, user, host, identity_file)
	local cmd = string.format("ssh-copy-id -i %s %s@%s", vim.fn.shellescape(identity_file .. ".pub"), user, host)
	vim.notify("Please run in terminal:\n" .. cmd, vim.log.levels.WARN)
	vim.fn.setreg("+", cmd)
	vim.notify("Command copied to clipboard", vim.log.levels.INFO)
end

function M.add_config_entry(alias, host, user, identity_file)
	M.ensure_ssh_dir()

	local lines = {}
	if vim.fn.filereadable(ssh_config) == 1 then
		lines = vim.fn.readfile(ssh_config)
	end

	for _, line in ipairs(lines) do
		if line:match("^Host%s+" .. vim.pesc(alias) .. "$") then
			return
		end
	end

	table.insert(lines, "")
	table.insert(lines, string.format("Host %s", alias))
	table.insert(lines, string.format("    HostName %s", host))
	if user then
		table.insert(lines, string.format("    User %s", user))
	end
	table.insert(lines, string.format("    IdentityFile %s", identity_file))
	table.insert(lines, "    IdentitiesOnly yes")
	table.insert(lines, "    AddKeysToAgent yes")

	vim.fn.writefile(lines, ssh_config)
	vim.fn.system("chmod 600 " .. vim.fn.shellescape(ssh_config))

	vim.notify("Added SSH config for " .. alias, vim.log.levels.INFO)
end

function M.remove_config_entry(alias)
	M.ensure_ssh_dir()
	if vim.fn.filereadable(ssh_config) == 0 then
		return false
	end

	local lines = vim.fn.readfile(ssh_config)
	local new_lines = {}
	local skip = false
	local removed = false

	for _, line in ipairs(lines) do
		local host_match = line:match("^Host%s+(.+)$")
		if host_match then
			if vim.trim(host_match) == alias then
				skip = true
				removed = true
			else
				skip = false
			end
		end
		if not skip then
			table.insert(new_lines, line)
		end
	end

	vim.fn.writefile(new_lines, ssh_config)
	if removed then
		vim.notify("Removed SSH config for " .. alias, vim.log.levels.INFO)
	end
	return removed
end

function M.remove_key(alias)
	local identity_file = M.get_identity_file(alias)
	local removed = false
	if vim.fn.filereadable(identity_file) == 1 then
		vim.fn.delete(identity_file)
		removed = true
	end
	if vim.fn.filereadable(identity_file .. ".pub") == 1 then
		vim.fn.delete(identity_file .. ".pub")
		removed = true
	end
	return removed
end

function M.remove_host(alias)
	local config_removed = M.remove_config_entry(alias)
	local key_removed = M.remove_key(alias)
	if config_removed or key_removed then
		vim.notify("Removed SSH host: " .. alias, vim.log.levels.INFO)
		return true
	end
	return false
end

function M.create_new_config(callback)
	vim.ui.input({
		prompt = "SSH alias name: ",
	}, function(alias_input)
		local alias = M.sanitize_alias(alias_input or "")

		if alias == "" then
			vim.notify("Alias required", vim.log.levels.WARN)
			callback(false)
			return
		end

		if M.host_exists(alias) then
			vim.notify("Alias '" .. alias .. "' already exists", vim.log.levels.ERROR)
			callback(false)
			return
		end

		vim.ui.input({
			prompt = "Remote host: ",
		}, function(remote_input)
			remote_input = remote_input and vim.trim(remote_input) or ""

			if remote_input == "" then
				vim.notify("Remote host required", vim.log.levels.WARN)
				callback(false)
				return
			end

			local user, host, _ = M.parse_remote_path(remote_input)
			if not host then
				host = remote_input
			end

			local prompt = "Password for " .. (user and user .. "@" or "") .. host .. " (empty to skip): "
			local password = vim.fn.inputsecret(prompt)

			M.generate_key(alias, function(success, identity_file)
				if not success then
					callback(false)
					return
				end

				M.add_config_entry(alias, host, user, identity_file)

				if password ~= "" then
					M.copy_key_to_server(
						alias,
						user or vim.fn.getenv("USER") or "root",
						host,
						password,
						function(copied)
							if copied then
								vim.notify("SSH setup complete for " .. alias, vim.log.levels.INFO)
							end
							callback(true, alias, host, user)
						end
					)
				else
					M.show_manual_copy_instructions(alias, user or vim.fn.getenv("USER") or "root", host, identity_file)
					callback(true, alias, host, user)
				end
			end)
		end)
	end)
end

function M.get_alias_for_host(remote_path)
	local user, host, _ = M.parse_remote_path(remote_path)
	if not host then
		return nil
	end
	return M.sanitize_alias((user and user .. "-" or "") .. host:gsub("%.", "-"))
end

return M
