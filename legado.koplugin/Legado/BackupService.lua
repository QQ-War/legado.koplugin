local logger = require("logger")
local util = require("util")
local H = require("Legado/Helper")

local M = {}

function M.backupDbWithPreCheck(backend_ref)
    local temp_dir = H.getTempDirectory()
    local last_backup_db = H.joinPath(temp_dir, "bookinfo.db.bak")
    local bookinfo_db_path = H.joinPath(temp_dir, "bookinfo.db")

    if not util.fileExists(bookinfo_db_path) then
        logger.warn("legado plugin: source database file does not exist - " .. bookinfo_db_path)
        return false
    end

    local setting_data = backend_ref:getSettings()
    local last_backup_time = setting_data.last_backup_time or 0
    local has_backup = util.fileExists(last_backup_db)
    local needs_backup = not has_backup or (os.time() - last_backup_time > 86400)

    if not needs_backup then
        return true
    end

    -- 预检查数据库是否损坏
    local status, err = pcall(function()
        backend_ref.dbManager:getAllBooksByUI("") -- 简单查询测试
    end)
    if not status then
        logger.err("legado plugin: database pre-check failed - " .. tostring(err))
        return false
    end

    if has_backup then
        util.removeFile(last_backup_db)
    end
    H.copyFileFromTo(bookinfo_db_path, last_backup_db)
    logger.info("legado plugin: backup successful")
    setting_data.last_backup_time = os.time()
    backend_ref:saveSettings(setting_data)
    return true
end

return M
