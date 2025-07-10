local M = {}

local uv = vim.uv or vim.loop
M.session_dir = vim.fn.stdpath("state") .. "/multi-session"

---@param project string
---@return string[]
M.session_list = function(project)
	local sessions = {}
	local fd = uv.fs_scandir(M.session_dir .. "/" .. project)
	if not fd then
		return sessions
	end
	while true do
		local name, type = uv.fs_scandir_next(fd)
		if not name then
			break
		end
		if type == "directory" then
			table.insert(sessions, name)
		end
	end
	return sessions
end

---@return string[]
M.project_list = function()
	local dirs = {}
	local fd = uv.fs_scandir(M.session_dir)
	if not fd then
		return dirs
	end
	while true do
		local name, type = uv.fs_scandir_next(fd)
		if not name then
			break
		end

		if type == "directory" then
			table.insert(dirs, name)
		end
	end
	return dirs
end

return M
