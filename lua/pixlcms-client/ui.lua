local config = require("pixlcms-client.config")
local api = require("pixlcms-client.api")
local fzf = require("fzf-lua")
local M = {}

M.buffers = {}
M.popup_win = nil

local function get_or_create_buffer(entry_id, callback)
    if M.buffers[entry_id] then
        local buf = M.buffers[entry_id]
        if (buf == nil or not vim.api.nvim_buf_is_valid(buf)) then
            vim.notify("Buffer is invalid", vim.log.levels.ERROR)
            return nil
        else
            callback(buf)
        end
    else
        api.fetch_page(entry_id, function(content)
            local buf = M.create_entry_buffer(content, entry_id)
            callback(buf)
        end)
    end
end

function M.create_popup(buf)
    M.popup_win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = math.floor(vim.o.columns * 0.8),
        height = math.floor(vim.o.lines * 0.8),
        col = math.floor(vim.o.columns * 0.1),
        row = math.floor(vim.o.lines * 0.1),
        border = "rounded",
    })
    return M.popup_win
end

function M.create_entry_buffer(content, entry_id)
    local buf = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))
    vim.api.nvim_set_option_value("filetype", "markdown", {
        buf = buf
    })

    vim.api.nvim_buf_set_name(buf, "pw://" .. entry_id)

    vim.bo[buf].modified = false
    vim.bo[buf].buftype = ''
    M.buffers[entry_id] = buf
    return buf
end

function M.open_entry_in_popup(entry_id)
    get_or_create_buffer(entry_id, function (buf)
        if (buf == nil) then return end
        M.create_popup(buf)
    end)
end

-- Open entry in a split view (horizontal or vertical)
function M.open_entry_in_split(entry_id, split_type)
    get_or_create_buffer(entry_id, function (buf)
        if split_type == "v" then
            vim.cmd("vsplit")
        else
            vim.cmd("split")
        end

        if (buf ~= nil) then
            vim.api.nvim_set_current_buf(buf)
        end
    end)
end

function M.open_entry(entry_id)
    if (config.opts.enter_opens_popup) then
        M.open_entry_in_popup(entry_id)
    else
        M.open_entry_in_current(entry_id)
    end
end

function M.open_entry_in_current(entry_id)
    get_or_create_buffer(entry_id, function (buf)
        if (buf ~= nil) then vim.api.nvim_set_current_buf(buf) end
    end)
end

function M.show_popup()
    if M.current_entry_id and M.popup_buf and vim.api.nvim_buf_is_valid(M.popup_buf) then
        M.create_popup(M.popup_buf)
        vim.api.nvim_set_current_win(M.popup_win)
    else
        print("Invalid Buffer");
        M.show_nav()
    end
end

function M.close_popup()
    if M.popup_win and vim.api.nvim_win_is_valid(M.popup_win) then
        vim.api.nvim_win_close(M.popup_win, false)
    end
end

function M.select_endpoint()
    local endpoints = config.opts.endpoints
    local options = {}
    local n=0

    for k, _ in pairs(endpoints) do
        n=n+1
        options[n]=k
    end

    local function set_endpoint(name)
        vim.print(name)
        config.opts.endpoint = endpoints[name]['domain']
        config.opts.token = endpoints[name]['token']
    end

    fzf.fzf_exec(options, {
        prompt = "Select Endpoint > ",
        actions = {
            ["default"] = function (selected)
                set_endpoint(selected[1])
            end,
        }
    })
end

return M
