local BD = require("ui/bidi")
local Menu = require("ui/widget/menu")
local UIManager = require("ui/uimanager")
local NetworkMgr = require("ui/network/manager")
local Device = require("device")
local SpinWidget = require("ui/widget/spinwidget")
local ButtonDialog = require("ui/widget/buttondialog")

local Backend = require("Legado/Backend")
local MessageBox = require("Legado/MessageBox")
local Icons = require("Legado/Icons")
local H = require("Legado/Helper")

local M = {}

function M:onMenuChoice(item)
    if item.chapters_index == nil then
        return true
    end
    local book_cache_id = self.bookinfo.cache_id
    local chapters_index = item.chapters_index

    local chapter = Backend:getChapterInfoCache(book_cache_id, chapters_index)
    if not H.is_tbl(chapter) then
        MessageBox:notice("章节数据为空")
        return true
    end
    if self.onShowingReader then self:onShowingReader() end
    self:showReaderUI(chapter)
    return true
end

function M:onMenuHold(item)
    local book_cache_id = self.bookinfo.cache_id

    if item.chapters_index == nil then
        return true
    end
    local chapters_index = item.chapters_index
    local chapter = Backend:getChapterInfoCache(book_cache_id, chapters_index)

    local function parse_range_input(input_text, max_chapters)
        local start_num, end_num = input_text:match("^(%d+)%-(%d+)$")
        if start_num and end_num then
            start_num, end_num = tonumber(start_num), tonumber(end_num)
        else
            start_num = tonumber(input_text)
            end_num = nil
        end
        if not start_num then
            return nil, nil
        end
        if start_num < 1 or start_num > max_chapters then
            return nil, nil
        end
        if end_num then
            if end_num < 1 or end_num > max_chapters or end_num < start_num then
                return nil, nil
            end
        end
        return start_num, end_num or start_num
    end

    local function prompt_clean_range(start, finish)
        if not self.all_chapters_count then
            self.all_chapters_count = Backend:getChapterCount(book_cache_id)
        end
        local max_chapters = tonumber(self.all_chapters_count) or 0
        if max_chapters < 1 then
            MessageBox:notice("章节数为 0")
            return
        end
        local max_num = max_chapters
        if finish and finish > max_num then finish = max_num end
        MessageBox:confirm(
            string.format("清理章节缓存：%s - %s?", tostring(start or ""), tostring(finish or "")),
            function(result)
                if not result then return end
                Backend:closeDbManager()
                MessageBox:loading("清理中 ", function()
                    return Backend:cleanChaptersCache(book_cache_id, start, finish)
                end, function(state, response)
                    if state == true then
                        Backend:HandleResponse(response, function(data)
                            MessageBox:notice("清理完成")
                            self:refreshItems(true)
                        end, function(err_msg)
                            MessageBox:error('失败：', err_msg)
                        end)
                    end
                end)
            end
        )
    end

    local dialog
    local buttons = {{
        {
            text = table.concat({Icons.FA_TRASH, " 清理已读"}),
            callback = function()
                UIManager:close(dialog)
                if not H.is_tbl(chapter) then
                    MessageBox:notice('章节数据为空')
                    return
                end
                local chapters_index = chapter.chapters_index
                if chapters_index and chapters_index > 0 then
                    prompt_clean_range(0, chapters_index - 1)
                end
            end
        },
        {
            text = table.concat({Icons.FA_TRASH, " 清理区间"}),
            callback = function()
                UIManager:close(dialog)
                prompt_clean_range(chapters_index)
            end
        }
    }}

    local dialog_title = table.concat({"[", tostring(item.text), ']'})
    dialog = ButtonDialog:new{
        buttons = buttons,
        title = dialog_title,
        title_align = "center"
    }

    UIManager:show(dialog)
end

function M:onSwipe(arg, ges_ev)
    local direction = BD.flipDirectionIfMirroredUILayout(ges_ev.direction)
    if direction == "south" then
        if NetworkMgr:isConnected() then
            UIManager:nextTick(function()
                self:onRefreshChapters()
            end)
        else
            MessageBox:notice("刷新失败，请检查网络")
        end
        return
    end
    Menu.onSwipe(self, arg, ges_ev)
end

function M:onRefreshChapters()
    if not Backend.settings_data then
        Backend:initialize()
    end
    if not (self.bookinfo and H.is_str(self.bookinfo.cache_id) and H.is_str(self.bookinfo.bookUrl)) then
        MessageBox:notice("目录信息不完整，无法刷新")
        return
    end
    Backend:closeDbManager()
    MessageBox:loading("正在刷新章节数据", function()
        local ok, response = pcall(function()
            return Backend:refreshChaptersCache({
                cache_id = self.bookinfo.cache_id,
                bookUrl = self.bookinfo.bookUrl,
                origin = self.bookinfo.origin,
                name = self.bookinfo.name,
            }, self._ui_refresh_time)
        end)
        if not ok then
            return { type = "ERROR", message = tostring(response) }
        end
        return response
    end, function(state, response)
        if state == true then
            Backend:HandleResponse(response, function(data)
                MessageBox:notice('同步成功')
                self:refreshItems(nil, true)
                self.all_chapters_count = nil
                self._ui_refresh_time = os.time()
            end, function(err_msg)
                MessageBox:notice(err_msg or '同步失败')
                if err_msg ~= '处理中' then
                    MessageBox:notice("请检查并刷新书架")
                end
            end)
        end
    end)
end

function M:showReaderUI(chapter)
    if H.is_func(self.on_show_chapter_callback) then
        self.on_show_chapter_callback(chapter)
    end
end

function M:syncProgressShow(chapter)
    Backend:closeDbManager()
    MessageBox:loading("同步中 ", function()
        if H.is_tbl(chapter) and H.is_num(chapter.chapters_index) then
            local response = Backend:saveBookProgress(chapter)
            if not (type(response) == 'table' and response.type == 'SUCCESS') then
                local message = type(response) == 'table' and response.message or
                                    "进度上传失败，请稍后重试"
                return {
                    type = 'ERROR',
                    message = message or ""
                }
            end
        end
    end, function(state, response)
        if state == true then
            Backend:HandleResponse(response, function(data)
                MessageBox:notice('同步成功')
                if H.is_tbl(chapter) and H.is_num(chapter.chapters_index) then
                    self:refreshItems(true)
                    self:switchItemTable(nil, self.item_table, chapter.chapters_index)
                end
            end, function(err_msg)
                MessageBox:notice(err_msg or '同步失败')
                if err_msg ~= '处理中' then
                    MessageBox:notice("请检查并刷新书架")
                end
            end)
        end
    end)
end

return M
