local M = {}
local utils = require("multi-session.utils")

local uv = vim.uv or vim.loop

---@param type string
---@param project string
---@param opts table
---@param git? table
M.vim = function(type, project, opts, git)
	if type == "projects" then
		vim.ui.select(utils.project_list(), {
			prompt = "Select project",
			format_item = function(item)
				local path = item:gsub("%%", "/")
				return opts.project_icon .. " " .. path
			end,
		}, function(choice)
			if not choice or choice == "" then
				return
			end
			if git and git.repo then
				M.vim("branches", choice, opts, git)
			else
				M.vim("sessions", choice, opts)
			end
		end)
	elseif type == "branches" then
		vim.ui.select(utils.branch_list(project), {
			prompt = "Select branch",
			format_item = function(item)
				return opts.session_icon .. " " .. item
			end,
		}, function(choice)
			if not choice or choice == "" then
				return
			end
			git.branch = choice
			project = project .. "/" .. choice
			M.vim("sessions", project, opts, git)
		end)
	elseif type == "sessions" then
		vim.ui.select(utils.session_list(project), {
			prompt = "Select session",
			format_item = function(item)
				return opts.session_icon .. " " .. item
			end,
		}, function(choice)
			if not choice or choice == "" then
				return
			end
			if not git then
				require("multi-session").load(nil, project, choice)
			else
				-- branch needs to be removed from the project name
				-- it was added in the branch picker and will be added back on
				-- from inside the `utils.load_session` function
				local s = "/" .. git.branch
				if project:sub(-#s) == s then
					project = project:sub(1, -#s - 1)
				end
				print(project)
				require("multi-session").load(nil, project, choice, git.branch)
			end
		end)
	else
		return vim.notify("Invalid type in default picker", vim.log.levels.ERROR)
	end
end

---@param type string
---@param project string
---@param opts table
---@param git? table
M.snacks = function(type, project, opts, git)
	local snacks = require("snacks")
	local items = {}

	local options = {}
	if type == "projects" then
		options = utils.project_list()
	elseif type == "sessions" then
		options = utils.session_list(project)
	elseif type == "branches" then
		options = utils.branch_list(project)
	else
		return vim.notify("Invalid type in snacks picker", vim.log.levels.ERROR)
	end

	for _, v in ipairs(options) do
		local path = ""
		local commit
		if type == "projects" then
			path = v:gsub("%%", "/")
		elseif type == "sessions" then
			path = utils.session_dir .. "/" .. project .. "/" .. v .. "/" .. v .. ".vim"
		else
			local repo_path = project:gsub("%%", "/")
			commit = utils.get_head(repo_path, v)
			-- if commit then
			-- 	commit = commit:sub(1, 7)
			-- end
		end
		table.insert(items, { text = v, file = path, commit = commit })
	end

	snacks.picker({
		items = items,
		format = function(item)
			if type == "projects" then
				local path = item.text:gsub("%%", "/")
				local base = vim.fn.fnamemodify(path, ":t")
				local dir = vim.fn.fnamemodify(path, ":h"):gsub(uv.os_getenv("HOME"), "~")
				return {
					{ opts.project_icon .. " " .. dir .. "/", opts.hl.base_dir },
					{ base, opts.hl.project_dir },
				}
			else
				local name = item.text:gsub("%.vim", "")
				return { { opts.session_icon .. " " .. name, opts.hl.session } }
			end
		end,
		layout = opts.layout,
		preview = opts.preview or "directory",
		confirm = function(picker, item)
			picker:close()
			if type == "projects" then
				if git and git.repo then
					opts.preview = "git_log"
					M.snacks("branches", item.text, opts, git)
				else
					opts.preview = "file"
					M.snacks("sessions", item.text, opts)
				end
			elseif type == "branches" then
				git.branch = item.text
				project = project .. "/" .. item.text
				opts.preview = "file"
				M.snacks("sessions", project, opts, git)
			else
				if not git then
					require("multi-session").load(nil, project, item.text)
					return
				end
				-- branch needs to be removed from the project name
				-- it was added in the branch picker and will be added back on
				-- from inside the `utils.load_session` function
				local s = "/" .. git.branch
				if project:sub(-#s) == s then
					project = project:sub(1, -#s - 1)
				end
				print(project)
				require("multi-session").load(nil, project, item.text, git.branch)
			end
		end,
	})
end

return M
