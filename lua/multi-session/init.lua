local M = {}
local pickers = require("multi-session.pickers")

local session_dir = vim.fn.stdpath("state") .. "/multi-session"
local uv = vim.uv or vim.loop

M.config = {
	notify = true, -- show notifications after performing actions
	preserve = {
		cwd = true,
		buffers = true,
		tabpages = true,
		layout = true,
	},
	picker = {
		default = "snacks", -- default|snacks
		snacks = {
			-- can be any snacks preset layout or custom layout table
			-- see https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#%EF%B8%8F-config
			layout = "telescope",
			project_icon = "",
			session_icon = "󰑏",
			project_hl = "Directory",
			session_hl = "SnacksPickerBold",
		},
	},
}

M.select = function()
	if M.config.picker.default == "snacks" then
		pickers.snacks("projects", nil, M.config.picker.snacks)
	else
		pickers.default("projects")
	end
end

---@param project string
---@param session string
M.load = function(project, session)
	local path = vim.fs.joinpath(session_dir, project, session)
	vim.cmd("source " .. vim.fn.fnameescape(path))
	if M.config.notify then
		vim.notify("Loaded session: " .. session, vim.log.levels.INFO)
	end
end

M.save = function()
	local sanitized_dir = vim.fn.getcwd():gsub("[\\/:]+", "%%")
	local project_dir = session_dir .. "/" .. sanitized_dir
	local exists = uv.fs_stat(project_dir)

	if not exists then
		vim.fn.mkdir(project_dir, "p")
	end

	local full_path = vim.fn.fnameescape(project_dir .. "/session.vim")
	vim.cmd("mksession! " .. full_path)

	if M.config.notify then
		vim.notify("Saved session as: " .. "session", vim.log.levels.INFO)
	end
end

M.sanitize_path = function()
	local cwd = uv.cwd()
	local ret = cwd:gsub("/", "%")
	print(ret)
end

M.delete = function()
	vim.cmd("silent !rm " .. session_dir .. "/session.vim")
end

function M.setup(opts)
	if not vim.loop.fs_stat(session_dir) then
		vim.fn.mkdir(session_dir, "p")
	end
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

return M
