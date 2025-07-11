local M = {}
M.branch_scope = false
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
				return opts.icons.project .. " " .. path
			end,
		}, function(choice)
			if not choice or choice == "" then
				return
			end
			if opts.delete_project then
				require("multi-session").delete_project(choice)
				return
			end
			local path = choice:gsub("%%", "/")
			if M.branch_scope and utils.is_repo(path) then
				git = { repo = true }
				M.vim("branches", choice, opts, git)
			else
				M.vim("sessions", choice, opts)
			end
		end)
	elseif type == "branches" then
		vim.ui.select(utils.branch_list(project), {
			prompt = "Select branch",
			format_item = function(item)
				return opts.icons.session .. " " .. item
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
				return opts.icons.session .. " " .. item
			end,
		}, function(choice)
			if not choice or choice == "" then
				return
			end
			if opts.delete then
				require("multi-session").delete(project, choice, git and git.branch or nil)
				return
			end
			if opts.rename then
				if git and git.branch then
					local s = "/" .. git.branch
					if project:sub(-#s) == s then
						project = project:sub(1, -#s - 1)
					end
				end
				require("multi-session").rename(project, choice, git and git.branch or nil)
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
					{ opts.icons.project .. " " .. dir .. "/", opts.hl.base_dir },
					{ base, opts.hl.project_dir },
				}
			elseif type == "branches" then
				return { { opts.icons.branch .. " " .. item.text, opts.hl.branch } }
			else
				local name = item.text:gsub("%.vim", "")
				return { { opts.icons.session .. " " .. name, opts.hl.session } }
			end
		end,
		layout = opts.layout,
		preview = opts.preview or "directory",
		confirm = function(picker, item)
			picker:close()
			if type == "projects" then
				if opts.delete_project then
					require("multi-session").delete_project(item.text)
					return
				end
				local path = item.text:gsub("%%", "/")
				if M.branch_scope and utils.is_repo(path) then
					git = { repo = true }
					opts.preview = function(ctx)
						M.git_preview(path, ctx)
					end
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
				if opts.delete then
					require("multi-session").delete(project, item.text, git and git.branch or nil)
					return
				end
				if opts.rename then
					if git and git.branch then
						local s = "/" .. git.branch
						if project:sub(-#s) == s then
							project = project:sub(1, -#s - 1)
						end
					end
					require("multi-session").rename(project, item.text, git and git.branch or nil)
					return
				end
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
				require("multi-session").load(nil, project, item.text, git.branch)
			end
		end,
	})
end

-- rework of the builtin git_log preview for snacks picker
-- allows showing logs from any repo regaurdless of cwd
---@param path string
---@param ctx table
M.git_preview = function(path, ctx)
	local ns = vim.api.nvim_create_namespace("snacks.picker.preview")
	local cmd = {
		"git",
		"-C",
		path,
		"--no-pager",
		"log",
		"--pretty=format:%h %s (%ch)",
		"--abbrev-commit",
		"--decorate",
		"--date=short",
		"--color=never",
		"--no-show-signature",
		"--no-patch",
		ctx.item.commit,
	}
	local row = 0
	require("snacks.picker.preview").cmd(cmd, ctx, {
		ft = "git",
		add = function(text)
			local commit, msg, date = text:match("^(%S+) (.*) %((.*)%)$")
			if commit then
				row = row + 1
				local hl = require("snacks.picker.format").git_log({
					idx = 1,
					score = 0,
					text = "",
					commit = commit,
					msg = msg,
					date = date,
				}, ctx.picker)
				vim.api.nvim_buf_set_lines(ctx.buf, row - 1, row, false, { text })
				require("snacks.picker.util.highlight").set(ctx.buf, ns, row, hl)
			end
		end,
	})
end

return M
