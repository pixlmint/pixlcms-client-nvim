local M = {}
local metadata_cache = {}
local config = require("pixlcms-client.config")

local curl = require('plenary.curl')
local util = require('pixlcms-client.util')

local cache_file = vim.fn.stdpath("cache") .. "/pixlcms-nav.json"

local function get_instance()
    return config.opts.endpoint
end

local function get_token()
    return config.opts.token
end

function M.fetch_page(page_id, callback)
    local response = curl.get(get_instance() .. "/api/entry/view?p=" .. page_id, {
        headers = {
            ["pixltoken"] = get_token(),
        },
    })
    if response.status == 200 then
        local data = vim.fn.json_decode(response.body)
        metadata_cache[page_id] = data.meta
        callback(data.raw_content)
    else
        vim.notify("Failed to fetch page: " .. page_id, vim.log.levels.ERROR)
    end
end

function M.save_page(page_id, content)
    local form = {
        ["content"] = content,
        ["entry"] = page_id,
        ["meta"] = vim.fn.json_encode(metadata_cache[page_id]),
        ["lastUpdate"] = "",
    }
    -- vim.print(form)
    local response = curl.put(get_instance() .. "/api/admin/entry/edit", {
        body = util.urlencode(form),
        headers = {
            ["content-type"] = "application/x-www-form-urlencoded",
            ["pixltoken"] = get_token(),
        },
    })
    -- vim.print(response.body)
    -- vim.print(vim.fn.json_decode(response.body))
    if response.status == 200 then
        vim.notify("Page saved successfully!", vim.log.levels.INFO)
    else
        vim.notify("Failed to save page: " .. page_id, vim.log.levels.ERROR)
    end
end

function M.fetch_nav(callback)
    local response = curl.get(get_instance() .. "/api/nav?forceReload", {
        headers = {
            ["pixltoken"] = get_token(),
        },
    })
    if response.status == 200 then
        local data = vim.fn.json_decode(response.body)
        io.open(cache_file, "w"):close() -- make sure the file exists
        local file = io.open(cache_file, "r+")
        if file then
            vim.print(file:read("*a"))
            local nav_data_str = file:read("*a")
            local nav_data = {}
            if (string.len(nav_data_str) > 0) then
                nav_data = vim.fn.json_decode(nav_data_str)
            end
            nav_data[get_instance()] = vim.fn.json_decode(response.body)
            file:write(vim.fn.json_encode(nav_data))
            file:close()
        else
            vim.notify("Unable to cache nav to " .. cache_file, vim.log.levels.ERROR)
        end
        if callback then
            callback(data)
        end
    else
        vim.notify("Failed to fetch navigation data", vim.log.levels.ERROR)
    end
end

function M.load_cached_nav()
    local file = io.open(cache_file, "r")
    if file then
        local content = file:read("*a")
        file:close()
        return vim.fn.json_decode(content)[get_instance()]
    else
        return nil
    end
end

function M.create_entry(parent_folder, title, callback)
    local form = {
        ["parentFolder"] = parent_folder,
        ["title"] = title,
    }
    local response = curl.post(get_instance() .. "/api/admin/entry/add", {
        body = util.urlencode(form),
        headers = {
            ["pixltoken"] = get_token(),
            ["content-type"] = "application/x-www-form-urlencoded",
        },
    })

    if response.status == 200 then
        vim.notify("Page created successfully!", vim.log.levels.INFO)
        if callback then
            callback(vim.fn.json_decode(response.body))
        end
    else
        vim.notify("Failed to create page " .. title, vim.log.levels.ERROR)
    end
end


-- Journal Only

function M.current(callback)
    local response = curl.post(get_instance() .. "/api/admin/entry/edit/current", {
        headers = {
            ["pixltoken"] = get_token(),
            ["content-type"] = "application/x-www-form-urlencoded",
        },
    })

    if response.status == 200 then
        local current_entry = vim.fn.json_decode(response.body)["entryId"]
        vim.notify("Loaded current entry " .. current_entry, vim.log.levels.INFO)
        if callback then
            callback(current_entry)
        end
    else
        vim.notify("Unable to get current entry", vim.log.levels.ERROR)
    end
end

return M
