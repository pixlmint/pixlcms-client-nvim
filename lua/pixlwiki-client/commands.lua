local api = require("pixlwiki-client.api")
local ui = require("pixlwiki-client.ui")
local fzf = require("fzf-lua")
local config = require("pixlwiki-client.config")

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
                        M.open_entry(entry.id)
                    end
                end
            end,
            ["ctrl-v"] = function(selected)
                local entry = get_selected_entry(selected)
                -- Open in vertical split on <Ctrl-V>
                if entry then
                    M.open_entry_in_split(entry.id, "v")
                end
            end,
        },
    })
end

-- Open entry in a split view (horizontal or vertical)
function M.open_entry_in_split(entry_id, split_type)
    api.fetch_page(entry_id, function(content)
        local buf = ui.create_entry_buffer(content, entry_id)
        ui.popup_buf = buf

        if split_type == "v" then
            vim.cmd("vsplit")
        else
            vim.cmd("split")
        end

        vim.api.nvim_set_current_buf(buf)
    end)
end

function M.open_entry(entry_id)
    if ui.current_entry_id == entry_id and ui.popup_win and vim.api.nvim_win_is_valid(ui.popup_win) then
        vim.api.nvim_set_current_win(ui.popup_win)
        return
    end

    api.fetch_page(entry_id, function (content)
        ui.open_popup(content, entry_id)
    end)
end

function M.show_popup()
    if ui.current_entry_id and ui.popup_buf and vim.api.nvim_buf_is_valid(ui.popup_buf) then
        ui.create_popup(ui.popup_buf)
        vim.api.nvim_set_current_win(ui.popup_win)
    else
        print("Invalid Buffer");
        M.show_nav()
    end
end

function M.close_popup()
    if ui.popup_win and vim.api.nvim_win_is_valid(ui.popup_win) then
        vim.api.nvim_win_close(ui.popup_win, false)
    end
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

function M.register_commands()
    vim.api.nvim_create_user_command("PixlwikiEdit", function (opts)
        api.fetch_page(opts.args, function (content)
            ui.open_page_buffer(opts.args, content)
        end)
    end, { nargs = 1, complete = "customlist,v:lua.pixlwiki_page_completion"})

    vim.api.nvim_create_user_command("PixlwikiSave", function ()
        ui.save_current_buffer()
    end, { nargs = 0 })

    vim.api.nvim_create_user_command("PixlwikiNav", function ()
        M.show_nav()
    end, { nargs = 0 })

    vim.api.nvim_create_user_command("PixlwikiNavRefresh", function ()
        M.force_refresh_nav()
    end, { nargs = 0 })

    vim.api.nvim_create_user_command("PixlwikiShow", function ()
        M.show_popup()
    end, { nargs = 0 })

    vim.api.nvim_create_user_command("PixlwikiClosePopup", function ()
        M.close_popup()
    end, { nargs = 0 })

    vim.api.nvim_create_user_command("PixlwikiCreateEntry", function ()
        M.create_entry()
    end, { nargs = 0 })
end

return M
