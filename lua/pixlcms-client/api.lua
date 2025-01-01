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

local function log_opened_entry(entry)
    local opened_entries = util.get_opened_entries()
    if opened_entries[entry] == nil then
        opened_entries[entry] = {
            times_opened = 0,
            last_opened = -1,
        }
    end
    opened_entries[entry]["times_opened"] = opened_entries[entry]["times_opened"] + 1
    opened_entries[entry]["last_opened"] = os.time()
    util.set_opened_entries(opened_entries)
end

function M.fetch_page(page_id, callback)
    local response = curl.get(get_instance() .. "/api/entry/view?p=" .. page_id, {
        headers = {
            ["pixltoken"] = get_token(),
        },
    })
    if response.status == 200 then
        log_opened_entry(page_id)
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
    local response = curl.put(get_instance() .. "/api/admin/entry/edit", {
        body = util.urlencode(form),
        headers = {
            ["content-type"] = "application/x-www-form-urlencoded",
            ["pixltoken"] = get_token(),
        },
    })
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
        if not util.is_file(cache_file) then
            io.open(cache_file, "w"):close()
        end
        local file = io.open(cache_file, "r")
        local nav_data = {}
        if file then
            local nav_data_str = file:read("*a")
            if (string.len(nav_data_str) > 0) then
                nav_data = vim.fn.json_decode(nav_data_str)
            end
            file:close()
        end
        file = io.open(cache_file, "w")
        if file then
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
