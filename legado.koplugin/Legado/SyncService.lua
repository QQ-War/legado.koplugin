local logger = require("logger")
local dbg = require("dbg")
local H = require("Legado/Helper")
local MangaRules = require("Legado/MangaRules")

if not dbg.log then
    dbg.log = logger.dbg
end

local function wrap_response(data, err_message)
    local response = { 
        type = data ~= nil and 'SUCCESS' or 'ERROR' 
    }
    if data ~= nil then
        response.body = data
    else
        response.message = H.is_str(err_message) and err_message or "Unknown error"
    end
    return response
end

local M = {}

-- 刷新书架缓存
function M.refreshLibraryCache(backend_ref, last_refresh_time, isUpdate)
    if last_refresh_time and os.time() - last_refresh_time < 2 then
        dbg.v('ui_refresh_time prevent refreshChaptersCache')
        return wrap_response(nil, '处理中')
    end
    
    local ret, err_msg = backend_ref.apiClient:getBookshelf(function(response)
        local bookShelfId = backend_ref:getCurrentBookShelfId()
        local status, err = pcall(function()
            return backend_ref.dbManager:upsertBooks(bookShelfId, response.data, isUpdate)
        end)
        if not status then
            dbg.log('refreshLibraryCache数据写入', err)
            return nil, '写入数据出错，请重试'
        end
        return true
    end)
    return wrap_response(ret, err_msg)
end

-- 同步并重新排序书籍
function M.syncAndResortBooks(backend_ref)
    local wrapped_response = M.refreshLibraryCache(backend_ref)
    return backend_ref:HandleResponse(wrapped_response, function(data)
        local bookShelfId = backend_ref:getCurrentBookShelfId()
        local status, err = pcall(function()
            return backend_ref.dbManager:resortBooksByLastRead(bookShelfId)
        end)
        if not status then
            return wrap_response(nil, "排序失败: " .. tostring(err))
        end
        return wrap_response(true)
    end, function(err_msg)
        return wrap_response(nil, err_msg)
    end)
end

-- 获取章节列表并缓存
function M.refreshChaptersCache(backend_ref, bookinfo, last_refresh_time)
    if last_refresh_time and os.time() - last_refresh_time < 2 then
        dbg.v('ui_refresh_time prevent refreshChaptersCache')
        return wrap_response(nil, '处理中')
    end
    if not (type(bookinfo) == "table" and bookinfo.bookUrl and bookinfo.cache_id) then
        return wrap_response(nil, "获取目录参数错误")
    end
    
    local book_cache_id = bookinfo.cache_id
    return wrap_response(backend_ref.apiClient:getChapterList(bookinfo, function(response)
        local status, err = H.pcall(function()
            return backend_ref.dbManager:upsertChapters(book_cache_id, response.data)
        end)
        if not status then
            dbg.log('refreshChaptersCache数据写入', tostring(err))
            return nil, '数据写入出错，请重试'
        end
        return true
    end))
end

-- 获取章节正文 (带 Fallback 逻辑)
function M.pGetChapterContent(backend_ref, chapter)
    local response = wrap_response(backend_ref.apiClient:getBookContent(chapter))

    -- 核心修复：针对特定服务端 Jsoup 解析异常增加本地回退
    if (not (type(response) == "table") or response.type ~= 'SUCCESS') and chapter.bookUrl then
        local host = chapter.bookUrl:match("https?://([^/]+)")
        if host and (host:find("mxshm.top") or host:find("www.mxshm.top")) then
            dbg.log("Server getBookContent failed, trying local fallback for", host)
            local clean_url = MangaRules.sanitizeImageUrl(chapter.url)
            if not clean_url:find("^https?://") then
                clean_url = MangaRules.getAbsoluteUrl(clean_url, chapter.bookUrl)
            end
            local status, html_data = backend_ref:pGetUrlContent({
                url = clean_url,
                timeout = 20,
                maxtime = 60
            })
            if status and type(html_data) == "table" and html_data.data then
                dbg.log("Local fallback success for", host)
                return wrap_response(html_data.data)
            end
        end
    end

    return response
end

-- 保存书籍进度
function M.saveBookProgress(backend_ref, chapter)
    return wrap_response(backend_ref.apiClient:saveBookProgress(chapter))
end

return M
