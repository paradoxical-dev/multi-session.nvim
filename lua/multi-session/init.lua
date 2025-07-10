local M = {}
local pickers = require("multi-session.pickers")
local state = require("multi-session.state")
local session_dir = require("multi-session.utils").session_dir
local uv = vim.uv or vim.loop

M.config = {
	notify = true, -- show notifications after performing actions
	preserve = { -- which aspects of the user session to preserve
		cwd = true,
		buffers = true,
		tabpages = true,
		layout = true,
	},
	picker = {
		default = "vim", -- vim|snacks
		vim = {
			project_icon = "",
			session_icon = "󰑏",
		},
		snacks = {
			-- can be any snacks preset layout or custom layout table
			-- see https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#%EF%B8%8F-layouts
			layout = "vertical",
			project_icon = "",
			session_icon = "󰑏",
			hl = {
				base_dir = "SnacksPickerDir",
				project_dir = "Directory",
				session = "SnacksPickerBold",
			},
		},
	},
}

---@param opts? table
M.select = function(opts)
	local default_picker = M.config.picker.default
	local picker_options = M.config.picker[default_picker]

	if opts and opts.cwd == true then
		local project = vim.fn.getcwd():gsub("[\\/:]+", "%%")
		pickers[default_picker]("sessions", project, picker_options)
		return
	end

	pickers[default_picker]("projects", nil, picker_options)
end

---@param opts table
---@param project string
---@param session string
M.load = function(opts, project, session)
	if opts and opts.latest == true then
		local s = state.load()
		if s then
			local path = vim.fs.joinpath(session_dir, s.project, s.session)
			vim.cmd("source " .. vim.fn.fnameescape(path))

			if M.config.notify then
				vim.notify("Loaded latest session: " .. s.session, vim.log.levels.INFO)
			end
		end
		return
	end

	if not (project and session) or session == "" then
		return
	end

	local path = vim.fs.joinpath(session_dir, project, session)
	vim.cmd("source " .. vim.fn.fnameescape(path))

	state.save(project, session)

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

M.delete = function()
	vim.cmd("silent !rm " .. session_dir .. "/session.vim")
end

function M.setup(opts)
	if uv.fs_stat(session_dir) then
		vim.fn.mkdir(session_dir, "p")
	end
	state.file_check()
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

return M
