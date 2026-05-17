-- 2-dropbox-sync-action.lua
--
-- KOReader user patch: adds a Dispatcher action that triggers Dropbox
-- folder synchronization directly, without having to navigate into the
-- Cloud storage menu and long-press the account.
--
-- Once installed, the action "Synchronize Dropbox (patch)" appears under:
--   * Profiles → Manage actions → General
--   * Taps and gestures → General (touch devices)
--   * Keyboard shortcuts → General (Kindle 4 and other non-touch devices)
--
-- For automatic sync at every KOReader startup:
--   1. Top menu → Tools → Profiles → New → give it a name
--   2. Open the profile → Manage actions → add:
--        - Turn Wi-Fi on
--        - Synchronize Dropbox (patch)
--   3. Same profile → Auto-execute → "When KOReader starts"
--
-- Installation:
--   1. Drop this file into <koreader-folder>/patches/
--   2. Restart KOReader
--   3. Top menu → Tools → More tools → Patch management → make sure
--      the patch is enabled
--
-- Prerequisites:
--   You must have already configured Dropbox under Cloud storage and set
--   up "Synchronize settings" on the account (Dropbox folder + local
--   folder). Without that, the action will show a "no account configured"
--   message and exit.
--
-- Tested on: KOReader 2026.03
-- On older/newer versions the internal function names may differ. The
-- patch tries known variants before giving up; check koreader.log if
-- the action does nothing.

local Dispatcher  = require("dispatcher")
local UIManager   = require("ui/uimanager")
local LuaSettings = require("luasettings")
local DataStorage = require("datastorage")
local InfoMessage = require("ui/widget/infomessage")
local _           = require("gettext")
local logger      = require("logger")

-- Register the action in the Dispatcher. It shows up in the "General" category.
Dispatcher:registerAction("user_dropbox_sync", {
    category = "none",
    event    = "UserDropboxSync",
    title    = _("Synchronize Dropbox (patch)"),
    general  = true,
})

-- Reads cloudstorage.lua and returns the first Dropbox account that has
-- sync folders configured (both sync_source_folder and sync_dest_folder).
local function findDropboxSyncAccount()
    local path = DataStorage:getSettingsDir() .. "/cloudstorage.lua"
    local ok, settings = pcall(LuaSettings.open, LuaSettings, path)
    if not ok or not settings then return nil end

    local servers = settings:readSetting("cs_servers")
    if not servers then return nil end

    for _, srv in ipairs(servers) do
        if srv.type == "dropbox"
           and srv.sync_source_folder
           and srv.sync_dest_folder then
            return srv
        end
    end
    return nil
end

-- Trigger the sync by calling the same code path used by the
-- "Synchronize now" long-press menu item.
local function performSync()
    local item = findDropboxSyncAccount()
    if not item then
        UIManager:show(InfoMessage:new{
            text = _("No Dropbox account with synchronization configured.\n\nOpen Top menu → Tools → Cloud storage, long-press your Dropbox account and set up 'Synchronize settings' first."),
        })
        return
    end

    local CloudStorage = require("apps/cloudstorage/cloudstorage")
    local cs = CloudStorage:new{}

    -- Hook downloadListFiles so that when the download phase finishes we
    -- refresh the file browser to make the freshly-downloaded files visible.
    -- We can't do this after calling synchronizeCloud directly: that function
    -- runs inside a Trapper:wrap coroutine and returns immediately, before
    -- the actual download has happened.
    local orig_download = cs.downloadListFiles
    if orig_download then
        cs.downloadListFiles = function(self_cs, sync_item)
            local downloaded_files, failed_files = orig_download(self_cs, sync_item)
            -- Small delay so the original "Successfully downloaded N files"
            -- InfoMessage shows up first, then we refresh underneath it.
            UIManager:scheduleIn(0.3, function()
                local FileManager = require("apps/filemanager/filemanager")
                local fm = FileManager.instance
                if fm and fm.file_chooser then
                    fm.file_chooser:refreshPath()
                    logger.info("[user-patch] dropbox-sync: file browser refreshed")
                end
            end)
            return downloaded_files, failed_files
        end
    end

    -- In KOReader 2026.x the function is named synchronizeCloud(item).
    -- Older/newer-version variants are tried as fallbacks.
    -- synchronizeCloud handles Wi-Fi waiting internally via
    -- NetworkMgr:willRerunWhenOnline, so we don't need to do it here.
    local sync_fn = cs.synchronizeCloud
                 or cs.synchronizeCloudStorage
                 or cs.synchronize
    if not sync_fn then
        UIManager:show(InfoMessage:new{
            text = _("Sync function not found in this KOReader version. The patch needs updating."),
        })
        logger.warn("[user-patch] dropbox-sync: no sync function found on CloudStorage")
        return
    end

    logger.info("[user-patch] dropbox-sync: starting sync for", item.name)
    sync_fn(cs, item)
end

-- Wire the event handler onto ReaderUI and FileManager, the two top-level
-- classes that always receive events broadcast by the Dispatcher.
local ReaderUI    = require("apps/reader/readerui")
local FileManager = require("apps/filemanager/filemanager")

local function attachHandler(class)
    if class.onUserDropboxSync then return end
    class.onUserDropboxSync = function(self)
        performSync()
        return true
    end
end

attachHandler(ReaderUI)
attachHandler(FileManager)

logger.info("[user-patch] dropbox-sync-action: loaded")
