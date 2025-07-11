local M = {}
local pickers = require("multi-session.pickers")
local state = require("multi-session.state")
local utils = require("multi-session.utils")
local session_dir = utils.session_dir
local uv = vim.uv or vim.loop

-- TODO: Add rename/remove session
-- TODO: Add auto checkout for branch_scope

M.config = {
	auto_save = true, -- overwrite current session on exit
	notify = true,
	-- extra aspects of the user session to preserve
	preserve = {
		breakpoints = false, -- requires dap-utils.nvim
		qflist = false, -- requires quickfix.nvim
		undo = false,
		watches = false, -- requires dap-utils.nvim
	},
	branch_scope = true, -- store per branch sessions for git repos
	-- adds venv to vim.env,PATH and restarts lsp
	restore_venv = { -- TODO: implement
		enabled = true,
		patterns = { "venv", ".venv" }, -- patterns to match against for venv
	},
	picker = {
		default = "vim", -- vim|snacks
		vim = {
			icons = {
				project = "",
				session = "󰑏",
				branch = "",
			},
		},
		snacks = {
			-- can be any snacks preset layout or custom layout table
			-- see https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#%EF%B8%8F-layouts
			layout = "default",
			icons = {
				project = "",
				session = "󰑏",
				branch = "",
			},
			hl = {
				base_dir = "SnacksPickerDir",
				project_dir = "Directory",
				session = "SnacksPickerBold",
				branch = "SnacksPickerGitBranch",
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
		local cwd = vim.fn.getcwd()
		local project = cwd:gsub("[\\/:]+", "%%")
		if M.config.branch_scope and utils.is_repo(cwd) then
			picker_options.preview = function(ctx)
				pickers.git_preview(cwd, ctx)
			end
			pickers[default_picker]("branches", project, picker_options, { repo = true })
			return
		end
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
	local s
	if opts and opts.latest then
		s = state.load()
		if not s then
			return
		end
		project, session, branch = s.project, s.session, s.branch
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

	utils.load_session(path, project, M.config.preserve, branch or nil)
	M.active_session = true

	state.save(project, session, (branch and M.config.branch_scope) and branch or nil)

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

			local session_path = vim.fs.joinpath(session_dir, s.project, s.branch or "", s.session)
			utils.save_session(session_path, M.config.preserve)

			if M.config.notify then
				vim.notify("Saved session as: " .. s.session, vim.log.levels.INFO)
			end
			return
		end
	end

	local cwd = vim.fn.getcwd()
	local sanitized_dir = vim.fn.getcwd():gsub("[\\/:]+", "%%")
	local project_dir = vim.fs.joinpath(session_dir, sanitized_dir)

	if not uv.fs_stat(project_dir) then
		vim.fn.mkdir(project_dir, "p")
	end

	vim.ui.input({ prompt = "Session name:" }, function(name)
		if not name or name == "" then
			vim.notify("Session save cancelled", vim.log.levels.WARN)
			return
		end

		local branch = (utils.is_repo(cwd) and M.config.branch_scope) and utils.current_branch(cwd) or nil
		local session_path = vim.fs.joinpath(project_dir, branch or "", name)
		vim.fn.mkdir(session_path, "p")

		utils.save_session(session_path, M.config.preserve)
		state.save(sanitized_dir, name, branch)

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
	utils.branch_scope = M.config.branch_scope
end

return M
