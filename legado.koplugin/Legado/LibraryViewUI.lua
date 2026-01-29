local UIManager = require("ui/uimanager")
local FileManager = require("apps/filemanager/filemanager")
local filemanagerutil = require("apps/filemanager/filemanagerutil")
local Backend = require("Legado/Backend")
local logger = require("logger")

local M = {}

function M:clearMenuItems()
    if self.book_menu then
        self.book_menu.item_table = self.book_menu:generateEmptyViewItemTable()
        self.book_menu.multilines_show_more_text = true
        self.book_menu.items_per_page = 1
        self.book_menu:updateItems()
    end
end

function M:closeMenu()
    if self.book_menu then
        self.book_menu:onClose()
    end
end

function M:getInstance()
    if not self.instance then
        self:init()
        if not self.instance then
            logger.err("LibraryView init not loaded")
        end
    end
    return self
end

function M:closeBookshelfToHome()
    local home_dir = G_reader_settings:readSetting("home_dir") or filemanagerutil.getDefaultDir()
    UIManager:nextTick(function()
        local ok, err = pcall(function()
            if FileManager.instance and FileManager.instance.goHome then
                FileManager.instance:goHome()
            elseif home_dir then
                FileManager:showFiles(home_dir)
            end
        end)
        if not ok then
            logger.err("返回本地目录失败:", tostring(err))
        end
    end)
    UIManager:nextTick(function()
        Backend:closeDbManager()
    end)
end

return M
