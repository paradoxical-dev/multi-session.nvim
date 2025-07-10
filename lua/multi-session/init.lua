local M = {}

local session_dir = vim.fn.stdpath("state") .. "/multi-session"

local uv = vim.uv or vim.loop

M.config = {}

---@param type string
---@param project? string
M.snacks_picker = function(type, project)
	local snacks = require("snacks")
	local items = {}

	local options = {}
	if type == "projects" then
		options = M.project_list()
	elseif type == "sessions" then
		options = M.session_list(project)
	else
		return vim.notify("Invalid type in snacks picker", vim.log.levels.ERROR)
	end

	for i, v in ipairs(options) do
		table.insert(items, { text = v })
	end

	snacks.picker({
		items = items,
		format = function(item)
			return { { item.text, "SnacksPickerBold" } }
		end,
		confirm = function(picker, item)
			picker:close()
			if type == "projects" then
				M.snacks_picker("sessions", item.text)
			else
				-- print(project, item.text)
				M.load(project, item.text)
			end
		end,
	})
end

---@return string[]
M.project_list = function()
	local dirs = {}
	local fd = uv.fs_scandir(session_dir)
	if not fd then
		return dirs
	end
	while true do
		local name, type = uv.fs_scandir_next(fd)
		if not name then
			break
		end

		if type == "directory" then
			table.insert(dirs, name)
		end
	end
	return dirs
end

---@param project string
---@return string[]
M.session_list = function(project)
	local files = {}
	local fd = uv.fs_scandir(session_dir .. "/" .. project)
	if not fd then
		return files
	end
	while true do
		local name, type = uv.fs_scandir_next(fd)
		if not name then
			break
		end
		if type == "file" then
			table.insert(files, name)
		end
	end
	return files
end

---@param project string
---@return string
M.pick_session = function(project)
	local co = coroutine.running()
	vim.ui.select(M.session_list(project), { prompt = "Select session" }, function(choice)
		coroutine.resume(co, choice)
	end)
	return coroutine.yield()
end

---@return string
M.pick_project = function()
	local co = coroutine.running()
	vim.ui.select(M.project_list(), { prompt = "Select project" }, function(choice)
		coroutine.resume(co, choice)
	end)
	return coroutine.yield()
end

M.select = function()
	coroutine.wrap(function()
		if M.config.picker == "snacks" then
			M.snacks_picker("projects")
		else
			local project = M.pick_project()
			local session = M.pick_session(project)
			M.load(project, session)
		end
	end)()
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
