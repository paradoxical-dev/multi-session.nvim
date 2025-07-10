local M = {}

local session_dir = require("multi-session.utils").session_dir
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
M.save = function(project, session)
	local f = io.open(state_file, "w")
	if f then
		local data = vim.fn.json_encode({ project = project, session = session })
		f:write(data)
		f:close()
	end
end

M.load = function()
	local f = io.open(state_file, "r")
	if f then
		local data = f:read("*a")
		f:close()
		-- print(vim.inspect(vim.fn.json_decode(data)))
		return vim.fn.json_decode(data)
	end
end

return M
