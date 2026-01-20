local logger = require("logger")
local H = require("Legado/Helper")

local BaseApi = {
    name = "base_api",
    settings = nil,
}

function BaseApi:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

-- 接口定义 (待子类实现)
function BaseApi:getBookshelf(callback) error("Not implemented") end
function BaseApi:saveBook(bookinfo, callback) error("Not implemented") end
function BaseApi:deleteBook(bookinfo, callback) error("Not implemented") end
function BaseApi:getChapterList(bookinfo, callback) error("Not implemented") end
function BaseApi:getBookContent(chapter, callback) error("Not implemented") end
function BaseApi:refreshBookContent(chapter, callback) error("Not implemented") end
function BaseApi:saveBookProgress(chapter, callback) error("Not implemented") end
function BaseApi:searchBookMulti(options, callback) error("Not implemented") end

-- 代理 URL 生成器
function BaseApi:getProxyCoverUrl(coverUrl) return coverUrl end
function BaseApi:getProxyImageUrl(bookUrl, img_src) return img_src end
function BaseApi:getProxyEpubUrl(bookUrl, htmlUrl) return htmlUrl end

return BaseApi
