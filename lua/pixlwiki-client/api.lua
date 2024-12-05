local M = {}
local metadata_cache = {}
local config = require("pixlwiki-client.config")

local curl = require('plenary.curl')
local util = require('pixlwiki-client.util')

local cache_file = vim.fn.stdpath("cache") .. "/pixlwiki-nav.json"
local INSTANCE = config.opts.endpoint
local TOKEN = config.opts.token

function M.fetch_page(page_id, callback)
    local response = curl.get(INSTANCE .. "/api/entry/view?p=" .. page_id, {
        headers = {
            ["pixltoken"] = TOKEN,
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
    local response = curl.put(INSTANCE .. "/api/admin/entry/edit", {
        body = util.urlencode(form),
        headers = {
            ["content-type"] = "application/x-www-form-urlencoded",
            ["pixltoken"] = TOKEN,
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
    local response = curl.get(INSTANCE .. "/api/nav", {
        headers = {
            ["pixltoken"] = TOKEN,
        },
    })
    if response.status == 200 then
        local data = vim.fn.json_decode(response.body)
        local file = io.open(cache_file, "w")
        if file then
            file:write(response.body)
            file:close()
        end
        callback(data)
    else
        vim.notify("Failed to fetch navigation data", vim.log.levels.ERROR)
    end
end

function M.load_cached_nav()
    local file = io.open(cache_file, "r")
    if file then
        local content = file:read("*a")
        file:close()
        return vim.fn.json_decode(content)
    else
        return nil
    end
end

function M.create_entry(parent_folder, title, callback)
    local form = {
        ["parentFolder"] = parent_folder,
        ["title"] = title,
    }
    local response = curl.post(INSTANCE .. "/api/admin/entry/add", {
        body = util.urlencode(form),
        headers = {
            ["pixltoken"] = TOKEN,
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

return M
