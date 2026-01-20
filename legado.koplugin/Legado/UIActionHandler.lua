local logger = require("logger")
local util = require("util")
local Event = require("ui/event")
local UIManager = require("ui/uimanager")
local NetworkMgr = require("ui/network/manager")
local ReaderUI = require("apps/reader/readerui")
local H = require("Legado/Helper")
local MessageBox = require("Legado/MessageBox")

local M = {}

-- 显示阅读器界面
function M.showReaderUI(view_ref, chapter)
    if not (chapter and chapter.cacheFilePath) then return end
    local book_path = chapter.cacheFilePath
    if not util.fileExists(book_path) then
        return MessageBox:error(book_path, "不存在")
    end
    
    view_ref:readingChapter(chapter)

    local toc_obj = view_ref:getBookTocWidget()
    if toc_obj and UIManager:isWidgetShown(toc_obj) then
        UIManager:close(toc_obj)
    end
    
    if ReaderUI.instance then
        ReaderUI.switchDocument(ReaderUI.instance, book_path, true)
    else
        UIManager:broadcastEvent(Event:new("SetupShowReader"))
        ReaderUI:showReader(book_path, nil, true)
    end
    
    UIManager:nextTick(function()
        local backend = view_ref.backend or require("Legado/Backend")
        backend:after_reader_chapter_show(chapter)
    end)
end

-- 加载并渲染章节逻辑 (核心调度)
function M.loadAndRenderChapter(view_ref, chapter)
    if not (chapter and chapter.book_cache_id) then return end
    local backend = view_ref.backend or require("Legado/Backend")
    
    -- 漫画流式阅读特殊处理
    if chapter.cacheExt == 'cbz' then
        local extras_settings = backend:getBookExtras(chapter.book_cache_id)
        if extras_settings.data and extras_settings.data.stream_image_view == true then
            if not NetworkMgr:isConnected() then
                return MessageBox:error("流式漫画需要网络连接")
            end
            view_ref:afterCloseReaderUi(function()
                view_ref.stream_view = require("Legado/StreamImageView"):fetchAndShow({
                    chapter = chapter,
                    on_return_callback = function()
                        local bookinfo = backend:getBookInfoCache(chapter.book_cache_id)
                        view_ref:showBookTocDialog(bookinfo)
                    end,
                })   
            end)
            return 
        end
    end

    local cache_chapter = backend:getCacheChapterFilePath(chapter)
    if cache_chapter and cache_chapter.cacheFilePath then
        M.showReaderUI(view_ref, cache_chapter)
    else
        return MessageBox:loading("正在下载正文", function()
            return backend:downloadChapter(chapter)
        end, function(state, response)
            if state == true then
                backend:HandleResponse(response, function(data)
                    M.showReaderUI(view_ref, data)
                end, function(err_msg)
                    MessageBox:error(err_msg or '下载失败')
                end)
            end
        end)
    end
end

-- 处理阅读进度同步和最后一次阅读跳转
function M.openLastReadChapter(view_ref, bookinfo)
    if not (bookinfo and bookinfo.cache_id) then return false end
    local book_cache_id = bookinfo.cache_id
    local backend = view_ref.backend or require("Legado/Backend")
    local last_read_chapter_index = backend:getLastReadChapter(book_cache_id)
    
    if last_read_chapter_index and last_read_chapter_index >= 0 then
        local chapter = backend:getChapterInfoCache(book_cache_id, last_read_chapter_index)
        if chapter and chapter.chapters_index then
            chapter.call_event = "next"
            M.loadAndRenderChapter(view_ref, chapter)
        else
            view_ref:showBookTocDialog(bookinfo)
            MessageBox:notice('请同步刷新目录数据')
        end
        return true
    end
    return false
end

return M
