local Blitbuffer = require("ffi/blitbuffer")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local Size = require("ui/size")
local UIManager = require("ui/uimanager")
local Menu = require("ui/widget/menu")
local Device = require("device")
local _ = require("gettext")

local Icons = require("Legado/Icons")
local Backend = require("Legado/Backend")
local MessageBox = require("Legado/MessageBox")

local CacheManagementDialog = Menu:extend{
    name = "legado_cache_management",
    is_borderless = true,
    covers_fullscreen = true,
    single_line = true,
    title = "缓存分析与管理",
}

function CacheManagementDialog:init()
    self.onLeftButtonTap = function()
        self:onClose()
    end
    Menu.init(self)
    self:refreshItems()
end

function CacheManagementDialog:refreshItems()
    local stats, total_size = Backend:getAllBooksCacheStats()
    local item_table = {}
    
    self.subtitle = "总占用: " .. require("Legado/CacheManager").formatSize(total_size)

    if #stats == 0 then
        table.insert(item_table, {
            text = "本地无缓存数据",
            dim = true,
            select_enabled = false,
        })
    else
        for _, item in ipairs(stats) do
            table.insert(item_table, {
                text = item.name,
                mandatory = item.size_text,
                cache_id = item.cache_id,
            })
        end
    end
    
    self.item_table = item_table
    Menu.updateItems(self)
end

function CacheManagementDialog:onMenuSelect(item)
    if not item.cache_id then return end
    
    MessageBox:confirm(string.format("是否清空 <<%s>> 的所有本地缓存？", item.text), function(result)
        if result then
            Backend:cleanBookCache(item.cache_id)
            MessageBox:notice("已清理")
            self:refreshItems()
        end
    end)
end

return CacheManagementDialog
