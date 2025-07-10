local M = {}
local pickers = require("multi-session.pickers")

local session_dir = vim.fn.stdpath("state") .. "/multi-session"
local uv = vim.uv or vim.loop

M.config = {
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
	vim.cmd("source " .. path)
end

M.save = function()
	local cwd = uv.cwd()
	local current_dir = vim.fn.fnamemodify(cwd, ":t")
	local project = session_dir .. "/" .. current_dir
	print(project)
	if not uv.fs_stat(project) then
		vim.fn.mkdir(project, "p")
	end
	vim.cmd("mksession! " .. project .. "/session.vim")
end

M.delete = function()
	vim.cmd("silent !rm " .. session_dir .. "/session.vim")
end

function M.setup(opts)
	if not vim.loop.fs_stat(session_dir) then
		vim.fn.mkdir(session_dir, "p")
	end
end

return M
