local api = require("pixlcms-client.api")
local ui = require("pixlcms-client.ui")
local fzf = require("fzf-lua")
local config = require("pixlcms-client.config")

local M = {}

local function flatten_nav(nav, parent, folders_only)
    local results = {}
    for _, item in ipairs(nav) do
        local path = parent and (parent .. " > " .. item.title) or item.title
        if item.kind and item.kind == 'board' then
        elseif item.isFolder then
            -- vim.print(item.children)
            -- print(#item.children)
            if folders_only then
                table.insert(results, { title = item.title, id = item.id })
            end
            -- print(#item.children, item.title)
            vim.list_extend(results, flatten_nav(item.children, path, folders_only))
        elseif not folders_only then
            table.insert(results, { title = path, id = item.id })
        end
    end

    return results
end

function M.show_nav()
    local nav_data = api.load_cached_nav()
    if not nav_data then
        vim.notify("No cached nav, fetching from API", vim.log.levels.ERROR)
        api.fetch_nav(function(data)
            M.show_nav_with_data(data)
        end)
    else
        M.show_nav_with_data(nav_data)
    end
end

function M.force_refresh_nav()
    api.fetch_nav(function(data)
        vim.notify("Navigation updated from API", vim.log.levels.INFO)
    end)
end

function M.show_nav_with_data(nav_data)
    local flat_nav = flatten_nav(nav_data, nil, false)
    local entries = vim.tbl_map(function (entry) return entry.id end, flat_nav)

    local function get_selected_entry(selected)
        return vim.tbl_filter(function (e) return e.id == selected[1] end, flat_nav)[1]
    end

    fzf.fzf_exec(entries, {
        prompt = config.opts.endpoint .. " > ",
        actions = {
            ["default"] = function (selected)
                if selected then
                    local entry = get_selected_entry(selected)
                    if entry then
                        ui.open_entry(entry.id)
                    end
                end
            end,
            ["ctrl-v"] = function(selected)
                local entry = get_selected_entry(selected)
                -- Open in vertical split on <Ctrl-V>
                if entry then
                    ui.open_entry_in_split(entry.id, "v")
                end
            end,
            ["ctrl-o"] = function(selected)
                local entry = get_selected_entry(selected)
                if entry then
                    ui.open_entry_in_current(entry.id)
                end
            end,
            ["ctrl-p"] = function(selected)
                local entry = get_selected_entry(selected)
                if entry then
                    ui.open_entry_in_popup(entry.id)
                end
            end,
        },
    })
end

function M.create_entry()
    local options = flatten_nav(api.load_cached_nav(), nil, true)
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
    local flat_nav = flatten_nav(nav_data)
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
                end
            end
        }
    })
end

function M.register_commands()
    local actions = {
        ["save"] = ui.save_current_buffer,
        ["nav"] = M.show_nav,
        ["nav_refresh"] = M.force_refresh_nav,
        ["create"] = M.create_entry,
        ["project_entry"] = M.open_project_entry,
        ["project_link_entry"] = M.link_project_entry,
        ["close_popup"] = ui.close_popup,
    }
    vim.api.nvim_create_user_command("PixlCms", function (opts)
        actions[opts.args]()
    end, {
            nargs = 1,
            complete = function (ArgLead, CmdLine, CursorPos)
                local keyset={}
                local n=0

                for k, _ in pairs(actions) do
                    n=n+1
                    keyset[n]=k
                end
                return keyset
            end,
        })
end

return M
