local BD = require("ui/bidi")
local Menu = require("ui/widget/menu")
local UIManager = require("ui/uimanager")
local Device = require("device")
local Backend = require("Legado/Backend")
local Icons = require("Legado/Icons")
local MessageBox = require("Legado/MessageBox")
local H = require("Legado/Helper")

local M = {}

function M:refreshItems(no_recalculate_dimen, go_last_read)
    local book_cache_id = self.bookinfo.cache_id
    local chapter_cache_data = Backend:getAllChaptersByUI(book_cache_id)

    if H.is_tbl(chapter_cache_data) and #chapter_cache_data > 0 then
        self.item_table = self:generateItemTableFromChapters(chapter_cache_data)
        self.multilines_show_more_text = false
        self.items_per_page = nil
        self.single_line = true
    else
        self.item_table = self:generateEmptyViewItemTable()
        self.multilines_show_more_text = true
        self.items_per_page = 1
        self.single_line = false
    end
    Menu.updateItems(self, nil, no_recalculate_dimen)
    if go_last_read then
        self:gotoLastReadChapter()
    end
end

function M:generateEmptyViewItemTable()
    local hint = (self.refresh_menu_key and not Device:isTouchDevice())
        and string.format("press the %s button", self.refresh_menu_key)
        or "swiping down"
    return {{
        text = string.format("Chapter list is empty. Try %s to refresh.", hint),
        dim = true,
        select_enabled = false,
    }}
end

function M:generateItemTableFromChapters(chapters)
    local item_table = {}
    local last_read_chapter = Backend:getLastReadChapter(self.bookinfo.cache_id)

    for _, chapter in ipairs(chapters) do
        local mandatory = (chapter.chapters_index == last_read_chapter and Icons.FA_THUMB_TACK or '') ..
                              (chapter.isRead and Icons.FA_CHECK_CIRCLE or "") ..
                              (chapter.isDownLoaded == true and Icons.UNICODE_CHECK or Icons.FA_DOWNLOAD)

        table.insert(item_table, {
            chapters_index = chapter.chapters_index,
            text = chapter.title or tostring(chapter.chapters_index),
            mandatory = mandatory ~= "" and mandatory or "  "
        })
    end

    return item_table
end

function M:fetchAndShow(bookinfo, onReturnCallBack, showChapterCallBack, accept_cached_results, visible)
    accept_cached_results = accept_cached_results or false

    if not (H.is_tbl(bookinfo) and H.is_str(bookinfo.cache_id)) then
        MessageBox:error('书籍信息出错')
        return
    end
    if not H.is_str(bookinfo.bookUrl) then
        bookinfo.bookUrl = ""
    end
    if not H.is_str(bookinfo.name) then
        bookinfo.name = ""
    end
    if not H.is_str(bookinfo.author) then
        bookinfo.author = ""
    end

    if not H.is_func(onReturnCallBack) then
        onReturnCallBack = function() end
    end

    local settings = Backend:getSettings()
    if not H.is_tbl(settings) then
        MessageBox:error('获取设置出错')
        return
    end

    local items_per_page = G_reader_settings:readSetting("toc_items_per_page") or self.toc_items_per_page_default
    local items_font_size = G_reader_settings:readSetting("toc_items_font_size") or Menu.getItemFontSize(items_per_page)
    local items_with_dots = G_reader_settings:nilOrTrue("toc_items_with_dots")

    local is_stream_image_mode = false
    if bookinfo.cacheExt == 'cbz' then
        local extras_settings = Backend:getBookExtras(bookinfo.cache_id)
        if H.is_tbl(extras_settings) and H.is_tbl(extras_settings.data) then
            is_stream_image_mode = extras_settings.data.stream_image_view == true
        end
    end

    local chapter_listing = self:new{
        bookinfo = bookinfo,
        on_return_callback = onReturnCallBack,
        on_show_chapter_callback = showChapterCallBack,

        title = "目录",
        with_dots = items_with_dots,
        items_per_page = items_per_page,
        items_font_size = items_font_size,
        subtitle = string.format("%s (%s)%s", tostring(bookinfo.name or ""), tostring(bookinfo.author or ""), is_stream_image_mode and "[流式]" or "")
    }
    if visible == true then
        UIManager:show(chapter_listing)
    end
    return chapter_listing
end

function M:gotoLastReadChapter()
    local last_read_chapter = Backend:getLastReadChapter(self.bookinfo.cache_id)
    if H.is_num(last_read_chapter) then
        self:switchItemTable(nil, self.item_table, last_read_chapter)
    end
end

return M
