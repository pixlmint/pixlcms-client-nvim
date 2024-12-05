local api = require("pixlwiki-client.api")
local M = {}

M.popup_buf = nil
M.popup_win = nil
M.current_entry_id = nil

function M.create_popup(buf)
    M.popup_win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = math.floor(vim.o.columns * 0.8),
        height = math.floor(vim.o.lines * 0.8),
        col = math.floor(vim.o.columns * 0.1),
        row = math.floor(vim.o.lines * 0.1),
        border = "rounded",
    })
end

function M.create_entry_buffer(content, entry_id)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))
    vim.api.nvim_set_option_value("filetype", "markdown", {
        buf = buf
    })

    vim.api.nvim_buf_create_user_command(buf, "Write", function()
        local new_content = table.concat(vim.api.nvim_buf_get_lines(M.popup_buf, 0, -1, false), "\n")
        api.save_page(entry_id, new_content)
    end, { nargs = 0 })

    vim.api.nvim_buf_set_name(buf, "pw://" .. entry_id)

    vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':PixlwikiClosePopup<CR>', { desc = "Close Popup", silent = true })
    vim.api.nvim_buf_set_keymap(buf, 'n', '<C-s>', ":Write<CR>", { desc = "Save", silent = true })
    vim.api.nvim_buf_set_keymap(buf, 'v', '<C-s>', ":Write<CR>", { desc = "Save", silent = true })
    vim.api.nvim_buf_set_keymap(buf, 'i', '<C-s>', ":Write<CR>", { desc = "Save", silent = true })

    return buf
end

function M.open_popup(content, entry_id)
    M.current_entry_id = entry_id
    M.popup_buf = M.create_entry_buffer(content, entry_id)
    M.create_popup(M.popup_buf)
end

function M.open_page_buffer(page_id, content)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, "pw://" .. page_id)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))
    vim.api.nvim_set_option_value("filetype", "markdown", {
        buf = buf
    })

    vim.api.nvim_create_autocmd("BufWritePost", {
        buffer = buf,
        callback = function ()
            local new_content = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
            api.save_page(page_id, new_content)
        end,
    })

    vim.api.nvim_set_current_buf(buf)
end

return M
