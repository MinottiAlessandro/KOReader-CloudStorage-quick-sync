# KOReader Cloud Storage Quick Sync

A small KOReader user patch that adds a one-tap Dropbox sync action, so you don't have to dive into **Cloud storage → long-press account → Synchronize now** every time.

Once installed, a new action named **"Synchronize Dropbox (patch)"** appears under:

- Profiles → Manage actions → General
- Taps and gestures → General (touch devices)
- Keyboard shortcuts → General (Kindle 4 and other non-touch devices)

## Installation

1. Copy `2-sincronizza-dropbox.lua` into `<koreader-folder>/patches/`
2. Restart KOReader
3. Go to **Top menu → Tools → More tools → Patch management** and make sure the patch is enabled

## Prerequisites

You must have already:

- Configured a Dropbox account under **Cloud storage**
- Set up **Synchronize settings** on it (Dropbox folder + local folder)

Without those, the action will show a "no account configured" message and exit.

## Auto-sync on startup

To sync automatically every time KOReader starts:

1. **Top menu → Tools → Profiles → New** and give it a name
2. Open the profile → **Manage actions** → add:
   - *Turn Wi-Fi on*
   - *Synchronize Dropbox (patch)*
3. In the same profile → **Auto-execute → When KOReader starts**

## How it works

The patch registers a Dispatcher action that:

1. Reads `cloudstorage.lua` and finds the first Dropbox account with sync folders configured
2. Calls the same `synchronizeCloud` code path used by the long-press "Synchronize now" menu entry
3. Wi-Fi handling is delegated to KOReader's `NetworkMgr` (sync waits until the connection is up)
4. After the download finishes, the File Manager is refreshed so newly downloaded files appear right away

## Compatibility

Tested on **KOReader 2026.03**. On older or newer versions the internal function names may differ — the patch tries known variants (`synchronizeCloud`, `synchronizeCloudStorage`, `synchronize`) before giving up. If the action does nothing, check `koreader.log` for `[user-patch] dropbox-sync` entries.
