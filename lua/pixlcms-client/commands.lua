local api = require("pixlcms-client.api")
local ui = require("pixlcms-client.ui")
local fzf = require("fzf-lua")
local config = require("pixlcms-client.config")
local util = require("pixlcms-client.util")

local M = {}

function M.show_nav()
    local nav_data = api.load_cached_nav()
    if not nav_data then
        vim.notify("No cached nav, fetching from API", vim.log.levels.INFO)
        api.fetch_nav(function(data)
            M.show_nav_with_data(data)
        end)
    else
        M.show_nav_with_data(nav_data)
    end
end

function M.force_refresh_nav()
    api.fetch_nav(function()
        vim.notify("Navigation updated from API", vim.log.levels.INFO)
    end)
end


function M.show_nav_with_data(nav_data)
    local flat_nav = util.flatten_nav(nav_data, nil, false)
    local entries = vim.tbl_map(function (entry) return entry.id end, flat_nav)

    local function get_selected_entry(selected)
        return vim.tbl_filter(function (e) return e.id == selected[1] end, flat_nav)[1]
    end

    local function open_entry(selected, mode)
        if selected then
            local entry = get_selected_entry(selected)['id']
            if entry then
                if mode == "default" then ui.open_entry(entry) end
                if mode == "vertical" then ui.open_entry_in_split(entry, "v") end
                if mode == "popup" then ui.open_entry_in_popup(entry) end
                if mode == "current" then ui.open_entry_in_current(entry) end
            end
        end
    end

    fzf.fzf_exec(entries, {
        prompt = config.opts.endpoint .. " > ",
        actions = {
            ["default"] = function (selected)
                open_entry(selected, 'default')
            end,
            ["ctrl-v"] = function(selected)
                open_entry(selected, "vertical")
            end,
            ["ctrl-o"] = function(selected)
                open_entry(selected, "current")
            end,
            ["ctrl-p"] = function(selected)
                open_entry(selected, "popup")
            end,
        },
    })
end

function M.create_entry()
    local options = util.flatten_nav(api.load_cached_nav(), nil, true)
    local entries = vim.tbl_map(function (entry) return entry.id end, options)
    vim.ui.select(entries, {}, function(selected)
        local title = vim.fn.input({
            prompt = "Title > ",
        })
        if title ~= '' and title ~= nil then
            api.create_entry(selected, title, function(data)
                api.fetch_nav()
                vim.print(data)
            end)
        end
    end)
end

local function get_project_key()
    return vim.fn.getcwd()
end

local function load_links()
    local f = io.open(config.opts.project_links, "r")
    if f then
        local content = f:read("*a")
        f:close()
        return vim.fn.json_decode(content) or {}
    else
        return {}
    end
end

local function save_links(links)
    local f = io.open(config.opts.project_links, "w")
    if f then
        f:write(vim.fn.json_encode(links))
        f:close()
    else
        vim.notify("Failed to save project links!", vim.log.levels.ERROR)
    end
end

function M.open_project_entry()
    local project_key = get_project_key()
    local links = load_links()
    local entry_id = links[project_key]

    if entry_id then
        ui.open_entry(entry_id)
    else
        M.link_project_entry()
    end
end

function M.link_project_entry()
    local nav_data = api.load_cached_nav() or api.fetch_nav(function(data) return data end)
    local flat_nav = util.flatten_nav(nav_data)
    local entries = vim.tbl_map(function(entry) return entry.title end, flat_nav)

    fzf.fzf_exec(entries, {
        prompt = "Link Entry to Project > ",
        actions = {
            ["default"] = function(selected)
                local entry = vim.tbl_filter(function(e) return e.title == selected[1] end, flat_nav)[1]
                if entry then
                    local project_key = get_project_key()
                    local links = load_links()
                    links[project_key] = entry.id
                    save_links(links)
                    vim.notify("Linked entry '" .. entry.title .."' to the Project")
                    M.open_project_entry()
                end
            end
        }
    })
end

function M.journal_current()
    api.current(function (id)
        api.fetch_nav()
        ui.open_entry(id)
    end)
end

vim.api.nvim_create_augroup("PixlCMS", {})

vim.api.nvim_create_autocmd("BufWriteCmd", {
    group = "PixlCMS",
    pattern = "pw://*",
    callback = function ()
        local current_buf = vim.api.nvim_get_current_buf()
        local entry_id = vim.api.nvim_buf_get_name(current_buf)
        entry_id = entry_id:gsub("pw://", "")
        local new_content = table.concat(vim.api.nvim_buf_get_lines(current_buf, 0, -1, false), "\n")
        api.save_page(entry_id, new_content)
        vim.bo.modified = false
    end
})

vim.api.nvim_create_autocmd("BufReadCmd", {
    pattern = "pw://*",
    group = "PixlCMS",
    callback = function ()
        local current_buf = vim.api.nvim_get_current_buf()
        local entry_id = vim.api.nvim_buf_get_name(current_buf)
        entry_id = entry_id:gsub("pw://", "")
        ui.open_entry(entry_id)
    end
})

function M.register_commands()
    local actions = {
        ["save"] = ui.save_current_buffer,
        ["nav"] = M.show_nav,
        ["nav_refresh"] = M.force_refresh_nav,
        ["create"] = M.create_entry,
        ["project_entry"] = M.open_project_entry,
        ["project_link_entry"] = M.link_project_entry,
        ["close_popup"] = ui.close_popup,
        ["select_endpoint"] = ui.select_endpoint,
        ["journal_current"] = M.journal_current,
    }
    vim.api.nvim_create_user_command(
        "PixlCms",
        function (opts)
            actions[opts.args]()
        end,
        {
            nargs = '?',
            complete = function (cmd)
                vim.print(cmd)
                local keyset={}
                local n=0

                for k, _ in pairs(actions) do
                    if cmd == "" or string.sub(k, 1, string.len(cmd)) == cmd then
                        n=n+1
                        keyset[n]=k
                    end
                end
                table.sort(keyset)
                return keyset
            end,
        })
end

return M
