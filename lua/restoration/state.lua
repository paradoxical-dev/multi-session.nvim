local M = {}

local session_dir = require("restoration.utils").session_dir
local state_file = session_dir .. "/last-session.json"

local uv = vim.uv or vim.loop

M.file_check = function()
	local exists = uv.fs_stat(state_file)
	if not exists then
		local f = io.open(state_file, "w")
		if f then
			return
		end
	end
end

---@param project string
---@param session string
---@param branch? string
M.save = function(project, session, branch)
	local f = io.open(state_file, "w")
	if f then
		local meta = {
			project = project,
			session = session,
		}
		if branch then
			meta.branch = branch
		end
		local data = vim.fn.json_encode(meta)
		f:write(data)
		f:close()
	end
end

M.load = function()
	local f = io.open(state_file, "r")
	if f then
		local data = f:read("*a")
		f:close()
		return vim.fn.json_decode(data)
	end
end

return M
