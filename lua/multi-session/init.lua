local M = {}
local pickers = require("multi-session.pickers")
local state = require("multi-session.state")
local utils = require("multi-session.utils")
local session_dir = utils.session_dir
local uv = vim.uv or vim.loop

-- TODO: Add rename/remove session

M.config = {
	notify = true, -- show notifications after performing actions
	preserve = { -- extra aspects of the user session to preserve
		breakpoints = false, -- requires dap-utils.nvim
		qflist = false, -- requires quickfix.nvim
		undo = false,
		watches = false, -- requires dap-utils.nvim
	},
	branch_scope = true,
	picker = {
		default = "snacks", -- vim|snacks
		vim = {
			project_icon = "",
			session_icon = "󰑏",
		},
		snacks = {
			-- can be any snacks preset layout or custom layout table
			-- see https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#%EF%B8%8F-layouts
			layout = "default",
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
---@param branch? string
M.load = function(opts, project, session, branch)
	if opts and opts.latest then
		local s = state.load()
		if s then
			local path
			if s.branch and M.config.branch_scope then
				path = vim.fs.joinpath(session_dir, s.project, s.branch, s.session)
			else
				path = vim.fs.joinpath(session_dir, s.project, s.session)
			end

			utils.load_session(path, M.config.preserve)
			M.active_session = true
			state.save(s.project, s.session, s.branch)

			if M.config.notify then
				vim.notify("Loaded latest session: " .. s.session, vim.log.levels.INFO)
			end
		end
		return
	end

	if not (project and session) or session == "" then
		return
	end

	local path
	if branch and M.config.branch_scope then
		path = vim.fs.joinpath(session_dir, project, branch, session)
	else
		path = vim.fs.joinpath(session_dir, project, session)
	end
	utils.load_session(path, M.config.preserve)
	M.active_session = true

	if branch and M.config.branch_scope then
		state.save(project, session, branch)
	else
		state.save(project, session)
	end

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

	local cwd = vim.fn.getcwd()
	local sanitized_dir = vim.fn.getcwd():gsub("[\\/:]+", "%%")
	local project_dir = session_dir .. "/" .. sanitized_dir
	local exists = uv.fs_stat(project_dir)
	local branch

	if not exists then
		vim.fn.mkdir(project_dir, "p")
	end

	vim.ui.input({ prompt = "Session name:" }, function(name)
		if not name or name == "" then
			vim.notify("Session save cancelled", vim.log.levels.WARN)
			return
		end

		local session_path = ""
		if utils.is_repo(cwd) and M.config.branch_scope then
			branch = utils.current_branch(cwd)
			session_path = project_dir .. "/" .. branch .. "/" .. name
		else
			session_path = project_dir .. "/" .. name
		end
		vim.fn.mkdir(session_path, "p")

		utils.save_session(session_path, M.config.preserve)

		if M.config.branch_scope and branch then
			state.save(sanitized_dir, name, branch)
		else
			state.save(sanitized_dir, name)
		end

		if M.config.notify then
			vim.notify("Saved session as: " .. name, vim.log.levels.INFO)
		end
	end)
end

M.delete = function()
	vim.cmd("silent !rm " .. session_dir .. "/session.vim")
end

M.setup = function(opts)
	if uv.fs_stat(session_dir) then
		vim.fn.mkdir(session_dir, "p")
	end
	state.file_check()
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
	pickers.branch_scope = M.config.branch_scope
end

return M
