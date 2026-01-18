local M = {}

M.antiScrapingProfiles = {
    ["acg456.com"] = "http://www.acg456.com/",
    ["baozimh.com"] = "https://www.baozimh.com/",
    ["bzcdn.net"] = "https://www.baozimh.com/",
    ["manga.bilibili.com"] = "https://manga.bilibili.com/",
    ["boodo.qq.com"] = "https://boodo.qq.com/",
    ["boylove.cc"] = "https://boylove.cc/",
    ["177pic.info"] = "http://www.177pic.info/",
    ["18comic.vip"] = "https://18comic.vip/",
    ["18h.mm-cg.com"] = "https://18h.mm-cg.com/",
    ["2animx.com"] = "https://www.2animx.com/",
    ["2feimh.com"] = "https://www.2feimh.com/",
    ["3250mh.com"] = "https://www.3250mh.com/",
    ["36mh.com"] = "https://www.36mh.com/",
    ["55comic.com"] = "https://www.55comic.com/",
    ["77mh.cc"] = "https://www.77mh.cc/",
    ["copymanga.tv"] = "https://copymanga.tv/",
    ["dm5.com"] = "https://www.dm5.com/",
    ["cdndm5.com"] = "https://www.dm5.com/",
    ["dmzj.com"] = "https://www.dmzj.com/",
    ["gufengmh9.com"] = "https://www.gufengmh9.com/",
    ["bud.iqiyi.com"] = "https://bud.iqiyi.com/",
    ["jmzj.xyz"] = "http://jmzj.xyz/",
    ["kanman.com"] = "https://www.kanman.com/",
    ["kuaikanmanhua.com"] = "https://www.kuaikanmanhua.com/",
    ["kkmh.com"] = "https://www.kuaikanmanhua.com/",
    ["kuimh.com"] = "https://www.kuimh.com/",
    ["laimanhua.net"] = "https://www.laimanhua.net/",
    ["manhuadb.com"] = "https://www.manhuadb.com/",
    ["manhuafei.com"] = "https://www.manhuafei.com/",
    ["manhuagui.com"] = "https://www.manhuagui.com/",
    ["manhuatai.com"] = "https://www.manhuatai.com/",
    ["manwa.site"] = "https://manwa.site/",
    ["mh1234.com"] = "https://www.mh1234.com/",
    ["mh160.cc"] = "https://mh160.cc/",
    ["mmkk.me"] = "https://www.mmkk.me/",
    ["myfcomic.com"] = "http://www.myfcomic.com/",
    ["nhentai.net"] = "https://nhentai.net/",
    ["picxx.icu"] = "http://picxx.icu/",
    ["pufei8.com"] = "http://www.pufei8.com/",
    ["qiman6.com"] = "http://www.qiman6.com/",
    ["qimiaomh.com"] = "https://www.qimiaomh.com/",
    ["qootoon.net"] = "https://www.qootoon.net/",
    ["ac.qq.com"] = "https://ac.qq.com/",
    ["sixmh6.com"] = "http://www.sixmh6.com/",
    ["tuhao456.com"] = "https://www.tuhao456.com/",
    ["twhentai.com"] = "http://twhentai.com/",
    ["u17.com"] = "https://www.u17.com/",
    ["webtoons.com"] = "https://www.webtoons.com/",
    ["wnacg.org"] = "http://www.wnacg.org/",
    ["xiuren.org"] = "http://www.xiuren.org/",
    ["ykmh.com"] = "https://www.ykmh.com/",
    ["yymh889.com"] = "http://yymh889.com/"
}

M.extraHeaders = {
    ["kkmh.com"] = { ["Origin"] = "https://www.kuaikanmanhua.com" },
    ["kuaikanmanhua.com"] = { ["Origin"] = "https://www.kuaikanmanhua.com" }
}

function M.getRefererForUrl(url)
    if not url then return nil end
    local host = url:match("https?://([^/]+)")
    if not host then return nil end
    
    -- Check direct match and suffix match
    for domain, referer in pairs(M.antiScrapingProfiles) do
        if host == domain or host:sub(-#domain - 1) == "." .. domain then
            return referer
        end
    end
    return nil
end

function M.getExtraHeadersForUrl(url)
    if not url then return nil end
    local host = url:match("https?://([^/]+)")
    if not host then return nil end
    
    for domain, headers in pairs(M.extraHeaders) do
        if host == domain or host:sub(-#domain - 1) == "." .. domain then
            return headers
        end
    end
    return nil
end

function M.getAbsoluteUrl(img_src, bookUrl)
    if not img_src or img_src == "" then return img_src end
    if img_src:match("^https?://") then return img_src end
    if img_src:match("^//") then return "https:" .. img_src end
    
    local socket_url = require("socket.url")
    return socket_url.absolute(bookUrl, img_src)
end

return M
