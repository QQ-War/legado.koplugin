local UIManager = require("ui/uimanager")
local NetworkMgr = require("ui/network/manager")
local Device = require("device")
local MessageBox = require("Legado/MessageBox")
local Backend = require("Legado/Backend")
local Icons = require("Legado/Icons")
local H = require("Legado/Helper")

local M = {}

function M:openMenu()
    if not (self.bookinfo and H.is_str(self.bookinfo.cache_id)) then
        MessageBox:notice("书籍信息异常")
        return
    end
    local dialog
    local book_name = tostring(self.bookinfo.name or "")
    local buttons = {{},{
        {
            text = Icons.FA_GLOBE .. " 切换书源",
            callback = function()
                if NetworkMgr:isConnected() then
                    UIManager:close(dialog)
                    UIManager:nextTick(function()
                        require("Legado/BookSourceResults"):changeSourceDialog(self.bookinfo, function()
                            self:onReturn()
                        end)
                    end)
                else
                    MessageBox:notice("操作失败，请检查网络")
                end
            end,
            align = "left",
        }
    }, {
        {
            text = Icons.FA_EXCHANGE .. " 排序反转",
            callback = function()
                UIManager:close(dialog)
                self:toggleSortMode()
            end,
            align = "left",
        }
    }, {
        {
            text = table.concat({Icons.FA_THUMB_TACK, " 拉取进度"}),
            callback = function()
                if self.multilines_show_more_text == true then
                    MessageBox:notice('章节列表为空')
                    return
                end
                UIManager:close(dialog)
                self:syncProgressShow()
            end,
            align = "left",
        }
    }, {
        {
            text = Icons.FA_DOWNLOAD .. " 缓存管理",
            callback = function()
                UIManager:close(dialog)
                MessageBox:confirm(
                    string.format("《%s》: \n\n (部分书源存在访问频率限制，如遇章节缺失或内容不完整，可尝试: \n  长按章节分章下载、调低并发下载数)", book_name),
                    function(result)
                        if result then
                            require("Legado/ExportDialog"):new({
                                bookinfo = self.bookinfo
                            }):cacheAllChapters(function(success)
                                self:refreshItems(true)
                            end)
                        end
                    end,
                    {
                        ok_text = "缓存全书",
                        cancel_text = "取消",
                        other_buttons_first = true,
                        other_buttons = {{
                            {
                                text = "导出书籍",
                                callback = function()
                                    require("Legado/ExportDialog"):new({ bookinfo = self.bookinfo }):exportBook()
                                end,
                            }, {
                                 text = "清理已读",
                                 callback = function()
                                     MessageBox:confirm(
                                         "请确认清理本书已读章节的缓存：\n",
                                         function(result)
                                             if not result then return end
                                             Backend:closeDbManager()
                                             MessageBox:loading("清理中 ", function()
                                                 return Backend:cleanReadChapterCache(self.bookinfo.cache_id)
                                             end, function(state, response)
                                                 if state == true and H.is_str(response) then
                                                     local response_func = loadstring("return " .. response)
                                                     if response_func then response = response_func() end
                                                     Backend:HandleResponse(response, function(data)
                                                         MessageBox:success(tostring(data or "清理完成"))
                                                         self:refreshItems(true)
                                                     end, function(err_msg)
                                                         MessageBox:error('失败：', err_msg)
                                                     end)
                                                 end
                                             end)
                                         end)
                                 end,

                            }, {
                                 text = "查看已缓存区间",
                                 callback = function()
                                     Backend:closeDbManager()
                                     MessageBox:loading("统计中", function()
                                         return Backend:analyzeCacheStatus(self.bookinfo.cache_id)
                                     end, function(state, data)
                                         if state == true and H.is_str(data) then
                                             local status_func = loadstring("return " .. data)
                                             if status_func then data = status_func() end
                                             if not (H.is_tbl(data) and H.is_tbl(data.cached_chapters)) then

                                                MessageBox:notice("未发现缓存")
                                                return
                                            end
                                            local indices = {}
                                            for _, c in ipairs(data.cached_chapters) do
                                                if c.chapters_index ~= nil then
                                                    table.insert(indices, c.chapters_index)
                                                end
                                            end
                                            table.sort(indices)
                                            if #indices == 0 then
                                                MessageBox:notice("未发现缓存")
                                                return
                                            end
                                            local ranges = {}
                                            local start = indices[1]
                                            local last = indices[1]
                                            for i = 2, #indices do
                                                local v = indices[i]
                                                if v == last + 1 then
                                                    last = v
                                                else
                                                    table.insert(ranges, {start, last})
                                                    start = v
                                                    last = v
                                                end
                                            end
                                            table.insert(ranges, {start, last})
                                            local parts = {}
                                            for _, r in ipairs(ranges) do
                                                local s = r[1] + 1
                                                local e = r[2] + 1
                                                if s == e then
                                                    table.insert(parts, tostring(s))
                                                else
                                                    table.insert(parts, string.format("%d-%d", s, e))
                                                end
                                            end
                                            local msg = "已缓存章节区间：\n" .. table.concat(parts, ", ")
                                            MessageBox:confirm(msg, function() end, { ok_text = "确定", cancel_text = "关闭" })
                                        end
                                    end)
                                end,
                            }, {
                                 text = "清除全书",
                                 callback = function()
                                     MessageBox:confirm(
                                         "请确认清除本书所有缓存：\n",
                                         function(result)
                                             if not result then return end
                                             Backend:closeDbManager()
                                             MessageBox:loading("清理中 ", function()
                                                 return Backend:cleanBookCache(self.bookinfo.cache_id)
                                             end, function(state, response)
                                                 if state == true and H.is_str(response) then
                                                     local response_func = loadstring("return " .. response)
                                                     if response_func then response = response_func() end
                                                     Backend:HandleResponse(response, function(data)
                                                         MessageBox:success("已清理，刷新重新可添加")
                                                         self:onReturn()
                                                     end, function(err_msg)
                                                         MessageBox:error('请稍后重试：', err_msg)
                                                     end)
                                                 end
                                             end)
                                         end)
                                 end,

                            }
                        }}
                    }
                )
            end,
            align = "left",
        }
    }}

    local stream_mode_item = self:getStreamModeItem(function()
        if dialog then UIManager:close(dialog) end
    end)
    if H.is_tbl(stream_mode_item) then
        table.insert(buttons, stream_mode_item)
    end

    if not Device:isTouchDevice() then
        table.insert(buttons, {{
            text = Icons.FA_REFRESH .. ' ' .. "刷新目录",
            callback = function()
                UIManager:close(dialog)
                self:onRefreshChapters()
            end,
            align = "left",
        }})
    end

    table.insert(buttons, {{
        text = Icons.FA_SHARE .. " 跳转到指定章节",
        callback = function()
            UIManager:close(dialog)
            if self.multilines_show_more_text == true then
                MessageBox:notice('章节列表为空')
                return
            end
            if Device.isAndroid() then
                local book_cache_id = self.bookinfo.cache_id
                if not self.all_chapters_count then
                    self.all_chapters_count = Backend:getChapterCount(book_cache_id)
                end
                UIManager:show(require("ui/widget/spinwidget"):new{
                    value = 1,
                    value_min = 1,
                    value_max = tonumber(self.all_chapters_count) or 10,
                    value_step = 1,
                    value_hold_step = 5,
                    ok_text = "跳转",
                    title_text = "请选择需要跳转的章节：",
                    info_text = "( 点击中间可直接输入数字 )",
                    callback = function(autoturn_spin)
                        local autoturn_spin_value = autoturn_spin and tonumber(autoturn_spin.value)
                        self:onGotoPage(self:getPageNumber(autoturn_spin_value))
                    end
                })
            else
                self:onShowGotoDialog()
            end
        end,
        align = "left",
    }})

    dialog = require("ui/widget/buttondialog"):new{
        buttons = buttons,
        title = "菜单",
        title_align = "center"
    }

    UIManager:show(dialog)
end

return M
