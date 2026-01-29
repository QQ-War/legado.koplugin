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
                    return Backend:cleanChapterCacheRange(book_cache_id, start, finish)
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

    local function prompt_clean_range_input()
        if not self.all_chapters_count then
            self.all_chapters_count = Backend:getChapterCount(book_cache_id)
        end
        local max_chapters = tonumber(self.all_chapters_count) or 0
        if max_chapters < 1 then
            MessageBox:notice("章节数为 0")
            return
        end
        local dialog
        dialog = MessageBox:input("", nil, {
            title = "输入清理范围",
            input = "",
            input_hint = "格式：起始章-结束章（如 5-20），或单章（如 12）",
            buttons = {{{
                text = "清理",
                is_enter_default = true,
                callback = function()
                    local text = dialog:getInputText()
                    if not H.is_str(text) or text == "" then
                        return
                    end
                    local s, e = parse_range_input(text, max_chapters)
                    if not s then
                        MessageBox:notice("范围格式错误")
                        return
                    end
                    UIManager:close(dialog)
                    prompt_clean_range(s - 1, e - 1)
                end
            }, {
                text = "取消",
                id = "close",
                callback = function()
                    UIManager:close(dialog)
                end
            }}}
        })
    end

    local function prompt_cache_forward(count)
        if not H.is_num(count) or count < 1 then
            return
        end
        if not self.all_chapters_count then
            self.all_chapters_count = Backend:getChapterCount(book_cache_id)
        end
        local max_chapters = tonumber(self.all_chapters_count) or 0
        if max_chapters < 1 then
            MessageBox:notice("章节数为 0")
            return
        end
        local start_index = chapters_index + 1
        local target_count = math.min(max_chapters, chapters_index + count + 1)
        local export = require("Legado/ExportDialog"):new({ bookinfo = self.bookinfo })
        export:cacheSelectedChapters(start_index, target_count - start_index, function()
            self:refreshItems(true)
        end)
    end

    local function prompt_cache_range_input()
        if not self.all_chapters_count then
            self.all_chapters_count = Backend:getChapterCount(book_cache_id)
        end
        local max_chapters = tonumber(self.all_chapters_count) or 0
        if max_chapters < 1 then
            MessageBox:notice("章节数为 0")
            return
        end
        local dialog
        dialog = MessageBox:input("", nil, {
            title = "输入缓存范围",
            input = "",
            input_hint = "格式：起始章-结束章（如 5-20），或单章（如 12）",
            buttons = {{{
                text = "开始",
                is_enter_default = true,
                callback = function()
                    local text = dialog:getInputText()
                    if not H.is_str(text) or text == "" then
                        return
                    end
                    local s, e = parse_range_input(text, max_chapters)
                    if not s then
                        MessageBox:notice("范围格式错误")
                        return
                    end
                    UIManager:close(dialog)
                    local start_index = s - 1
                    local end_index = e - 1
                    local export = require("Legado/ExportDialog"):new({ bookinfo = self.bookinfo })
                    export:cacheSelectedChapters(start_index, end_index - start_index + 1, function()
                        self:refreshItems(true)
                    end)
                end
            }, {
                text = "取消",
                id = "close",
                callback = function()
                    UIManager:close(dialog)
                end
            }}}
        })
    end

    local function prompt_cache_forward_input()
        if not self.all_chapters_count then
            self.all_chapters_count = Backend:getChapterCount(book_cache_id)
        end
        local max_chapters = tonumber(self.all_chapters_count) or 0
        if max_chapters < 1 then
            MessageBox:notice("章节数为 0")
            return
        end
        local dialog
        dialog = MessageBox:input("", nil, {
            title = "向后缓存章节数",
            input = "",
            input_hint = "输入数字，例如 10",
            buttons = {{{
                text = "开始",
                is_enter_default = true,
                callback = function()
                    local text = dialog:getInputText()
                    local n = tonumber(text)
                    if not n or n < 1 then
                        MessageBox:notice("请输入有效数字")
                        return
                    end
                    UIManager:close(dialog)
                    prompt_cache_forward(n)
                end
            }, {
                text = "取消",
                id = "close",
                callback = function()
                    UIManager:close(dialog)
                end
            }}}
        })
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
                prompt_clean_range_input()
            end
        }
    }, {
        {
            text = table.concat({Icons.FA_DOWNLOAD, " 向后缓存"}),
            callback = function()
                UIManager:close(dialog)
                prompt_cache_forward_input()
            end
        },
        {
            text = table.concat({Icons.FA_DOWNLOAD, " 缓存区间"}),
            callback = function()
                UIManager:close(dialog)
                prompt_cache_range_input()
            end
        }
    }, {
        {
            text = table.concat({Icons.FA_DOWNLOAD, " 缓存 +5 章"}),
            callback = function()
                UIManager:close(dialog)
                prompt_cache_forward(5)
            end
        },
        {
            text = table.concat({Icons.FA_DOWNLOAD, " 缓存 +10 章"}),
            callback = function()
                UIManager:close(dialog)
                prompt_cache_forward(10)
            end
        },
        {
            text = table.concat({Icons.FA_DOWNLOAD, " 缓存 +20 章"}),
            callback = function()
                UIManager:close(dialog)
                prompt_cache_forward(20)
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

function M:getStreamModeItem(on_close_callback, on_changed_callback)
    if not (self.bookinfo and H.is_str(self.bookinfo.cache_id)) then
        return nil
    end
    if self.bookinfo.cacheExt ~= 'cbz' then
        return nil
    end

    local function is_stream_image_mode()
        local extras_settings = Backend:getBookExtras(self.bookinfo.cache_id)
        return H.is_tbl(extras_settings.data) and extras_settings.data.stream_image_view == true
    end

    return {{
        text = Icons.FA_IMAGE .. " 流式漫画模式",
        keep_menu_open = true,
        help_text = "在线获取内容",
        callback = function()
            local extras_settings = Backend:getBookExtras(self.bookinfo.cache_id)
            if not H.is_tbl(extras_settings) then
                MessageBox:notice("设置读取失败")
                return
            end
            local new_state = not is_stream_image_mode()
            extras_settings:saveSetting("stream_image_view", new_state):flush()
            if H.is_func(on_close_callback) then
                pcall(on_close_callback)
            end
            if H.is_func(on_changed_callback) then
                pcall(on_changed_callback, new_state)
            end
            MessageBox:notice(new_state and "已开启流式漫画" or "已关闭流式漫画")
        end,
        align = "left",
    }}
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

    local Notification = require("ui/widget/notification")
    Notification:notify("正在刷新目录...", Notification.SOURCE_ALWAYS_SHOW)

    Backend:launchProcess(function()
        return Backend:refreshChaptersCache({
            cache_id = self.bookinfo.cache_id,
            bookUrl = self.bookinfo.bookUrl,
            origin = self.bookinfo.origin,
            name = self.bookinfo.name,
        }, self._ui_refresh_time)
    end, function(status, response, r2)
        if status == true then
            Backend:HandleResponse(response, function(data)
                Notification:notify("目录刷新完成", Notification.SOURCE_ALWAYS_SHOW)
                self:refreshItems(nil, true)
                self.all_chapters_count = nil
                self._ui_refresh_time = os.time()
            end, function(err_msg)
                MessageBox:notice(err_msg or '同步失败')
                if err_msg ~= '处理中' then
                    MessageBox:notice("请检查并刷新书架")
                end
            end)
        else
            MessageBox:error(tostring(response or r2 or "刷新任务失败"))
        end
    end)
end

function M:showReaderUI(chapter)
    if H.is_func(self.on_show_chapter_callback) then
        self.on_show_chapter_callback(chapter)
    end
end

function M:syncProgressShow(chapter)
    local Notification = require("ui/widget/notification")
    Notification:notify("正在同步阅读进度...", Notification.SOURCE_ALWAYS_SHOW)

    Backend:launchProcess(function()
        if H.is_tbl(chapter) and H.is_num(chapter.chapters_index) then
            return Backend:saveBookProgress(chapter)
        end
    end, function(status, response, r2)
        if status == true then
            Backend:HandleResponse(response, function(data)
                Notification:notify("进度同步成功", Notification.SOURCE_ALWAYS_SHOW)
                if H.is_tbl(chapter) and H.is_num(chapter.chapters_index) then
                    self:refreshItems(true)
                    self:switchItemTable(nil, self.item_table, chapter.chapters_index)
                end
            end, function(err_msg)
                MessageBox:notice(err_msg or '同步失败')
            end)
        else
            MessageBox:error(tostring(response or r2 or "同步任务失败"))
        end
    end)
end

return M
