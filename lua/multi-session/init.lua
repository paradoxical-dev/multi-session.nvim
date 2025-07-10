local M = {}
local pickers = require("multi-session.pickers")
local state = require("multi-session.state")
local utils = require("multi-session.utils")
local session_dir = utils.session_dir
local uv = vim.uv or vim.loop

M.config = {
	notify = true, -- show notifications after performing actions
	preserve = { -- extra aspects of the user session to preserve
		breakpoints = true, -- requires dap-utils.nvim
		qflist = true, -- requires quickfix.nvim
		undo = true,
		watches = true, -- requires dap-utils.nvim
	},
	branch_scope = true, -- TODO: implement branch scoped sessions
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

M.active_session = false

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
			utils.load_session(path, M.config.preserve)
			M.active_session = true

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
	utils.load_session(path, M.config.preserve)
	M.active_session = true

	state.save(project, session)

	if M.config.notify then
		vim.notify("Loaded session: " .. session, vim.log.levels.INFO)
	end
end

M.save = function()
	if M.active_session then
		local overwrite = vim.fn.confirm("Overwrite your current session?", "&Yes\n&No", 2)
		if overwrite == 1 then
			local s = state.load()
			if not s then
				vim.notify("Unable to load session details", vim.log.levels.ERROR)
				return
			end

			local session_path = session_dir .. "/" .. s.project .. "/" .. s.session
			utils.save_session(session_path, M.config.preserve)

			if M.config.notify then
				vim.notify("Saved session as: " .. s.session, vim.log.levels.INFO)
			end

			return
		end
	end

	local sanitized_dir = vim.fn.getcwd():gsub("[\\/:]+", "%%")
	local project_dir = session_dir .. "/" .. sanitized_dir
	local exists = uv.fs_stat(project_dir)

	if not exists then
		vim.fn.mkdir(project_dir, "p")
	end

	vim.ui.input({ prompt = "Session name:" }, function(name)
		if not name or name == "" then
			vim.notify("Session save cancelled", vim.log.levels.WARN)
			return
		end

		local session_path = project_dir .. "/" .. name
		vim.fn.mkdir(session_path, "p")

		utils.save_session(session_path, M.config.preserve)
		state.save(sanitized_dir, name)

		if M.config.notify then
			vim.notify("Saved session as: " .. name, vim.log.levels.INFO)
		end
	end)
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
