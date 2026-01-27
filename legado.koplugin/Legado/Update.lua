local logger = require("logger")
local util = require("util")
local makeRequest = require("Legado.HttpRequest")
local H = require("Legado/Helper")
local MessageBox = require("Legado/MessageBox")
local LuaSettings = require("luasettings")

local M = {}

local RELEASE_API = "https://api.github.com/repos/QQ-War/legado.koplugin/releases/tags/ci-build-main"
local RELEASE_API_PATH = "/repos/QQ-War/legado.koplugin/releases/tags/ci-build-main"

local function get_ota_mirrors()
    local settings = LuaSettings:open(H.getUserSettingsPath())
    local data = settings and settings.data or {}
    return data.ota_api_mirror, data.ota_dl_mirror, data.ota_obj_mirror, data.ota_use_mirror
end

local function normalize_prefix(prefix)
    if not H.is_str(prefix) then
        return nil
    end
    return prefix:gsub("/+$", "")
end

local function join_prefix(prefix, path)
    prefix = normalize_prefix(prefix)
    if not (H.is_str(prefix) and prefix ~= "" and H.is_str(path)) then
        return nil
    end
    return prefix .. path
end

local function to_mirror_download(url, mirror_prefix, obj_prefix)
    if not H.is_str(url) then
        return url
    end
    mirror_prefix = normalize_prefix(mirror_prefix)
    obj_prefix = normalize_prefix(obj_prefix)

    if H.is_str(obj_prefix) and obj_prefix ~= ""
        and url:find("^https?://objects%.githubusercontent%.com/") then
        local path = url:gsub("^https?://objects%.githubusercontent%.com", "")
        return obj_prefix .. path
    end

    if H.is_str(mirror_prefix) and mirror_prefix ~= ""
        and url:find("^https?://github%.com/") then
        local path = url:gsub("^https?://github%.com", "")
        return mirror_prefix .. path
    end

    return url
end

local function resolve_api_url(api_mirror)
    api_mirror = normalize_prefix(api_mirror)
    if not (H.is_str(api_mirror) and api_mirror ~= "") then
        return nil
    end
    if api_mirror:find("/repos/") then
        return api_mirror
    end
    return join_prefix(api_mirror, RELEASE_API_PATH)
end

function M:_getUpdateSettings()
    return LuaSettings:open(H.getUserSettingsPath())
end

function M:getInstalledReleaseStamp()
    local settings = self:_getUpdateSettings()
    return settings and settings:readSetting("installed_release_stamp")
end

function M:saveInstalledReleaseStamp(stamp)
    if not H.is_str(stamp) then
        return
    end
    local settings = self:_getUpdateSettings()
    if settings then
        settings:saveSetting("installed_release_stamp", stamp):flush()
    end
end

function M:getPluginMetaInfo()
    local result, err_msg= H.require("_meta")
    if not result then
        logger.warn(string.format("getPluginMetaInfo load %s/_meta.lua err", plugin_path))
        return
    end
    return result
end

function M:getCurrentPluginVersion()
    local meta_info = self:getPluginMetaInfo()
    if H.is_tbl(meta_info) then
        return meta_info.version
    end
end

function M:checkUpdate()
    local current_version = self:getCurrentPluginVersion()
    local latest_release_info = self:_getLatestReleaseInfo()
    if not (current_version and H.is_tbl(latest_release_info) and latest_release_info.latest_version) then
        return {
            error = "获取版本信息失败"
        }
    end
    local latest_release_version = latest_release_info.latest_version
    local latest_stamp = latest_release_info.updated_at or latest_release_info.published_at
    local installed_stamp = self:getInstalledReleaseStamp()
    local should_update = false

    -- Use the version we fetched
    local is_standard_version = string.match(latest_release_version, "^[%d%.]+$")

    if H.is_str(installed_stamp) and H.is_str(latest_stamp) then
        -- If we have an OTA record, trust the timestamp string from GitHub API
        should_update = installed_stamp ~= latest_stamp
    elseif is_standard_version then
        -- Compare version strings (which now include timestamps for CI builds)
        should_update = (current_version ~= latest_release_version)
    else
        -- Last resort fallback
        should_update = (current_version ~= latest_release_version)
    end

    return {
        state = should_update,
        info = latest_release_info,
        release_version = latest_release_version,
        current_version = current_version
    }
end

function M:ota(ok_callback)
    local install_ota = function(zip_path, release_info)
        local update_response = self:_installUpdate(zip_path)
        if update_response == true then
            if H.is_tbl(release_info) then
                local stamp = release_info.updated_at or release_info.published_at
                if H.is_str(stamp) then
                    self:saveInstalledReleaseStamp(stamp)
                end
            end
            MessageBox:askForRestart("Updated. Restart KOReader for changes to apply.")
            if util.fileExists(zip_path) then
                pcall(os.remove, zip_path)
            end
            if H.is_func(ok_callback) then
                ok_callback()
            end
        else
            local err_msg = H.is_str(update_response) and update_response or "更新失败, 请重试"
            MessageBox:error(err_msg)
        end
    end

    MessageBox:loading("检查更新", function()
        return self:checkUpdate()
    end, function(state, response)
        if state == true and response and response.state == true then
            MessageBox:confirm(string.format("有新版本可用: %s ,要下载并更新吗？",
                response.release_version), function(result)
                if result then
                    -- multi process Android unzip prompts no permission
                    MessageBox:loading("安装更新中", function()
                        return self:_downloadUpdate(response.info)
                    end, function(state, down_response)
                        if state == true and down_response and down_response.path then
                            install_ota(down_response.path, response.info)
                        else
                            local err_msg = (H.is_tbl(down_response) and down_response.error) or ""
                            MessageBox:error("下载失败，请重试:" .. tostring(err_msg))
                        end
                    end)

                end
            end, {
                ok_text = "升级",
                cancel_text = "稍后"
            })
        elseif H.is_tbl(response) then
            MessageBox:success(response.error or "已是最新版本")
        end
    end)
end

function M:_getLatestReleaseInfo()
    local function request_release(url)
        return makeRequest({
            url = url,
            timeout = 10,
            maxtime = 20,
            headers = {
                ["Accept"] = "application/vnd.github.v3+json"
            }
        })
    end

    local api_mirror, _, _, use_mirror = get_ota_mirrors()
    local ok, err
    if use_mirror == true then
        local api_url = resolve_api_url(api_mirror)
        if H.is_str(api_url) and api_url ~= "" then
            ok, err = request_release(api_url)
        else
            logger.warn("OTA 镜像开关已开启，但未配置 API 镜像地址")
            return
        end
    else
        ok, err = request_release(RELEASE_API)
        local api_url = resolve_api_url(api_mirror)
        if not ok and H.is_str(api_url) and api_url ~= "" then
            ok, err = request_release(api_url)
        end
    end
    if not (ok and H.is_tbl(err) and err.data) then
        logger.warn("获取版本失败：", err)
        return
    end

    local json = require("json")
    local success, data = pcall(json.decode, err.data, json.decode.simple)
    if not success then
        logger.warn("github 返回数据格式错误：", tostring(data))
        return
    end
    if not (type(data) == "table" and data.tag_name and data.assets and data.assets[1]) then
        logger.warn("获取版本数据错误：", err)
        return
    end

    local release_info = data
    local latest_version_tag = release_info.tag_name
    local assets = release_info.assets
    local normalized_latest_version = string.match(latest_version_tag, "v?([%d%.]+)")
    
    -- Try to get version from release body (injected by GitHub Action)
    if not normalized_latest_version and release_info.body then
        normalized_latest_version = string.match(release_info.body, "Latest version:[%s]*([%d%.]+)")
    end

    normalized_latest_version = normalized_latest_version or latest_version_tag

    local asset = assets[1]
    local download_url = asset.browser_download_url
    local asset_name = asset.name or "legado_plugin_update.zip"
    local updated_at = asset.updated_at or release_info.published_at
    return {
        asset_name = asset_name,
        download_url = download_url,
        latest_version = normalized_latest_version,
        tag_name = latest_version_tag,
        updated_at = updated_at,
        published_at = release_info.published_at
    }
end

function M:_downloadUpdate(release_info)

    if not (H.is_tbl(release_info) and release_info.asset_name and release_info.download_url) then
        return {
            error = "downloadUpdate: Parameter error"
        }
    end

    local function download_with_url(url, attempt)
        local asset_name = release_info.asset_name
        local temp_path_base = H.getTempDirectory()
        local temp_zip_path = string.format("%s/%s", temp_path_base, asset_name)

        if util.fileExists(temp_zip_path) then
            os.remove(temp_zip_path)
        end

        local file, err_open = io.open(temp_zip_path, "wb")
        if not file then
            return nil, {
                error = "downloadUpdate: io.open path error"
            }
        end

        local http_options = {
            url = url,
            method = "GET",
            file = file,
            timeout = 60,
            maxtime = 900,
            redirect = true,
        }

        local ok, err = makeRequest(http_options)
        if not ok then
            pcall(os.remove, temp_zip_path)
            return nil, {
                error = "Download network request failed: " .. tostring(err)
            }
        end

        return {
            state = true,
            path = temp_zip_path
        }
    end

    local url = release_info.download_url
    local _, dl_mirror, obj_mirror, use_mirror = get_ota_mirrors()
    local mirror_url = to_mirror_download(url, dl_mirror, obj_mirror)

    if use_mirror == true then
        if mirror_url ~= url then
            local result = download_with_url(mirror_url, 1)
            if result then
                return result
            end
            local retry = download_with_url(mirror_url, 2)
            if retry then
                return retry
            end
            return { error = "下载失败" }
        end
        return { error = "OTA 镜像未配置" }
    end

    local result, err = download_with_url(url, 1)
    if result then
        return result
    end

    local retry = download_with_url(url, 2)
    if retry then
        return retry
    end

    if mirror_url ~= url then
        local fallback = download_with_url(mirror_url, 1)
        if fallback then
            return fallback
        end
    end

    return err or { error = "下载失败" }
end

-- return true or err_string
function M:_installUpdate(update_zip_path)

    if not (H.is_str(update_zip_path) and util.fileExists(update_zip_path)) then
        return "下载更新文件错误，请重试"
    end

    local plugin_path = H.get_plugin_path()
    local temp_path_base = H.getTempDirectory()
    -- zip plugins/xxx
    local target_unzip_dir = H.getKoreaderDirectory()

    local update_zip_path_escaped = update_zip_path:gsub("'", "'\\''")
    local target_unzip_escaped = target_unzip_dir:gsub("'", "'\\''")

    local unzip_command = string.format("unzip -qqo '%s' -d '%s'", update_zip_path_escaped, target_unzip_escaped)
    logger.dbg("installUpdate - Executing: " .. unzip_command)
    local ret_code, err_code, err_msg_os = os.execute(unzip_command)
    if ret_code ~= 0 then
        if util.fileExists(update_zip_path) then
            os.remove(update_zip_path)
        end
        return string.format("Failed to unzip update, exit code %s", ret_code)
    end

    return true
end

return M
