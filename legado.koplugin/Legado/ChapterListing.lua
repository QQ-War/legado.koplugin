local BD = require("ui/bidi")
local Font = require("ui/font")
local util = require("util")
local logger = require("logger")
local dbg = require("dbg")
local Blitbuffer = require("ffi/blitbuffer")
local Menu = require("ui/widget/menu")
local UIManager = require("ui/uimanager")
local NetworkMgr = require("ui/network/manager")
local Device = require("device")
local time = require("ui/time")
local SpinWidget = require("ui/widget/spinwidget")
local ButtonDialog = require("ui/widget/buttondialog")
local Screen = Device.screen

local Backend = require("Legado/Backend")
local Icons = require("Legado/Icons")
local MessageBox = require("Legado/MessageBox")
local H = require("Legado/Helper")

local function safe_require(name, errors)
    local ok, mod = pcall(require, name)
    if not ok then
        if errors then table.insert(errors, string.format("%s: %s", name, tostring(mod))) end
        return {}
    end
    return mod
end

local _load_errors = {}
local ChapterListingView = safe_require("Legado/ChapterListingView", _load_errors)
local ChapterListingActions = safe_require("Legado/ChapterListingActions", _load_errors)
local ChapterListingMenu = safe_require("Legado/ChapterListingMenu", _load_errors)

if not dbg.log then
    dbg.log = logger.dbg
end

local ChapterListing = Menu:extend{
    name = "chapter_listing",
    title = "catalogue",
    align_baselines = true,
    is_borderless = true,
    line_color = Blitbuffer.COLOR_WHITE,
    -- can't be 0 → no key move indicator
    -- linesize = 0,
    covers_fullscreen = true,
    single_line = true,
    toc_items_per_page_default = 14,
    title_bar_left_icon = "appbar.menu",
    title_bar_fm_style = true,

    bookinfo = nil,
    all_chapters_count = nil,
    on_return_callback = nil,
    on_show_chapter_callback = nil,
    _ui_refresh_time = nil,
    refresh_menu_key = nil,
}

function ChapterListing:init()
    self.width, self.height = Screen:getWidth(), Screen:getHeight()
    self.onLeftButtonTap = function()
        self:openMenu()
    end

    Menu.init(self)
    
    if Device:hasKeys() then
        self.refresh_menu_key = "Home"
        if Device:hasKeyboard() then
            self.refresh_menu_key = "F5"
        end
        self.key_events.RefreshChapters = {{ self.refresh_menu_key }}
    end

    if Device:hasDPad() then
        self.key_events.FocusRight = nil
        self.key_events.Right = {{ "Right" }}
    end

    self._ui_refresh_time = os.time()
    self:refreshItems(nil, true)

    if _load_errors and #_load_errors > 0 then
        MessageBox:notice("目录模块加载失败，请重新同步插件")
        for _, err in ipairs(_load_errors) do
            logger.err("chapter listing load error: " .. tostring(err))
        end
    end
end

function ChapterListing:onClose()
    Backend:closeDbManager()
    Menu.onClose(self)
end

function ChapterListing:onReturn()
    if self.on_return_callback ~= nil and H.is_func(self.on_return_callback) then
        self.on_return_callback(self.bookinfo)
    end
    Backend:closeDbManager()
    return true
end

function ChapterListing:onCloseWidget()
    if self.on_return_callback ~= nil and H.is_func(self.on_return_callback) then
        self.on_return_callback(self.bookinfo)
    end

    Backend:closeDbManager()
    Menu.onCloseWidget(self)
end

function ChapterListing:updateReturnCallback(callback)
    -- Skip changes when callback is nil
    if H.is_func(callback) then
        self.on_return_callback = callback
    end
end

-- mixins
for k, v in pairs(ChapterListingView) do ChapterListing[k] = v end
for k, v in pairs(ChapterListingActions) do ChapterListing[k] = v end
for k, v in pairs(ChapterListingMenu) do ChapterListing[k] = v end

return ChapterListing
