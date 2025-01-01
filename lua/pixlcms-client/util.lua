local config = require("pixlcms-client.config")

local opened_entries_storage = config.opts.data_storage .. "/opened-entries.json"

local M = {}

function M.get_opened_entries()
    local opened_entries = nil
    if not M.is_file(opened_entries_storage) then
        io.open(opened_entries_storage, "w"):close()
    end
    local file = io.open(opened_entries_storage, "r+")

    if file then
        local opened_entries_data = file:read("*a")
        if string.len(opened_entries_data) > 0 then
            opened_entries = vim.fn.json_decode(opened_entries_data)
        end
        file:close()
    else
        vim.notify("Unable to learn about previously opened entries", vim.log.levels.WARN)
    end

    if opened_entries == nil then
        opened_entries = {}
    end
    return opened_entries
end

function M.get_opened_entries_sorted()
    local entries = M.get_opened_entries()
    local entries_flat = {}
    for k, v in pairs(entries) do
        v['id'] = k
        table.insert(entries_flat, v)
    end
    table.sort(entries_flat, function (a, b)
        return b['last_opened'] - a['last_opened']
    end)
    return entries_flat
end

function M.is_file(path)
    -- https://stackoverflow.com/a/4991602
    local f = io.open(path,"r")
    if f ~= nil then io.close(f) return true else return false end
end

function M.set_opened_entries(opened_entries)
    local file = io.open(opened_entries_storage, "w")
    if file then
        file:write(vim.fn.json_encode(opened_entries))
        file:close()
    end
end

function M.flatten_nav(nav, parent, folders_only)
    local results = {}
    for _, item in ipairs(nav) do
        local path = parent and (parent .. " > " .. item.title) or item.title
        if item.kind and item.kind == 'board' then
        elseif item.isFolder then
            if folders_only then
                table.insert(results, { title = item.title, id = item.id })
            end
            vim.list_extend(results, M.flatten_nav(item.children, path, folders_only))
        elseif not folders_only then
            table.insert(results, { title = path, id = item.id })
        end
    end

    return results
end

return M
