local logger = require("logger")
local util = require("util")
local ffiUtil = require("ffi/util")
local dbg = require("dbg")
local H = require("Legado/Helper")

if not dbg.log then
    dbg.log = logger.dbg
end

local M = {}

-- 检查并获取章节缓存文件路径
function M.getCacheChapterFilePath(dbManager, chapter, not_write_db)
    if not (type(chapter) == "table" and chapter.book_cache_id and chapter.chapters_index) then
        return chapter
    end

    local book_cache_id = chapter.book_cache_id
    local chapters_index = chapter.chapters_index
    local book_name = chapter.name or ""
    local cache_file_path = chapter.cacheFilePath
    local cacheExt = chapter.cacheExt

    if type(cache_file_path) == "string" then
        if util.fileExists(cache_file_path) then
            chapter.cacheFilePath = cache_file_path
            return chapter
        else
            dbg.v('Files are deleted, clear database record flag', cache_file_path)
            local tmp_file = cache_file_path .. ".tmp"
            if util.fileExists(tmp_file) then
                pcall(function() util.removeFile(tmp_file) end)
            end
            if not not_write_db and dbManager then
                pcall(function()
                    dbManager:updateCacheFilePath(chapter, false)
                end)
            end
            chapter.cacheFilePath = nil
        end
    end

    local filePath = H.getChapterCacheFilePath(book_cache_id, chapters_index, book_name)
    local extensions = {'html', 'cbz', 'xhtml', 'txt', 'png', 'jpg'}
    if type(cacheExt) == "string" then
        table.insert(extensions, 1, cacheExt)
    end

    for _, ext in ipairs(extensions) do
        local fullPath = filePath .. '.' .. ext
        if util.fileExists(fullPath) then
            chapter.cacheFilePath = fullPath
            return chapter
        end
    end

    return chapter
end

-- 清理单本书的缓存
function M.cleanBookCache(dbManager, bookShelfId, book_cache_id)
    dbManager:clearBook(bookShelfId, book_cache_id)

    local book_cache_path = H.getBookCachePath(book_cache_id)
    if book_cache_path and util.pathExists(book_cache_path) then
        ffiUtil.purgeDir(book_cache_path)
        return true
    else
        return false, '没有缓存'
    end
end

-- 清理所有书架缓存
function M.cleanAllBookCaches(dbManager, currentBookShelfId)
    dbManager:clearBooks(currentBookShelfId)
    local cache_dir = H.getPluginCacheDirectory()
    if util.directoryExists(cache_dir) then
        ffiUtil.purgeDir(cache_dir)
    end
    return true
end

-- 分析指定范围内的章节缓存状态
function M.analyzeCacheStatusForRange(dbManager, book_cache_id, start_index, end_index)
    local cached_chapters = {}
    local uncached_chapters = {}
    
    local chapters = dbManager:getAllChapters(book_cache_id)
    for _, chapter in ipairs(chapters) do
        if chapter.chapters_index >= start_index and chapter.chapters_index <= end_index then
            local updated_chapter = M.getCacheChapterFilePath(dbManager, chapter, true)
            if updated_chapter.cacheFilePath then
                table.insert(cached_chapters, updated_chapter)
            else
                table.insert(uncached_chapters, updated_chapter)
            end
        end
    end
    
    return {
        cached_chapters = cached_chapters,
        uncached_chapters = uncached_chapters
    }
end

return M
