local Backend = require("Legado/Backend")
local MessageBox = require("Legado/MessageBox")
local NetworkMgr = require("ui/network/manager")
local UIManager = require("ui/uimanager")
local Event = require("ui/event")
local ReaderUI = require("apps/reader/readerui")
local util = require("util")
local logger = require("logger")
local H = require("Legado/Helper")

local M = {}

function M:afterCloseReaderUi(callback)
    self:openLegadoFolder(nil, nil, nil, callback)
end

function M:loadAndRenderChapter(chapter)
    if not (H.is_tbl(chapter) and chapter.book_cache_id) then
        logger.err("loadAndRenderChapter: chapter parameter is invalid")
        return 
    end

    if chapter.cacheExt == 'cbz' then
        local book_cache_id = chapter.book_cache_id
        local extras_settings = Backend:getBookExtras(book_cache_id)
        if H.is_tbl(extras_settings.data) and extras_settings.data.stream_image_view == true then
            MessageBox:notice("流式漫画开启")
            if not NetworkMgr:isConnected() then
                MessageBox:error("需要网络连接")
                return
            end
             self:afterCloseReaderUi(function()
                local ex_chapter = chapter
                self.stream_view = require("Legado/StreamImageView"):fetchAndShow({
                    chapter = ex_chapter,
                    on_return_callback = function()
                        local bookinfo = Backend:getBookInfoCache(ex_chapter.book_cache_id)
                        --self:openLastReadChapter(bookinfo)
                        self:showBookTocDialog(bookinfo)
                    end,
                })
            end)
            return 
        end
    end

    local cache_chapter = Backend:getCacheChapterFilePath(chapter)

    if (H.is_tbl(cache_chapter) and H.is_str(cache_chapter.cacheFilePath)) then
        self:showReaderUI(cache_chapter)
    else
        if H.is_tbl(self._pending_chapter_request)
            and self._pending_chapter_request.book_cache_id == chapter.book_cache_id
            and self._pending_chapter_request.chapters_index == chapter.chapters_index then
            local Notification = require("ui/widget/notification")
            Notification:notify("该章节正在后台下载", Notification.SOURCE_ALWAYS_SHOW)
            return
        end

        local request_id = tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
        self._pending_chapter_request = {
            id = request_id,
            book_cache_id = chapter.book_cache_id,
            chapters_index = chapter.chapters_index
        }
        
        -- 发起非阻塞通知
        local Notification = require("ui/widget/notification")
        Notification:notify("正在后台下载正文", Notification.SOURCE_ALWAYS_SHOW)

        Backend:launchProcess(function()
            return Backend:_pDownloadChapter(chapter)
        end, function(status, response, r2)
            if status == true and H.is_tbl(response) and H.is_str(response.cacheFilePath) then
                if Backend.dbManager and Backend.dbManager.updateCacheFilePath then
                    Backend.dbManager:updateCacheFilePath(response, response.cacheFilePath)
                else
                    MessageBox:error("缓存写入失败：DB未就绪")
                end

                local pending = self._pending_chapter_request
                if not (pending and pending.id == request_id) then
                    Notification:notify("下载完成: " .. (chapter.title or ""), Notification.SOURCE_ALWAYS_SHOW)
                    return
                end
                
                -- 如果还在当前书架/目录视图，且没有切换书籍，则自动打开
                if not ReaderUI.instance then
                    self._pending_chapter_request = nil
                    self:showReaderUI(response)
                else
                    self._pending_chapter_request = nil
                    Notification:notify("下载完成，已可阅读", Notification.SOURCE_ALWAYS_SHOW)
                end
            else
                local err_msg = (H.is_tbl(response) and response.message) or response or r2 or "下载失败"
                MessageBox:error(err_msg)
            end
        end)
    end
end

function M:showReaderUI(chapter)
    if not (H.is_tbl(chapter) and H.is_str(chapter.cacheFilePath)) then
        return
    end
    local book_path = chapter.cacheFilePath
    if not util.fileExists(book_path) then
        return MessageBox:error(book_path, "不存在")
    end
    self:readingChapter(chapter)

    local toc_obj = self:getBookTocWidget()
    if toc_obj and UIManager:isWidgetShown(toc_obj) then
        UIManager:close(toc_obj)
    end
    if self.book_menu and UIManager:isWidgetShown(self.book_menu) then
        self.book_menu:onClose()
    end
    if ReaderUI.instance then
        self._legado_switching = true
        ReaderUI.instance:switchDocument(book_path, true)
    else
        UIManager:broadcastEvent(Event:new("SetupShowReader"))
        ReaderUI:showReader(book_path, nil, true)
    end
    UIManager:nextTick(function()
        Backend:after_reader_chapter_show(chapter)
    end)
end

function M:openLastReadChapter(bookinfo)
    if not (H.is_tbl(bookinfo) and bookinfo.cache_id) then
        logger.err("openLastReadChapter parameter error")
        return false
    end
    local book_cache_id = bookinfo.cache_id
    local last_read_chapter_index = Backend:getLastReadChapter(book_cache_id)
    if H.is_num(last_read_chapter_index) then
        if last_read_chapter_index < 0 then
            last_read_chapter_index = 0
        end
        local chapter = Backend:getChapterInfoCache(book_cache_id, last_read_chapter_index)
        if H.is_tbl(chapter) and chapter.chapters_index then
            -- jump to the reading position
            chapter.call_event = "resume"
            self:loadAndRenderChapter(chapter)
        else
            -- chapter does not exist, request refresh
            self:showBookTocDialog(bookinfo)
            MessageBox:notice('请同步刷新目录数据')
        end

        return true
    end
end

function M:ReaderUIEventCallback(chapter_direction)
    if not H.is_str(chapter_direction) then
        logger.err("ReaderUIEventCallback: chapter_direction parameter is invalid")
        return
    end
    if self._legado_eob_pending then
        self._legado_eob_pending = false
    end

    local chapter = self:readingChapter()
    if not (H.is_tbl(chapter) and chapter.book_cache_id) then
        logger.err("ReaderUIEventCallback: current reading chapter is invalid")
        return
    end

    local lookup_direction = chapter_direction
    if chapter_direction == "prev_start" then
        lookup_direction = "prev"
    end
    self:chapterDirection(lookup_direction)
    chapter.call_event = lookup_direction

    local nextChapter = Backend:findNextChapter({
        chapters_index = chapter.chapters_index,
        call_event = chapter.call_event,
        book_cache_id = chapter.book_cache_id,
        totalChapterNum = chapter.totalChapterNum
    })
 
    if H.is_tbl(nextChapter) then
        nextChapter.call_event = chapter_direction
        self:loadAndRenderChapter(nextChapter)
    else
        local book_cache_id = self:getReadingBookId()
        if book_cache_id then
            local bookinfo = Backend:getBookInfoCache(book_cache_id)
            self:afterCloseReaderUi(function()
                self:showBookTocDialog(bookinfo)
            end)
        end
    end
end

return M
