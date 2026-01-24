local UIManager = require("ui/uimanager")
local Backend = require("Legado/Backend")
local ChapterListing = require("Legado/ChapterListing")
local MessageBox = require("Legado/MessageBox")
local H = require("Legado/Helper")
local logger = require("logger")

local M = {}

function M:refreshBookTocWidget(bookinfo, onReturnCallBack, visible)
    if not (H.is_tbl(bookinfo) and bookinfo.cache_id) then
        logger.err("refreshBookTocWidget parameter error")
        return self.book_toc
    end

    local book_cache_id = bookinfo.cache_id

    local toc_obj = self.book_toc
    if not (H.is_tbl(toc_obj) and H.is_tbl(toc_obj.bookinfo) and 
            toc_obj.bookinfo.cache_id == book_cache_id) then
            logger.dbg("add new book_toc widget")

            self.book_toc = ChapterListing:fetchAndShow({
                cache_id = bookinfo.cache_id,
                bookUrl = bookinfo.bookUrl,
                durChapterIndex = bookinfo.durChapterIndex,
                name = bookinfo.name,
                author = bookinfo.author,
                cacheExt = bookinfo.cacheExt,
                origin = bookinfo.origin,
                originName = bookinfo.originName,
                originOrder = bookinfo.originOrder,
                coverUrl = bookinfo.coverUrl,

            }, onReturnCallBack, function(chapter)
                    self:loadAndRenderChapter(chapter)
            end, true, visible)

    else
        logger.dbg("update book_toc widget ReturnCallback")
        self.book_toc:updateReturnCallback(onReturnCallBack)

        if visible == true then
            self.book_toc:refreshItems(nil, true)
            UIManager:show(self.book_toc)
        end
    end
    return self.book_toc
end

function M:showBookTocDialog(bookinfo)
    if not H.is_tbl(bookinfo) then
        MessageBox:error("书籍信息出错")
        return
    end
    self:refreshBookTocWidget(bookinfo, nil, true)
end

return M
