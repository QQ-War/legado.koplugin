local logger = require("logger")
local util = require("util")
local dbg = require("dbg")
local H = require("Legado/Helper")
local MangaRules = require("Legado/MangaRules")

if not dbg.log then
    dbg.log = logger.dbg
end

local M = {}

-- 图像灰度化处理
function M.convertToGrayscale(image_data)
    local Png = require("Legado/Png")
    return Png.processImage(Png.toGrayscale, image_data, 1)
end

-- 获取 URL 扩展名
function M.get_url_extension(url)
    if type(url) ~= "string" or url == "" then
        return ""
    end
    local socket_url = require("socket.url")
    local parsed = socket_url.parse(url)
    local path = parsed and parsed.path
    if not path or path == "" then
        return ""
    end
    path = socket_url.unescape(path):gsub("/+$", "")

    local filename = path:match("([^/]+)$") or ""
    local ext = filename:match("%.([%w]+)$")
    return ext and ext:lower() or "", filename
end

-- 创建 CBZ 压缩包 (核心下载与打包逻辑)
function M.pDownload_CreateCBZ(backend_ref, chapter, filePath, img_sources, bookUrl)
    dbg.v('CreateCBZ start:')

    if not filePath or not H.is_tbl(img_sources) then
        error("Cbz param error:")
    end

    local settings = backend_ref:getSettings()
    local use_proxy = settings.manga_proxy_download == true
    local is_convertToGrayscale = false -- 默认不开启灰度化，预留

    local cbz_path_tmp = filePath .. '.downloading'

    -- 检查并清理过期的下载临时文件
    if util.fileExists(cbz_path_tmp) then
        local lfs = require("libs/libkoreader-lfs")
        local attributes = lfs.attributes(cbz_path_tmp)
        local m_mtime = attributes and attributes.modification or 0
        if os.time() - m_mtime < 600 then
            local socket = require("socket")
            for i = 1, 10 do
                if not util.fileExists(cbz_path_tmp) then break end
                if util.fileExists(filePath) then return filePath end
                socket.select(nil, nil, 1)
            end
            if util.fileExists(filePath) then return filePath end
            if util.fileExists(cbz_path_tmp) then
                error("Other threads downloading, cancelled")
            end
        else
            util.removeFile(cbz_path_tmp)
        end
    end

    local cbz
    local cbz_lib
    local no_compression
    local mtime

    -- 优先使用 ZipWriter
    local ok, ZipWriter = pcall(require, "ffi/zipwriter")
    if ok and ZipWriter then
        cbz_lib = "zipwriter"
        no_compression = true
        cbz = ZipWriter:new{}
        if not cbz:open(cbz_path_tmp) then
            error('CreateCBZ cbz:open err')
        end
        cbz:add("mimetype", "application/vnd.comicbook+zip", true)
    else
        cbz_lib = "archiver"
        mtime = os.time()
        local Archiver = require("ffi/archiver").Writer
        cbz = Archiver:new{}
        if not cbz:open(cbz_path_tmp, "epub") then
            error(string.format("CreateCBZ cbz:open err: %s", tostring(cbz.err)))
        end
        cbz:setZipCompression("store")
        cbz:addFileFromMemory("mimetype", "application/vnd.comicbook+zip", mtime)
        cbz:setZipCompression("deflate")
    end

    for i, img_src in ipairs(img_sources) do
        dbg.v('Download_Image start', i, img_src)
        local status, err
        local pGetUrlContent = backend_ref.pGetUrlContent -- 回调 Backend 的网络请求
        
        if use_proxy then
            local proxy_url = backend_ref:getProxyImageUrl(bookUrl, img_src)
            status, err = pGetUrlContent(backend_ref, {
                url = proxy_url,
                timeout = 20,
                maxtime = 80,
            })
            if not status then
                status, err = pGetUrlContent(backend_ref, {
                    url = img_src,
                    timeout = 15,
                    maxtime = 60,
                    is_pic = true,
                })
            end
        else
            status, err = pGetUrlContent(backend_ref, {
                url = img_src,
                timeout = 15,
                maxtime = 60,
                is_pic = true,
            })
        end

        if status and H.is_tbl(err) and err['data'] then
            local imgdata = err['data']
            local img_extension = err['ext']
            if not img_extension or img_extension == "" then
                img_extension = M.get_url_extension(img_src)
            end
            if not img_extension or img_extension == "" then img_extension = "png" end
            
            local img_name = string.format("%d.%s", i, img_extension)
            if is_convertToGrayscale == true and img_extension == 'png' then
                local success, imgdata_new = M.convertToGrayscale(imgdata)
                if success == true then imgdata = imgdata_new.data end
            end

            if cbz_lib == "zipwriter" then
                cbz:add(img_name, imgdata, no_compression)
            else
                cbz:addFileFromMemory(img_name, imgdata, mtime)
            end
        else
            dbg.v('Download_Image err', tostring(err))
        end
    end

    if cbz and cbz.close then cbz:close() end
    
    if util.fileExists(filePath) ~= true then
        os.rename(cbz_path_tmp, filePath)
    else
        if util.fileExists(cbz_path_tmp) == true then util.removeFile(cbz_path_tmp) end
        error('exist target file, cancelled')
    end

    return filePath
end

return M
