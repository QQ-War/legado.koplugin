local logger = require("logger")
local util = require("util")
local dbg = require("dbg")
local H = require("Legado/Helper")

if not dbg.log then
    dbg.log = logger.dbg
end

local M = {}

-- 获取后台任务信息
function M.getBackgroundTaskInfo(backend_ref, chapter)
    if not backend_ref.task_pid_file or not util.fileExists(backend_ref.task_pid_file) then
        return false
    end
    
    local pid_data = backend_ref:getLuaConfig(backend_ref.task_pid_file).data
    if not (type(pid_data) == "table" and pid_data.pid) then
        return false
    end
    
    -- 检查进程是否还在运行 (Linux 环境)
    local pid_path = "/proc/" .. pid_data.pid
    if not util.directoryExists(pid_path) then
        util.removeFile(backend_ref.task_pid_file)
        return false
    end
    
    if chapter and type(chapter) == "table" then
        if pid_data.book_cache_id == chapter.book_cache_id then
            return pid_data
        else
            return false
        end
    end
    
    return pid_data
end

-- 添加任务到队列 (目前逻辑中主要是触发子进程下载)
function M.addTaskToQueue(backend_ref, options)
    -- 原有逻辑中这里通常是直接 fork 或者触发 background_task
    -- 我们将原有 downloadChaptersBackgroundTask 的启动逻辑整合进来
    error("TaskManager:addTaskToQueue not fully implemented yet - relies on backend shell execution")
end

return M
