if vim.g.loaded_fleet then
    return
end
vim.g.loaded_fleet = true

vim.api.nvim_create_user_command('FleetInfo', function()
    require('fleet').project_info()
end, { desc = "Show Fleet project information" })

vim.api.nvim_create_user_command('FleetProjectInfo', function()
    local fleet = require('fleet')
    if vim.fn.exists(':FleetProjectInfo') == 2 then
        vim.cmd('FleetProjectInfo')
    else
        local project_root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub("%s+$", "")
        if project_root == "" or vim.v.shell_error ~= 0 then
            project_root = vim.fn.getcwd()
        end
        vim.notify("Fleet Project Root: " .. project_root, vim.log.levels.INFO)
    end
end, { desc = "Show detailed Fleet project information" })

vim.api.nvim_create_user_command('FleetListFiles', function()
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
end, { desc = "List all Fleet list files" })

vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
        local ok, _ = pcall(require, "harpoon")
        if ok then
            if not vim.g.fleet_setup_called then
                require('fleet').setup({})
            end
        end
    end,
    desc = "Auto-initialize Fleet if Harpoon is available"
})
