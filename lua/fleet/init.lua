local M = {}

local default_config = {
    debug_mode = false,
    auto_save = true,
    keymaps = {
        toggle_menu = "<leader>ho",
        add_file = "<leader>a",
        new_list = "<leader>hn",
        remove_file = "<leader>hx",
        clear_list = "<leader>hc",
        save_list = "<leader>hs",
        load_list = "<leader>hl",
        delete_list = "<leader>hd",
        rename_list = "<leader>hr",
        where_am_i = "<leader>hw",
        nav_file_1 = "<leader>j",
        nav_file_2 = "<leader>k",
        nav_file_3 = "<leader>l",
        nav_file_4 = "<leader>;",
        nav_file_5 = "<leader>5",
        nav_next = "<S-j>",
        nav_prev = "<S-k>",
    },
    lualine_component = true,
}

local state = {
    config = {},
    harpoon_state = {
        current_list_counter = 1,
        project_root_cache = nil,
        project_id_cache = nil,
        project_lists_cache = nil,
    },
    status_update_timer = nil,
}

local function debug_log(msg)
    if state.config.debug_mode then
        vim.notify("Fleet debug: " .. msg)
    end
end

local function normalize_path(path)
    return path:gsub("[ %-]", "_")
end

local function parse_list_name(name)
    local folder_part, list_part = name:match("^(.+):(.+)$")
    if folder_part and list_part then
        return folder_part, list_part
    else
        return name, nil
    end
end

local function format_list_name(folder, list)
    if list then
        return folder .. ":" .. list
    else
        return folder
    end
end

local function get_project_root()
    if state.harpoon_state.project_root_cache then
        return state.harpoon_state.project_root_cache
    end

    debug_log("Detecting project root")

    local git_root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub("%s+$", "")
    if git_root ~= "" and vim.v.shell_error == 0 then
        git_root = normalize_path(git_root)
        state.harpoon_state.project_root_cache = git_root
        debug_log("Found git root: " .. git_root)
        return git_root
    end

    local cwd = vim.fn.getcwd()
    cwd = normalize_path(cwd)
    state.harpoon_state.project_root_cache = cwd
    debug_log("Using cwd as root: " .. cwd)
    return state.harpoon_state.project_root_cache
end

local function get_project_id()
    if state.harpoon_state.project_id_cache then
        return state.harpoon_state.project_id_cache
    end

    local project_path = get_project_root()
    local project_name = nil

    local git_origin = vim.fn.system("git config --get remote.origin.url 2>/dev/null"):gsub("%s+$", "")
    if git_origin ~= "" and vim.v.shell_error == 0 then
        project_name = git_origin:match("([^/]+)%.git$") or git_origin:match("[^/]+$")
        debug_log("Got project name from git origin: " .. (project_name or "nil"))
    end

    if not project_name or project_name == "" then
        project_name = vim.fn.fnamemodify(project_path, ":t")
        debug_log("Using root directory name: " .. project_name)
    end

    project_name = normalize_path(project_name)
    state.harpoon_state.project_id_cache = project_name
    debug_log("Final project ID: " .. project_name)
    return project_name
end

local function get_workspace_context()
    local project_root = get_project_root()
    local current_dir = vim.fn.getcwd()

    if current_dir == project_root then
        return nil
    end

    local relative_path = vim.fn.fnamemodify(current_dir, ":.")
    if current_dir:find(project_root, 1, true) == 1 then
        relative_path = current_dir:sub(#project_root + 2) -- +2 to skip the trailing slash
    end

    return relative_path:match("([^/]+)")
end

local function get_default_list_name()
    local project_id = get_project_id()
    local context = get_workspace_context()

    if context then
        return project_id .. ":" .. context
    else
        return project_id
    end
end

local function save_harpoon_list(name)
    debug_log("Saving list: " .. name)

    local harpoon_module = require("harpoon")
    local marks = harpoon_module.get_mark_config().marks

    local save_dir = vim.fn.stdpath("data") .. "/fleet_lists"
    if vim.fn.isdirectory(save_dir) == 0 then
        vim.fn.mkdir(save_dir, "p")
    end

    name = normalize_path(name)
    local folder_part, list_part = parse_list_name(name)
    local project_id = get_project_id()

    if not list_part then
        if folder_part ~= project_id then
            list_part = folder_part
            folder_part = project_id
            name = format_list_name(folder_part, list_part)
        else
            name = folder_part
        end
    else
        if folder_part ~= project_id then
            folder_part = project_id
            name = format_list_name(folder_part, list_part)
        end
    end

    local file_name = name
    local display_name = list_part or folder_part
    local file_path = save_dir .. "/" .. file_name .. ".json"

    debug_log("Saving to path: " .. file_path)

    local file = io.open(file_path, "w")
    if file then
        file:write(vim.fn.json_encode(marks))
        file:close()

        _G.active_harpoon_list = name
        state.harpoon_state.project_lists_cache = nil
        vim.defer_fn(function() vim.cmd("redrawstatus") end, 1)

        return true, project_id, display_name
    end
    return false, nil, nil
end

local function load_harpoon_list(full_name, display_name)
    debug_log("Loading list: " .. full_name)

    full_name = normalize_path(full_name)
    local file_path = vim.fn.stdpath("data") .. "/fleet_lists/" .. full_name .. ".json"

    debug_log("Looking for file at: " .. file_path)

    local file = io.open(file_path, "r")
    if file then
        local content = file:read("*a")
        file:close()

        local mark = require("harpoon.mark")
        mark.clear_all()

        local marks = vim.fn.json_decode(content)
        for _, file_info in ipairs(marks) do
            mark.add_file(file_info.filename)
        end

        _G.active_harpoon_list = full_name
        vim.defer_fn(function() vim.cmd("redrawstatus") end, 1)

        return true
    else
        debug_log("Failed to open file: " .. file_path)
    end
    return false
end

local function delete_harpoon_list(full_name)
    debug_log("Deleting list: " .. full_name)

    full_name = normalize_path(full_name)
    local file_path = vim.fn.stdpath("data") .. "/fleet_lists/" .. full_name .. ".json"
    local result = os.remove(file_path)

    if _G.active_harpoon_list == full_name then
        _G.active_harpoon_list = nil
        vim.defer_fn(function() vim.cmd("redrawstatus") end, 1)
    end

    state.harpoon_state.project_lists_cache = nil
    return result ~= nil
end

local function get_project_lists()
    if state.harpoon_state.project_lists_cache then
        return state.harpoon_state.project_lists_cache
    end

    debug_log("Scanning for project lists")
    local project_id = get_project_id()
    local save_dir = vim.fn.stdpath("data") .. "/fleet_lists"

    if vim.fn.isdirectory(save_dir) == 0 then
        state.harpoon_state.project_lists_cache = {}
        return {}
    end

    local files = vim.fn.readdir(save_dir)
    local lists = {}

    debug_log("Project ID: " .. project_id)
    debug_log("Found " .. #files .. " files in fleet_lists directory")

    for _, file in ipairs(files) do
        if file:match("%.json$") then
            local list_name = file:gsub("%.json$", "")
            list_name = normalize_path(list_name)

            if list_name == project_id or list_name:match("^" .. project_id .. ":") then
                local display_name = list_name:gsub("^" .. project_id .. ":", "")
                if display_name == "" then
                    display_name = "main"
                end
                table.insert(lists, {
                    full_name = list_name,
                    display_name = display_name
                })
            end
        end
    end

    table.sort(lists, function(a, b)
        local a_num = tonumber(a.display_name:match("^(%d+)$"))
        local b_num = tonumber(b.display_name:match("^(%d+)$"))

        if a_num and b_num then
            return a_num < b_num
        elseif a_num then
            return true
        elseif b_num then
            return false
        else
            return a.display_name < b.display_name
        end
    end)

    state.harpoon_state.project_lists_cache = lists
    return lists
end

local function find_highest_list_number()
    local lists = get_project_lists()
    local highest = 0

    for _, list in ipairs(lists) do
        local num = tonumber(list.display_name:match("_?(%d+)$"))
        if num and num > highest then
            highest = num
        end
    end

    return highest
end

local function initialize_default_list()
    debug_log("Initializing default list")
    local project_lists = get_project_lists()
    local context = get_workspace_context()

    if #project_lists == 0 then
        state.harpoon_state.current_list_counter = 1
        _G.active_harpoon_list = nil
        return
    end

    state.harpoon_state.current_list_counter = find_highest_list_number()

    if context then
        local context_list_name = get_project_id() .. ":" .. context
        for _, list in ipairs(project_lists) do
            if list.full_name == context_list_name then
                debug_log("Loading context-specific list: " .. context_list_name)
                load_harpoon_list(list.full_name)
                return
            end
        end
    end

    if #project_lists > 0 then
        debug_log("Loading first available list: " .. project_lists[1].full_name)
        load_harpoon_list(project_lists[1].full_name)
    end
end

local function prompt_for_list_name(default_name)
    local list_name = vim.fn.input("Enter list name (default: " .. default_name .. "): ")
    if list_name == "" then
        return default_name
    else
        return normalize_path(list_name)
    end
end

local function setup_keymaps()
    local mark = require("harpoon.mark")
    local ui = require("harpoon.ui")
    local config = state.config

    vim.keymap.set("n", config.keymaps.toggle_menu, function()
        local original_get_menu_items = ui._get_menu_items
        local original_menu_builder = ui.menu_builder

        local custom_title = "Fleet"
        if _G.active_harpoon_list then
            local list_part = _G.active_harpoon_list:match(":(.+)$")
            local display_name = list_part or _G.active_harpoon_list
            custom_title = "Fleet: " .. display_name
        end

        ui.menu_builder = function(items)
            local menu = original_menu_builder(items)
            menu.title = custom_title
            return menu
        end

        ui.toggle_quick_menu()

        ui.menu_builder = original_menu_builder
        ui._get_menu_items = original_get_menu_items
    end, { desc = "Open Fleet Menu with List Name" })

    vim.keymap.set("n", config.keymaps.add_file, function()
        local fileName = vim.fn.expand("%:t")
        mark.add_file()

        if not _G.active_harpoon_list then
            local default_list_name = get_default_list_name()
            local list_name = prompt_for_list_name(default_list_name)

            local success, _, display_name = save_harpoon_list(list_name)
            if success then
                vim.notify(fileName .. " added to new list '" .. display_name .. "'")
            else
                vim.notify("Failed to create list", vim.log.levels.ERROR)
            end
        else
            save_harpoon_list(_G.active_harpoon_list)
            local _, list_part = parse_list_name(_G.active_harpoon_list)
            local display_name = list_part or _G.active_harpoon_list
            vim.notify(fileName .. " added to list '" .. display_name .. "'")
        end
    end, { desc = "Add File to Current Fleet List" })

    vim.keymap.set("n", config.keymaps.new_list, function()
        mark.clear_all()
        local project_id = get_project_id()
        local context = get_workspace_context()
        local highest_num = find_highest_list_number()
        local next_num = highest_num + 1

        state.harpoon_state.current_list_counter = next_num

        local default_suggestions = {}
        if context then
            table.insert(default_suggestions, "Use context name: " .. context .. "_list_" .. next_num)
            table.insert(default_suggestions, "Use simple context: " .. context)
        end
        table.insert(default_suggestions, "Use default name: list_" .. next_num)
        table.insert(default_suggestions, "Choose custom name")

        vim.ui.select(default_suggestions, {
            prompt = "New empty list name:",
        }, function(choice)
            if not choice then return end

            local list_name
            if choice:match("Use context name:") then
                list_name = context .. "_list_" .. next_num
            elseif choice:match("Use simple context:") then
                list_name = context
            elseif choice:match("Use default") then
                list_name = "list_" .. next_num
            elseif choice:match("Choose custom") then
                local custom_name = vim.fn.input("Enter custom list name: ")
                if custom_name ~= "" then
                    list_name = normalize_path(custom_name)
                else
                    vim.notify("Operation cancelled - no name provided", vim.log.levels.WARN)
                    return
                end
            end

            if list_name then
                local full_name = format_list_name(project_id, list_name)
                local success, _, display_name = save_harpoon_list(full_name)
                if success then
                    vim.notify("Created new empty list '" .. display_name .. "'")
                else
                    vim.notify("Failed to create new list", vim.log.levels.ERROR)
                end
            end
        end)
    end, { desc = "Create New Empty Fleet List" })

    vim.keymap.set("n", config.keymaps.remove_file, function()
        local fileName = vim.fn.expand("%:t")
        mark.rm_file()
        vim.notify(fileName .. " removed from Fleet")

        if _G.active_harpoon_list then
            save_harpoon_list(_G.active_harpoon_list)
        end
    end, { desc = "Remove File from Fleet" })

    vim.keymap.set("n", config.keymaps.clear_list, function()
        mark.clear_all()
        vim.notify("Fleet list cleared")

        if _G.active_harpoon_list then
            vim.ui.select({ "Yes", "No" }, {
                prompt = "Save the cleared list?",
            }, function(choice)
                if choice == "Yes" then
                    save_harpoon_list(_G.active_harpoon_list)
                    local _, display_name = parse_list_name(_G.active_harpoon_list)
                    display_name = display_name or _G.active_harpoon_list
                    vim.notify("Saved empty list '" .. display_name .. "'")
                end
            end)
        end
    end, { desc = "Clear Fleet List" })

    vim.keymap.set("n", config.keymaps.nav_file_1, function() ui.nav_file(1) end, { desc = "Fleet File 1" })
    vim.keymap.set("n", config.keymaps.nav_file_2, function() ui.nav_file(2) end, { desc = "Fleet File 2" })
    vim.keymap.set("n", config.keymaps.nav_file_3, function() ui.nav_file(3) end, { desc = "Fleet File 3" })
    vim.keymap.set("n", config.keymaps.nav_file_4, function() ui.nav_file(4) end, { desc = "Fleet File 4" })
    vim.keymap.set("n", config.keymaps.nav_file_5, function() ui.nav_file(5) end, { desc = "Fleet File 5" })

    vim.keymap.set("n", config.keymaps.nav_next, function()
        ui.nav_next()
    end, { desc = "Next Fleet File" })

    vim.keymap.set("n", config.keymaps.nav_prev, function()
        ui.nav_prev()
    end, { desc = "Previous Fleet File" })

    vim.keymap.set("n", config.keymaps.where_am_i, function()
        local current_file = vim.fn.expand("%:p")
        local marks = require("harpoon").get_mark_config().marks

        for idx, file in ipairs(marks) do
            if file.filename == current_file then
                local display_name
                if _G.active_harpoon_list then
                    local _, list_part = parse_list_name(_G.active_harpoon_list)
                    display_name = list_part or _G.active_harpoon_list
                else
                    display_name = "unnamed"
                end

                vim.notify("Current file is #" .. idx .. " in Fleet list '" .. display_name .. "'")
                return
            end
        end
        vim.notify("Current file is not in Fleet")
    end, { desc = "Where in Fleet?" })

    vim.keymap.set("n", config.keymaps.rename_list, function()
        if not _G.active_harpoon_list then
            vim.notify("No active list to rename", vim.log.levels.WARN)
            return
        end

        local folder_part, list_part = parse_list_name(_G.active_harpoon_list)
        local current_name = list_part or folder_part

        local new_name = vim.fn.input("Rename list '" .. current_name .. "' to: ")

        if new_name ~= "" then
            new_name = normalize_path(new_name)

            local new_full_name
            if folder_part == get_project_id() then
                new_full_name = format_list_name(folder_part, new_name)
            else
                new_full_name = format_list_name(get_project_id(), new_name)
            end

            local old_file_path = vim.fn.stdpath("data") .. "/fleet_lists/" .. _G.active_harpoon_list .. ".json"
            local file = io.open(old_file_path, "r")
            local content = nil

            if file then
                content = file:read("*a")
                file:close()
            end

            delete_harpoon_list(_G.active_harpoon_list)

            if content then
                local new_file_path = vim.fn.stdpath("data") .. "/fleet_lists/" .. new_full_name .. ".json"
                local new_file = io.open(new_file_path, "w")

                if new_file then
                    new_file:write(content)
                    new_file:close()

                    _G.active_harpoon_list = new_full_name
                    state.harpoon_state.project_lists_cache = nil

                    vim.notify("Renamed list to '" .. new_name .. "'")
                else
                    vim.notify("Failed to create new list file", vim.log.levels.ERROR)
                end
            else
                save_harpoon_list(new_full_name)
                vim.notify("Renamed list to '" .. new_name .. "' (no content transferred)")
            end
        end
    end, { desc = "Rename Current Fleet List" })

    vim.keymap.set("n", config.keymaps.save_list, function()
        if not _G.active_harpoon_list then
            local default_list_name = get_default_list_name()
            local list_name = vim.fn.input("Save Fleet list as (default: " .. default_list_name .. "): ")

            if list_name == "" then
                list_name = default_list_name
            else
                list_name = normalize_path(list_name)
            end

            local success, project_id, display_name = save_harpoon_list(list_name)
            if success then
                vim.notify("Fleet list saved as '" .. display_name .. "' for project '" .. project_id .. "'")
            else
                vim.notify("Failed to save Fleet list", vim.log.levels.ERROR)
            end
        else
            local _, list_part = parse_list_name(_G.active_harpoon_list)
            local current_name = list_part or _G.active_harpoon_list

            vim.ui.select({ "Save to current list: " .. current_name, "Save as new list" }, {
                prompt = "Save options:",
            }, function(choice)
                if choice and choice:match("Save to current") then
                    local success = save_harpoon_list(_G.active_harpoon_list)
                    if success then
                        vim.notify("Saved changes to list '" .. current_name .. "'")
                    else
                        vim.notify("Failed to save Fleet list", vim.log.levels.ERROR)
                    end
                elseif choice and choice:match("Save as new") then
                    local new_name = vim.fn.input("Save Fleet list as: ")
                    if new_name ~= "" then
                        new_name = normalize_path(new_name)
                        local project_id = get_project_id()
                        local full_name = format_list_name(project_id, new_name)

                        local success, _, display_name = save_harpoon_list(full_name)
                        if success then
                            vim.notify("Fleet list saved as '" .. display_name .. "' for project '" .. project_id .. "'")
                        else
                            vim.notify("Failed to save Fleet list", vim.log.levels.ERROR)
                        end
                    end
                end
            end)
        end
    end, { desc = "Save Fleet List" })

    vim.keymap.set("n", config.keymaps.load_list, function()
        local project_lists = get_project_lists()

        if #project_lists == 0 then
            vim.notify("No saved Fleet lists found for this project", vim.log.levels.WARN)
            return
        end

        local display_names = {}
        for i, list_info in ipairs(project_lists) do
            display_names[i] = list_info.display_name
        end

        vim.ui.select(display_names, {
            prompt = "Select Fleet list to load:",
        }, function(choice, idx)
            if choice and idx then
                if load_harpoon_list(project_lists[idx].full_name) then
                    vim.notify("Loaded Fleet list '" .. choice .. "'")
                else
                    vim.notify("Failed to load Fleet list", vim.log.levels.ERROR)
                end
            end
        end)
    end, { desc = "Load Fleet List" })

    vim.keymap.set("n", config.keymaps.delete_list, function()
        local project_lists = get_project_lists()

        if #project_lists == 0 then
            vim.notify("No saved Fleet lists found for this project", vim.log.levels.WARN)
            return
        end

        local display_names = {}
        for i, list_info in ipairs(project_lists) do
            display_names[i] = list_info.display_name
        end

        vim.ui.select(display_names, {
            prompt = "Select Fleet list to delete:",
        }, function(choice, idx)
            if choice and idx then
                vim.ui.select({ "Yes", "No" }, {
                    prompt = "Are you sure you want to delete '" .. choice .. "'?",
                }, function(confirm)
                    if confirm == "Yes" then
                        if delete_harpoon_list(project_lists[idx].full_name) then
                            vim.notify("Deleted Fleet list '" .. choice .. "'", vim.log.levels.WARN)
                        else
                            vim.notify("Failed to delete Fleet list", vim.log.levels.ERROR)
                        end
                    end
                end)
            end
        end)
    end, { desc = "Delete Fleet List" })
end

local function setup_status_update()
    if state.status_update_timer then
        state.status_update_timer:stop()
        state.status_update_timer:close()
    end

    state.status_update_timer = vim.loop.new_timer()
    state.status_update_timer:start(1000, 5000, vim.schedule_wrap(function()
        if _G.active_harpoon_list then
            local harpoon_module = require("harpoon")
            local marks = harpoon_module.get_mark_config().marks
            local count = #marks

            _G.active_harpoon_list = _G.active_harpoon_list
            vim.cmd("redrawstatus")
        end
    end))
end

local function setup_commands()
    vim.api.nvim_create_user_command("FleetProjectInfo", function()
        local project_root = get_project_root()
        local project_id = get_project_id()
        local context = get_workspace_context()
        local lists = get_project_lists()
        local lists_str = ""

        for i, list in ipairs(lists) do
            lists_str = lists_str .. "\n  " .. i .. ". " .. list.display_name .. " (full: " .. list.full_name .. ")"
        end

        local info = "Fleet Project Info:\n" ..
            "Project Root: " .. project_root .. "\n" ..
            "Project ID: " .. project_id .. "\n" ..
            "Workspace Context: " .. (context or "none") .. "\n" ..
            "Active List: " .. (_G.active_harpoon_list or "none") .. "\n" ..
            "Available Lists:" .. (lists_str ~= "" and lists_str or " none")

        vim.notify(info, vim.log.levels.INFO, { title = "Fleet Debug" })
    end, {})

    vim.api.nvim_create_user_command("FleetListFiles", function()
        local save_dir = vim.fn.stdpath("data") .. "/fleet_lists"
        if vim.fn.isdirectory(save_dir) == 0 then
            vim.notify("Fleet lists directory does not exist", vim.log.levels.WARN)
            return
        end

        local files = vim.fn.readdir(save_dir)
        local file_list = "Fleet list files in " .. save_dir .. ":\n"

        for i, file in ipairs(files) do
            file_list = file_list .. "  " .. i .. ". " .. file .. "\n"
        end

        vim.notify(file_list, vim.log.levels.INFO, { title = "Fleet Files" })
    end, {})
end

local function setup_autocmds()
    vim.api.nvim_create_autocmd({ "BufEnter" }, {
        callback = function()
            local current_dir = vim.fn.getcwd()
            if state.harpoon_state.last_cwd ~= current_dir then
                state.harpoon_state.last_cwd = current_dir
                state.harpoon_state.project_root_cache = nil
                state.harpoon_state.project_lists_cache = nil
            end
        end,
    })

    if state.config.auto_save then
        vim.api.nvim_create_autocmd({ "BufWritePost" }, {
            callback = function()
                if _G.active_harpoon_list then
                    save_harpoon_list(_G.active_harpoon_list)
                    debug_log("Auto-saved list: " .. _G.active_harpoon_list)
                end
            end,
        })
    end
end

local function get_fleet_status()
    if not _G.active_harpoon_list then
        return ""
    end

    local harpoon_module = require("harpoon")
    local marks = harpoon_module.get_mark_config().marks
    local count = #marks

    local _, list_part = parse_list_name(_G.active_harpoon_list)
    local display_name = list_part or _G.active_harpoon_list

    if count == 0 then
        return "Fleet: " .. display_name .. " (empty)"
    else
        return "Fleet: " .. display_name .. " (" .. count .. ")"
    end
end

function M.setup(opts)
    opts = opts or {}
    state.config = vim.tbl_deep_extend("force", default_config, opts)

    _G.active_harpoon_list = nil

    setup_keymaps()
    setup_commands()
    setup_autocmds()
    setup_status_update()

    vim.defer_fn(function()
        initialize_default_list()
    end, 100)

    debug_log("Fleet plugin initialized")
end

function M.get_status()
    return get_fleet_status()
end

function M.save_current_list(name)
    if name then
        return save_harpoon_list(name)
    elseif _G.active_harpoon_list then
        return save_harpoon_list(_G.active_harpoon_list)
    end
    return false
end

function M.load_list(name)
    return load_harpoon_list(name)
end

function M.get_project_lists()
    return get_project_lists()
end

function M.get_current_list()
    return _G.active_harpoon_list
end

return M
