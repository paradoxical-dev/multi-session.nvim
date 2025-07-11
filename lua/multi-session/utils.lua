local M = {}

local uv = vim.uv or vim.loop
M.session_dir = vim.fn.stdpath("state") .. "/multi-session"
M.branch_scope = false

-- SESSION --

---@param project string
---@return string[]
M.session_list = function(project)
	local sessions = {}
	local fd = uv.fs_scandir(M.session_dir .. "/" .. project)
	if not fd then
		return sessions
	end
	while true do
		local name, type = uv.fs_scandir_next(fd)
		if not name then
			break
		end
		if type == "directory" then
			table.insert(sessions, name)
		end
	end
	return sessions
end

---@return string[]
M.project_list = function()
	local dirs = {}
	local fd = uv.fs_scandir(M.session_dir)
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

---@param session_path string
---@param extras table
M.save_session = function(session_path, extras)
	local name = vim.fn.fnamemodify(session_path, ":t")
	local session_file = vim.fn.fnameescape(session_path .. "/" .. name .. ".vim")

	vim.cmd("mksession! " .. session_file)

	for k, v in pairs(extras) do
		if k == "breakpoints" and v == true then
			require("dap-utils").store_breakpoints(session_path .. "/breakpoints")
		end
		if k == "qflist" and v == true then
			require("quickfix").store(session_path .. "/quickfix")
		end
		if k == "undo" and v == true then
			vim.cmd("wundo " .. vim.fn.fnameescape(session_path) .. "/undo")
		end
		if k == "watches" and v == true then
			require("dap-utils").store_watches(session_path .. "/watches")
		end
	end
end

---@param session_path string
---@param project string
---@param extras table
---@param branch? string
M.load_session = function(session_path, project, extras, branch)
	local name = vim.fn.fnamemodify(session_path, ":t")
	local session_file = vim.fn.fnameescape(session_path .. "/" .. name .. ".vim")

	if branch and M.branch_scope then
		M.switch_branch(project, branch)
	end

	vim.cmd("source " .. session_file)

	for k, v in pairs(extras) do
		if k == "breakpoints" and v == true then
			require("dap-utils").restore_breakpoints(session_path .. "/breakpoints")
		end
		if k == "qflist" and v == true then
			require("quickfix").restore(session_path .. "/quickfix")
		end
		if k == "undo" and v == true then
			vim.cmd("rundo " .. vim.fn.fnameescape(session_path) .. "/undo")
		end
		if k == "watches" and v == true then
			require("dap-utils").restore_watches(session_path .. "/watches")
		end
	end
end

-- GIT --

---@param dir string
M.is_repo = function(dir)
	local handle = io.popen("git -C " .. vim.fn.shellescape(dir) .. " rev-parse --is-inside-work-tree 2>/dev/null")
	if handle then
		local result = handle:read("*a")
		handle:close()
		return result:match("true") ~= nil
	end
	return false
end

---@param dir string
M.current_branch = function(dir)
	local handle = io.popen("git -C " .. vim.fn.shellescape(dir) .. " rev-parse --abbrev-ref HEAD 2>/dev/null")
	if handle then
		local result = handle:read("*l") -- read one line
		handle:close()
		return result
	end
	return nil
end

---@param project string
M.branch_list = function(project)
	local branches = {}
	local fd = uv.fs_scandir(M.session_dir .. "/" .. project)
	if not fd then
		return branches
	end
	while true do
		local name, type = uv.fs_scandir_next(fd)
		if not name then
			break
		end
		if type == "directory" then
			table.insert(branches, name)
		end
	end
	return branches
end

---@param project string
---@param branch string
M.switch_branch = function(project, branch)
	local repo = project:gsub("%%", "/")
	vim.cmd("cd " .. repo)
	local current_branch = M.current_branch(repo)
	if branch ~= current_branch then
		vim.cmd("silent !git switch " .. branch)
	end
end

---@param dir string
---@param branch string
M.get_head = function(dir, branch)
	local cmd = "git -C " .. vim.fn.shellescape(dir) .. " rev-parse " .. vim.fn.shellescape(branch)
	local handle = io.popen(cmd)
	if not handle then
		return nil
	end

	local result = handle:read("*l")
	handle:close()

	if result and result:match("^%x+$") then
		return result
	end
	return nil
end

return M
