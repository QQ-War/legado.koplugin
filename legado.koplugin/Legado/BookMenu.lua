local BD = require("ui/bidi")
local Font = require("ui/font")
local util = require("util")
local logger = require("logger")
local dbg = require("dbg")
local Menu = require("ui/widget/menu")
local UIManager = require("ui/uimanager")
local NetworkMgr = require("ui/network/manager")
local Device = require("device")
local T = require("ffi/util").template
local _ = require("gettext")

local Icons = require("Legado/Icons")
local Backend = require("Legado/Backend")
local MessageBox = require("Legado/MessageBox")
local H = require("Legado/Helper")

local BookMenu = Menu:extend{
    name = "legado_book_menu",
    is_borderless = true,
    covers_fullscreen = true,
    single_line = true,
    title_bar_left_icon = "appbar.menu",
    title_bar_fm_style = true,
    show_search_item = true,
    
    parent_ref = nil, -- 引用 LibraryView 实例
    refresh_menu_key = nil,
}

function BookMenu:init()
    self.onLeftButtonTap = function()
        self.parent_ref:openMenu()
    end
    
    Menu.init(self)
    
    if Device:hasKeys() then
        self.refresh_menu_key = Device:hasKeyboard() and "F5" or "Home"
        self.key_events.RefreshLibrary = {{ self.refresh_menu_key }}
    end
    
    self:refreshItems()
end

-- 此处省略大量 generateItemTable 和事件处理代码，后续通过 replace 填充
-- ...

return BookMenu
