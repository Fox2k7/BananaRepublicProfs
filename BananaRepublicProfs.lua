-- BananaRepublicProfs (BRP) v4.3.1 - German Localization Fixed!
-- FIXED: German profession names now properly mapped to English (Verzauberkunst → Enchanting)
-- NEW: Recipe-to-category mappings for ALL 7 professions (1,513 recipes total!)
-- NEW: Separate file BananaRepublicProfs_RecipeMaps.lua for all recipe mappings  
-- NEW: "Datenbank teilen" button to share all scanned professions with guild
-- FIXED: Enchanting scan works without itemID
-- Uses BRP_RecipeMaps[professionName][recipeName] = categoryName


-- Recipe maps loaded from BananaRepublicProfs_RecipeMaps.lua
-- Access via: BRP_RecipeMaps[professionName][recipeName] = categoryName

-- -------------------------
-- German → English Profession Name Mapping
-- -------------------------
local ProfessionNameMap = {
  -- German → English
  ["Alchemie"] = "Alchemy",
  ["Schmiedekunst"] = "Blacksmithing",
  ["Verzauberkunst"] = "Enchanting",
  ["Verzauberungskunst"] = "Enchanting",
  ["Ingenieurskunst"] = "Engineering",
  ["Juwelierskunst"] = "Jewelcrafting",
  ["Lederverarbeitung"] = "Leatherworking",
  ["Schneiderei"] = "Tailoring",
  -- English names stay the same
  ["Alchemy"] = "Alchemy",
  ["Blacksmithing"] = "Blacksmithing",
  ["Enchanting"] = "Enchanting",
  ["Engineering"] = "Engineering",
  ["Jewelcrafting"] = "Jewelcrafting",
  ["Leatherworking"] = "Leatherworking",
  ["Tailoring"] = "Tailoring",
}

-- Normalize profession name to English
local function normalizeProfessionName(profName)
  return ProfessionNameMap[profName] or profName
end

local ADDON_NAME = "BananaRepublicProfs"
local DB_NAME = "BRPDB"
local PREFIX = "BRP0"
local DEBUG = true

local tlen = table.getn
local LastScannedProf = nil

-- -------------------------
-- Utility
-- -------------------------
local function msg(text)
  DEFAULT_CHAT_FRAME:AddMessage("|cffffd200BRP:|r " .. text)
end

local function debug(text)
  if DEBUG then
    DEFAULT_CHAT_FRAME:AddMessage("|cff888888[BRP Debug]|r " .. text)
  end
end

local function now()
  return date("%Y-%m-%d %H:%M:%S")
end

local function playerName()
  return UnitName("player") or "Unknown"
end

local function ensureDB()
  if not _G[DB_NAME] then _G[DB_NAME] = {} end
  local db = _G[DB_NAME]
  if not db.guild then db.guild = {} end
  if not db.me then db.me = {} end
  if not db.me.profs then db.me.profs = {} end
  if not db.me.updated then db.me.updated = now() end
  if not db.settings then db.settings = {} end
  if db.settings.onlineOnly == nil then db.settings.onlineOnly = false end
  if not db.bank then db.bank = {} end  -- Bank inventory storage
  if not db.bankScanned then db.bankScanned = nil end  -- Last bank scan timestamp
  return db
end

-- STEP 2: Check if player is online
local function isPlayerOnline(name)
  if not name then return false end
  
  -- Request fresh guild roster data
  if GetNumGuildMembers then
    GuildRoster()
    local numGuildMembers = GetNumGuildMembers()
    if not numGuildMembers then return false end
    
    for i = 1, numGuildMembers do
      local guildName, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
      if guildName == name then
        return online == 1
      end
    end
  end
  
  return false
end

local function copyTable(t)
  local r = {}
  for k, v in pairs(t or {}) do r[k] = v end
  return r
end

local function norm(s)
  if not s then return "" end
  if type(s) ~= "string" then s = tostring(s) end
  return string.lower(s)
end

-- Safe timestamp parsing helper
local function parseTimestamp(timestamp)
  -- Accept epoch timestamps directly
  if type(timestamp) == "number" then
    return timestamp
  end

  if not timestamp then return nil end
  if type(timestamp) ~= "string" then return nil end

  -- trim spaces
  timestamp = string.gsub(timestamp, "^%s+", "")
  timestamp = string.gsub(timestamp, "%s+$", "")

  -- accept ISO-like "YYYY-MM-DDTHH:MM:SS"
  timestamp = string.gsub(timestamp, "T", " ")

  -- Vanilla Lua uses string.find with captures
  local _, _, year, month, day, hour, min, sec =
    string.find(timestamp, "^(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d):(%d%d)$")

  if not (year and month and day and hour and min and sec) then
    return nil
  end

  return time({
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = tonumber(hour),
    min = tonumber(min),
    sec = tonumber(sec)
  })
end

-- -------------------------
-- Protocol safety
-- -------------------------
local SEP = "~"

local function safe(str)
  if str == nil then return "" end
  if type(str) ~= "string" then str = tostring(str) end
  str = string.gsub(str, "~", "-")
  str = string.gsub(str, "\n", " ")
  str = string.gsub(str, "\r", "")
  return str
end

-- -------------------------
-- Send queue (throttle)
-- -------------------------
local SendQueue = {}
local SendThrottle = CreateFrame("Frame")
SendThrottle:Hide()

local function enqueueSend(chatType, payload)
  table.insert(SendQueue, { chatType = chatType, payload = payload })
  SendThrottle:Show()
end

SendThrottle:SetScript("OnUpdate", function()
  if tlen(SendQueue) == 0 then
    SendThrottle:Hide()
    return
  end
  local item = table.remove(SendQueue, 1)
  if SendAddonMessage then
    SendAddonMessage(PREFIX, item.payload, item.chatType)
  end
end)

-- -------------------------
-- Pending receive buffer
-- -------------------------
local Pending = {}

local function getPending(player, prof)
  if not Pending[player] then Pending[player] = {} end
  if not Pending[player][prof] then
    Pending[player][prof] = { total = 0, chunks = {}, rank = 0, maxRank = 0 }
  end
  return Pending[player][prof]
end

local function clearPending(player, prof)
  if Pending[player] then Pending[player][prof] = nil end
end

-- -------------------------
-- STEP 1 (Alternative): Cleanup old professions based on timestamp (5 days)
-- -------------------------
local function cleanupOldProfessions()
  -- Wrap in pcall to prevent crashes
  local success, err = pcall(function()
    local db = ensureDB()
    local currentTime = time()
    local maxAge = 14 * 24 * 60 * 60  -- 5 days in seconds
    
    local cleaned = 0
    
    for profName, profData in pairs(db.me.profs) do
      -- Safety checks
      if type(profData) == "table" and profData.scannedAt then
        local scanTime = parseTimestamp(profData.scannedAt)
        
        if scanTime then
          local age = currentTime - scanTime
          
          if age > maxAge then
            -- Older than 2 minutes - remove it
            db.me.profs[profName] = nil
            
            -- Update guild entry
            if db.guild[playerName()] and db.guild[playerName()].profs then
              db.guild[playerName()].profs[profName] = nil
            end
            
            msg("|cffff8800Gelöscht:|r " .. profName .. " (älter als 2 Minuten)")
            
            -- Broadcast deletion to guild
            local delMsg = "DEL" .. SEP .. safe(playerName()) .. SEP .. safe(profName)
            enqueueSend("GUILD", delMsg)
            
            cleaned = cleaned + 1
          end
        end
      end
    end
    
    if cleaned > 0 then
      debug("Cleanup: " .. cleaned .. " alte Berufe entfernt")
    end
  end)
  
  if not success then
    debug("Cleanup Fehler: " .. tostring(err))
  end
end

-- Cleanup old professions from ALL players (called on UI open only)
local function cleanupOldProfessionsFromAllPlayers()
  local db = ensureDB()
  local currentTime = time()
  local maxAge = 14 * 24 * 60 * 60  -- 14 Tage
  local cleaned = 0
  
  for player, data in pairs(db.guild) do
    if data.profs then
      for profName, profData in pairs(data.profs) do
        if type(profData) == "table" and profData.scannedAt then
          local scanTime = parseTimestamp(profData.scannedAt)
          
          if scanTime then
            local age = currentTime - scanTime
            if age > maxAge then
              -- Remove old profession from this player
              db.guild[player].profs[profName] = nil
              cleaned = cleaned + 1
              debug("UI-Cleanup: " .. player .. " - " .. profName .. " (Alter: " .. math.floor(age/60) .. " min)")
            end
          end
        end
      end
    end
  end
  
  if cleaned > 0 then
    debug("UI-Cleanup: " .. cleaned .. " alte Berufe von allen Spielern entfernt")
  end
end

-- -------------------------
-- Scan TradeSkill
-- -------------------------
local function scanCurrentTradeSkill()
  if not GetTradeSkillLine or not GetNumTradeSkills or not GetTradeSkillInfo then
    msg("TradeSkill API nicht verfügbar.")
    return
  end

  local profName, rank, maxRank = GetTradeSkillLine()
  if not profName or profName == "" then 
    debug("Kein Beruf geöffnet")
    return
  end

  -- IMPORTANT: Normalize profession name (German → English)
  local profNameOriginal = profName
  profName = normalizeProfessionName(profName)
  
  debug("Scanne Beruf: " .. profNameOriginal .. " → " .. profName)

  -- FIXED: Check if this is a DIFFERENT profession (not just if already scanned)
  if LastScannedProf and LastScannedProf == profName then
    debug("Beruf '" .. profName .. "' wurde bereits in dieser Session gescannt")
    return
  end
  
  LastScannedProf = profName

  local n = GetNumTradeSkills()
  if not n or n <= 0 then 
    debug("Keine Rezepte gefunden")
    return
  end

  local recipes = {}
  local currentHeader = nil

  for i = 1, n do
    local name, skillType = GetTradeSkillInfo(i)
    if name and skillType then
      if skillType == "header" then
        currentHeader = name
        debug("Header found: '" .. name .. "'")
        msg("|cffff8800Header:|r " .. name)  -- Show to user for debugging
      else
        -- Get item link to extract item ID (optional for Enchanting)
        local itemLink = GetTradeSkillItemLink(i)
        local itemID = nil
        local iconTexture = nil
        
        if itemLink then
          -- Extract item ID from link: |Hitem:12345:0:0:0|h
          local _, _, id = string.find(itemLink, "item:(%d+)")
          if id then
            itemID = tonumber(id)
            debug("Recipe: " .. name .. " -> Item ID: " .. itemID)
          end
        else
          debug("Recipe: " .. name .. " -> No item link (Enchanting?)")
        end
        
        -- Get icon texture directly from tradeskill window
        iconTexture = GetTradeSkillIcon(i)
        
        local reagents = {}
        local numReagents = GetTradeSkillNumReagents and GetTradeSkillNumReagents(i)
        if numReagents and numReagents > 0 then
          for r = 1, numReagents do
            local rName, _, rCount = GetTradeSkillReagentInfo(i, r)
            if rName and rName ~= "" and rCount then
              table.insert(reagents, { name = rName, count = rCount })
            end
          end
        end

        table.insert(recipes, {
          name = name,
          header = currentHeader,
          reagents = reagents,
          itemID = itemID,  -- May be nil for Enchanting
          icon = iconTexture,
        })
        debug("  Recipe: '" .. name .. "' -> Header: '" .. (currentHeader or "NONE") .. "'")
      end
    end
  end

  local db = ensureDB()
  db.me.profs[profName] = {
    rank = rank or 0,
    maxRank = maxRank or 0,
    recipes = recipes,
    scannedAt = now(),
  }
  db.me.updated = now()

  db.guild[playerName()] = { updated = db.me.updated, profs = copyTable(db.me.profs) }

  msg("Gescannt: |cff00ff00" .. profName .. "|r (" .. (rank or 0) .. "/" .. (maxRank or 0) .. ") — Rezepte: " .. tostring(tlen(recipes)))

  -- STEP 1: Cleanup old professions after scan
  cleanupOldProfessions()

  local gname = GetGuildInfo and GetGuildInfo("player")
  if gname and gname ~= "" then
    BRP_BroadcastProfession(profName)
  end
end

local function scanCurrentCraft()
  if not GetCraftDisplaySkillLine or not GetNumCrafts or not GetCraftInfo then
    debug("Craft API nicht verfügbar.")
    return
  end

  local profName, rank, maxRank = GetCraftDisplaySkillLine()
  if not profName or profName == "" then
    debug("Kein Craft-Beruf geöffnet")
    return
  end

  local profNameOriginal = profName
  profName = normalizeProfessionName(profName)

  local n = GetNumCrafts()
  if not n or n <= 0 then
    debug("Craft: Keine Rezepte gefunden")
    return
  end

  debug("Scanne Craft: " .. profNameOriginal .. " → " .. profName .. " (Anzahl: " .. n .. ")")

  local recipes = {}
  local currentHeader = nil

  for i = 1, n do
    local name, craftType = GetCraftInfo(i)
    if name and craftType then
      if craftType == "header" then
        currentHeader = name
        debug("Craft Header: '" .. name .. "'")
      else
        local iconTexture = GetCraftIcon and GetCraftIcon(i)

        -- ItemLink/ID ist bei Enchanting oft nil – also NICHT nötig machen
        local itemLink = GetCraftItemLink and GetCraftItemLink(i)
        local itemID = nil
        if itemLink then
          local _, _, id = string.find(itemLink, "item:(%d+)")
          if id then itemID = tonumber(id) end
        end

        local reagents = {}
        local numReagents = GetCraftNumReagents and GetCraftNumReagents(i)
        if numReagents and numReagents > 0 then
          for r = 1, numReagents do
            local rName, _, rCount = GetCraftReagentInfo(i, r)
            if rName and rName ~= "" and rCount then
              table.insert(reagents, { name = rName, count = rCount })
            end
          end
        end

        table.insert(recipes, {
          name = name,
          header = currentHeader,
          reagents = reagents,
          itemID = itemID,     -- kann nil sein
          icon = iconTexture,  -- kann nil sein
        })
      end
    end
  end

  local db = ensureDB()
  db.me.profs[profName] = {
    rank = rank or 0,
    maxRank = maxRank or 0,
    recipes = recipes,
    scannedAt = now(),
  }
  db.me.updated = now()
  db.guild[playerName()] = { updated = db.me.updated, profs = copyTable(db.me.profs) }

  msg("Gescannt: |cff00ff00" .. profName .. "|r (" .. (rank or 0) .. "/" .. (maxRank or 0) .. ") — Rezepte: " .. tostring(tlen(recipes)))

  cleanupOldProfessions()

  local gname = GetGuildInfo and GetGuildInfo("player")
  if gname and gname ~= "" then
    BRP_BroadcastProfession(profName)
  end
end


-- -------------------------
-- Broadcast
-- -------------------------
function BRP_BroadcastProfession(profName)
  local db = ensureDB()
  local entry = db.me.profs[profName]
  if not entry then return end

  local p = playerName()
  local rank = entry.rank or 0
  local maxRank = entry.maxRank or 0
  local recipes = entry.recipes or {}

  local recipeData = {}
  for i = 1, tlen(recipes) do
    local rec = recipes[i]
    local recStr = safe(rec.name or "")
    
    if rec.reagents and tlen(rec.reagents) > 0 then
      local reagentStr = ""
      for r = 1, tlen(rec.reagents) do
        local rg = rec.reagents[r]
        reagentStr = reagentStr .. rg.count .. "x" .. safe(rg.name) .. ";"
      end
      recStr = recStr .. "#" .. reagentStr
    end
    
    -- Add item ID at the end (if available)
    if rec.itemID then
      recStr = recStr .. "#" .. tostring(rec.itemID)
    end
    
    -- Add icon texture (if available)
    if rec.icon then
      recStr = recStr .. "#" .. safe(rec.icon)
    end
    
    table.insert(recipeData, recStr)
  end

  local chunks = {}
  local buf = ""
  
  for i = 1, tlen(recipeData) do
    local line = recipeData[i] .. "\n"
    if string.len(buf .. line) > 200 then
      table.insert(chunks, buf)
      buf = line
    else
      buf = buf .. line
    end
  end
  
  if string.len(buf) > 0 then
    table.insert(chunks, buf)
  end

  local total = tlen(chunks)
  
  local startMsg = "S" .. SEP .. safe(p) .. SEP .. safe(profName) .. SEP .. tostring(rank) .. SEP .. tostring(maxRank) .. SEP .. tostring(total)
  enqueueSend("GUILD", startMsg)

  for idx = 1, total do
    local chunkMsg = "C" .. SEP .. safe(p) .. SEP .. safe(profName) .. SEP .. tostring(idx) .. SEP .. chunks[idx]
    enqueueSend("GUILD", chunkMsg)
  end

  local endMsg = "E" .. SEP .. safe(p) .. SEP .. safe(profName)
  enqueueSend("GUILD", endMsg)

  msg("Broadcast: " .. profName .. " (" .. total .. " chunks)")
end

-- Wrapper to send a profession even if not currently open
function BRP_SendAllRecipesForProfession(profName)
  BRP_BroadcastProfession(profName)
end

local function broadcastAll()
  local db = ensureDB()
  local count = 0
  for profName, _ in pairs(db.me.profs) do
    BRP_BroadcastProfession(profName)
    count = count + 1
  end
  if count > 0 then
    msg("Sende " .. count .. " Beruf(e)...")
  else
    msg("Keine Berufe. /brp scan")
  end
end

-- -------------------------
-- Receive (STEP 1: Added DELETE handling)
-- -------------------------
local function handleAddonMessage(prefix, text, distrib, sender)
  if prefix ~= PREFIX then return end
  if sender == playerName() then return end

  local parts = {}
  local idx = 1
  while idx <= string.len(text) do
    local nextSep = string.find(text, SEP, idx, true)
    if nextSep then
      table.insert(parts, string.sub(text, idx, nextSep - 1))
      idx = nextSep + 1
    else
      table.insert(parts, string.sub(text, idx))
      break
    end
  end

  if tlen(parts) < 1 then return end
  
  local cmd = parts[1]
  local db = ensureDB()

  -- STEP 1: Handle DELETE messages
  if cmd == "DEL" then
    if tlen(parts) >= 3 then
      local player = parts[2]
      local prof = parts[3]
      
      if db.guild[player] and db.guild[player].profs then
        db.guild[player].profs[prof] = nil
        msg("|cffff8800Empfangen:|r " .. player .. " hat " .. prof .. " verlernt")
        debug("DELETE: " .. player .. " - " .. prof)
        
        if BRP_UI and BRP_UI:IsShown() then
          BRP_UI_Refresh()
        end
      end
    end
    return
  end

  if cmd == "S" then
    if tlen(parts) >= 6 then
      local player = parts[2]
      local prof = parts[3]
      local rankS = parts[4]
      local maxS = parts[5]
      local totalS = parts[6]
      
      local pend = getPending(player, prof)
      pend.total = tonumber(totalS) or 0
      pend.rank = tonumber(rankS) or 0
      pend.maxRank = tonumber(maxS) or 0
      pend.chunks = {}
      debug("Start: " .. player .. " - " .. prof .. " (" .. pend.total .. " chunks)")
    end
    return
  end

  if cmd == "C" then
    if tlen(parts) >= 4 then
      local player = parts[2]
      local prof = parts[3]
      local idxS = parts[4]
      local chunk = parts[5] or ""
      
      local pend = getPending(player, prof)
      local chunkIdx = tonumber(idxS)
      if chunkIdx then
        pend.chunks[chunkIdx] = chunk
        debug("Chunk " .. chunkIdx .. "/" .. pend.total)
      end
    end
    return
  end

  if cmd == "E" then
    if tlen(parts) >= 3 then
      local player = parts[2]
      local prof = parts[3]
      
      local pend = getPending(player, prof)
      local total = pend.total or 0
      local got = 0
      for k, v in pairs(pend.chunks) do
        if v then got = got + 1 end
      end

      debug("Ende: " .. player .. " - " .. prof .. " (" .. got .. "/" .. total .. " chunks)")

      if got >= total and total > 0 then
        local full = ""
        for i = 1, total do
          if pend.chunks[i] then
            full = full .. pend.chunks[i]
          end
        end

        local recipes = {}
        local lineIdx = 1
        while lineIdx <= string.len(full) do
          local lineEnd = string.find(full, "\n", lineIdx)
          if lineEnd then
            local line = string.sub(full, lineIdx, lineEnd - 1)
            if line and line ~= "" then
              local recipeName = line
              local reagents = {}
              local itemID = nil
              local iconTexture = nil
              
              -- Format: RecipeName#reagents;#itemID#iconTexture
              local firstSep = string.find(line, "#", 1, true)
              if firstSep then
                recipeName = string.sub(line, 1, firstSep - 1)
                local remainder = string.sub(line, firstSep + 1)
                
                -- Check for second # (item ID / icon)
                local secondSep = string.find(remainder, "#", 1, true)
                local reagentPart = remainder
                
                if secondSep then
                  reagentPart = string.sub(remainder, 1, secondSep - 1)
                  local metaPart = string.sub(remainder, secondSep + 1)
                  
                  -- Check for third # (icon texture)
                  local thirdSep = string.find(metaPart, "#", 1, true)
                  if thirdSep then
                    local itemIDStr = string.sub(metaPart, 1, thirdSep - 1)
                    iconTexture = string.sub(metaPart, thirdSep + 1)
                    itemID = tonumber(itemIDStr)
                  else
                    -- Only item ID, no icon
                    itemID = tonumber(metaPart)
                  end
                end
                
                -- Parse reagents
                local rIdx = 1
                while rIdx <= string.len(reagentPart) do
                  local rEnd = string.find(reagentPart, ";", rIdx, true)
                  if rEnd then
                    local rStr = string.sub(reagentPart, rIdx, rEnd - 1)
                    local xPos = string.find(rStr, "x", 1, true)
                    if xPos then
                      local count = tonumber(string.sub(rStr, 1, xPos - 1))
                      local name = string.sub(rStr, xPos + 1)
                      if count and name then
                        table.insert(reagents, { count = count, name = name })
                      end
                    end
                    rIdx = rEnd + 1
                  else
                    break
                  end
                end
              end
              
              table.insert(recipes, { 
                name = recipeName, 
                header = nil, 
                reagents = reagents,
                itemID = itemID,  -- Store item ID
                icon = iconTexture  -- Store icon texture
              })
            end
            lineIdx = lineEnd + 1
          else
            break
          end
        end

        if not db.guild[player] then
          db.guild[player] = { updated = now(), profs = {} }
        end
        db.guild[player].profs[prof] = {
          rank = pend.rank,
          maxRank = pend.maxRank,
          recipes = recipes,
          scannedAt = now(),
        }
        db.guild[player].updated = now()

        msg("Empfangen: " .. player .. " — " .. prof .. " (" .. tlen(recipes) .. " Rezepte)")

        if BRP_UI and BRP_UI:IsShown() then
          BRP_UI_Refresh()
        end
      end

      clearPending(player, prof)
    end
    return
  end
end

-- -------------------------
-- UI: Data & Filter
-- -------------------------
local UI_Search = ""
local UI_FilterProf = "ALL"
local UI_EnchantSlot = "ALL"  -- For Enchanting filter
local UI_ScrollOffset = 0
local UI_CurrentTab = 1  -- Tab system: 1 = Rezepte, 2 = Admin
local BRP_VISIBLE_ROWS = 12
local BRP_ROW_HEIGHT = 22

local function uiGetProfessionList()
  local db = ensureDB()
  local set = { ALL = true }
  for _, data in pairs(db.guild) do
    if data.profs then
      for pname, _ in pairs(data.profs) do
        set[pname] = true
      end
    end
  end
  local list = { "ALL" }
  for k, _ in pairs(set) do
    if k ~= "ALL" then
      table.insert(list, k)
    end
  end
  table.sort(list)
  return list
end

local function uiBuildData()
  local db = ensureDB()
  local recipeMap = {}  -- Map: recipeName -> list of crafters

  -- Build map of recipes to crafters
  for player, data in pairs(db.guild) do
    if data.profs then
      for profName, profData in pairs(data.profs) do
        if profData.recipes then
          for i = 1, tlen(profData.recipes) do
            local rec = profData.recipes[i]
            local rname = ""
            if type(rec) == "table" then
              rname = rec.name or ""
            else
              rname = rec or ""
            end
            
            -- Create unique key for recipe
            local key = profName .. ":" .. rname
            
            if not recipeMap[key] then
              recipeMap[key] = {
                recipe = rname,
                prof = profName,
                recipeData = rec,
                crafters = {}  -- List of players who can craft this
              }
            end
            
            -- Add crafter to list
            table.insert(recipeMap[key].crafters, {
              player = player,
              rank = profData.rank or 0,
              maxRank = profData.maxRank or 0,
              online = isPlayerOnline(player)
            })
          end
        end
      end
    end
  end
  
  -- Convert map to list
  local results = {}
  for key, data in pairs(recipeMap) do
    table.insert(results, data)
  end

  return results
end

local function uiFilterData(data)
  local filtered = {}
  local searchL = norm(UI_Search)

  for i = 1, tlen(data) do
    local row = data[i]
    
    -- Filter by profession
    local profMatch = (UI_FilterProf == "ALL") or (row.prof == UI_FilterProf)
    
    if profMatch then
      local searchMatch = false
      if searchL == "" then
        searchMatch = true
      else
        local rL = norm(row.recipe)
        if string.find(rL, searchL, 1, true) then
          searchMatch = true
        end
      end
      
      -- Subcategory filter
      local slotMatch = true
      if UI_EnchantSlot ~= "ALL" and UI_EnchantSlot ~= "" then
        -- Use recipe-to-category mapping (loaded from BRP_RecipeMaps)
        local recipeCategory = nil
        
        if BRP_RecipeMaps and BRP_RecipeMaps[row.prof] then
          recipeCategory = BRP_RecipeMaps[row.prof][row.recipe]
        end
        
        if recipeCategory and recipeCategory == UI_EnchantSlot then
          slotMatch = true
        else
          slotMatch = false
        end
      end
      
      -- Always show all recipes (no online filter)
      if searchMatch and slotMatch then
        table.insert(filtered, row)
      end
    end
  end

  return filtered
end

-- -------------------------
-- STEP 3: Inventory check for reagents (Bags + Bank)
-- -------------------------
local function getItemCountInBags(itemName)
  if not itemName or itemName == "" then return 0 end
  
  local total = 0
  local searchName = string.lower(itemName)
  
  -- Search all bags (0 = backpack, 1-4 = bags)
  for bag = 0, 4 do
    local numSlots = GetContainerNumSlots(bag)
    if numSlots then
      for slot = 1, numSlots do
        local itemLink = GetContainerItemLink(bag, slot)
        if itemLink then
          local _, _, name = string.find(itemLink, "%[(.+)%]")
          if name and string.lower(name) == searchName then
            local _, count = GetContainerItemInfo(bag, slot)
            if count then
              total = total + count
            end
          end
        end
      end
    end
  end
  
  return total
end

local function getItemCountInBank(itemName)
  if not itemName or itemName == "" then return 0 end
  
  local db = ensureDB()
  local searchName = string.lower(itemName)
  
  return db.bank[searchName] or 0
end

local function scanBank()
  local db = ensureDB()
  db.bank = {}  -- Clear old data
  
  -- Scan bank slots (bags -1, 5, 6, 7, 8, 9, 10, 11)
  -- Bag -1 is the main bank (28 slots)
  local bankBags = {-1, 5, 6, 7, 8, 9, 10, 11}
  local itemCount = {}
  
  for _, bag in pairs(bankBags) do
    local numSlots = GetContainerNumSlots(bag)
    if numSlots and numSlots > 0 then
      for slot = 1, numSlots do
        local itemLink = GetContainerItemLink(bag, slot)
        if itemLink then
          local _, _, name = string.find(itemLink, "%[(.+)%]")
          if name then
            local _, count = GetContainerItemInfo(bag, slot)
            if count then
              local searchName = string.lower(name)
              if not itemCount[searchName] then
                itemCount[searchName] = 0
              end
              itemCount[searchName] = itemCount[searchName] + count
            end
          end
        end
      end
    end
  end
  
  db.bank = itemCount
  db.bankScanned = now()
  
  local totalItems = 0
  for k, v in pairs(itemCount) do
    totalItems = totalItems + 1
  end
  
  msg("Bank gescannt: " .. totalItems .. " verschiedene Items gefunden")
end

-- -------------------------
-- UI: Recipe Popup
-- -------------------------
local BRP_RecipePopup = nil
local BRP_RecipeQuantity = 1  -- Default quantity

function BRP_ShowRecipePopup(data)
  if not BRP_RecipePopup then
    local pop = CreateFrame("Frame", "BRP_RecipePopup", UIParent)
    BRP_RecipePopup = pop
    pop:SetWidth(400)  -- Wider for table layout
    pop:SetHeight(380)  -- Taller for editbox + summary
    pop:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    pop:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 32, edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    pop:SetMovable(true)
    pop:EnableMouse(true)
    pop:RegisterForDrag("LeftButton")
    pop:SetScript("OnDragStart", function() this:StartMoving() end)
    pop:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    pop:SetFrameStrata("DIALOG")

    local title = pop:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", pop, "TOP", 0, -18)
    pop.title = title

    -- Recipe icon (top right, centered between title and content)
    local icon = CreateFrame("Button", nil, pop)
    icon:SetWidth(40)
    icon:SetHeight(40)
    icon:SetPoint("TOPRIGHT", pop, "TOPRIGHT", -60, -32)  -- More right spacing (-60), lower position (-32)
    pop.icon = icon
    
    local iconTexture = icon:CreateTexture(nil, "ARTWORK")
    iconTexture:SetAllPoints(icon)
    iconTexture:SetTexture("Interface\\Icons\\Trade_Engineering")  -- Default icon
    pop.iconTexture = iconTexture
    
    -- Icon border
    local iconBorder = icon:CreateTexture(nil, "OVERLAY")
    iconBorder:SetAllPoints(icon)
    iconBorder:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    iconBorder:SetTexCoord(0.2, 0.8, 0.2, 0.8)
    
    -- Enable tooltip on hover
    icon:SetScript("OnEnter", function()
      if pop.currentRecipeName and type(pop.currentRecipeName) == "string" and string.len(pop.currentRecipeName) > 0 then
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        
        pcall(function()
          -- currentRecipeName is already in "item:12345" format if we have ID
          GameTooltip:SetHyperlink(pop.currentRecipeName)
          GameTooltip:Show()
        end)
      end
    end)
    
    icon:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)

    local close = CreateFrame("Button", nil, pop, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", pop, "TOPRIGHT", -6, -6)

    -- STEP 3: Quantity EditBox
    local qtyLabel = pop:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    qtyLabel:SetPoint("TOPLEFT", pop, "TOPLEFT", 22, -50)
    qtyLabel:SetText("Anzahl:")
    
    local qtyBox = CreateFrame("EditBox", "BRP_QuantityBox", pop, "InputBoxTemplate")
    qtyBox:SetWidth(60)
    qtyBox:SetHeight(20)
    qtyBox:SetPoint("LEFT", qtyLabel, "RIGHT", 10, 0)
    qtyBox:SetAutoFocus(false)
    qtyBox:SetNumeric(true)
    qtyBox:SetMaxLetters(3)
    qtyBox:SetText(tostring(BRP_RecipeQuantity))
    pop.qtyBox = qtyBox
    
    qtyBox:SetScript("OnEnterPressed", function() 
      this:ClearFocus()
      local qty = tonumber(this:GetText()) or 1
      if qty < 1 then qty = 1 end
      if qty > 100 then qty = 100 end
      BRP_RecipeQuantity = qty
      this:SetText(tostring(qty))
      -- Refresh display
      if pop.currentData then
        BRP_UpdateRecipePopupContent(pop, pop.currentData)
      end
    end)
    
    qtyBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)

    local scrollBg = CreateFrame("Frame", nil, pop)
    scrollBg:SetPoint("TOPLEFT", pop, "TOPLEFT", 18, -80)
    scrollBg:SetPoint("BOTTOMRIGHT", pop, "BOTTOMRIGHT", -38, 80)
    scrollBg:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    scrollBg:SetBackdropColor(0, 0, 0, 0.8)
    
    -- Banana Republic Logo (watermark)
    local logo = scrollBg:CreateTexture(nil, "BACKGROUND")
    logo:SetTexture("Interface\\AddOns\\BananaRepublicProfs\\BananaRepublicIcon")
    logo:SetWidth(256)  -- Much bigger!
    logo:SetHeight(256)
    logo:SetPoint("CENTER", scrollBg, "CENTER", 0, -20)
    logo:SetAlpha(0.25)  -- More visible (was 0.15)
    pop.logo = logo

    local scroll = CreateFrame("ScrollFrame", "BRP_RecipePopupScrollFrame", pop, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", scrollBg, "TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", scrollBg, "BOTTOMRIGHT", -28, 8)
    pop.scroll = scroll

    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(320)
    content:SetHeight(400)
    scroll:SetScrollChild(content)
    pop.content = content

    local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    text:SetWidth(320)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetFont("Fonts\\ARIALN.TTF", 13)  -- Use Arial Narrow for better alignment
    pop.text = text

    -- STEP 3: Missing summary
    local missingSummary = pop:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    missingSummary:SetPoint("BOTTOMLEFT", pop, "BOTTOMLEFT", 22, 50)
    missingSummary:SetPoint("BOTTOMRIGHT", pop, "BOTTOMRIGHT", -22, 50)
    missingSummary:SetJustifyH("LEFT")
    missingSummary:SetHeight(20)
    pop.missingSummary = missingSummary

    -- Whisper dropdown button (centered at bottom, no checkbox)
    local whisperBtn = CreateFrame("Button", nil, pop, "UIPanelButtonTemplate")
    whisperBtn:SetWidth(200)
    whisperBtn:SetHeight(24)
    whisperBtn:SetPoint("BOTTOM", pop, "BOTTOM", 0, 18)
    whisperBtn:SetText("Whisper...")
    pop.whisperBtn = whisperBtn
    
    whisperBtn:SetScript("OnClick", function()
      if not pop.currentData or not pop.currentData.crafters then return end
      
      -- Build menu with ONLY online crafters
      local menu = {}
      local hasOnline = false
      
      for i = 1, tlen(pop.currentData.crafters) do
        local crafter = pop.currentData.crafters[i]
        if crafter.online then
          hasOnline = true
          local info = {}
          info.text = crafter.player .. " (" .. crafter.rank .. "/" .. crafter.maxRank .. ")"
          info.notCheckable = true
          info.func = function()
            local editbox = DEFAULT_CHAT_FRAME.editBox or ChatFrameEditBox
            if editbox then
              editbox:SetText("/w " .. crafter.player .. " ")
              editbox:Show()
              editbox:SetFocus()
            end
          end
          table.insert(menu, info)
        end
      end
      
      -- If no one online, show banana message
      if not hasOnline then
        msg("|cffff8800Leider ist derzeit keine Banane Online die dir hier weiterhelfen kann! 🍌|r")
        return
      end
      
      -- Show dropdown menu with online crafters
      if tlen(menu) > 0 then
        local dropdown = CreateFrame("Frame", "BRP_WhisperMenu", pop, "UIDropDownMenuTemplate")
        UIDropDownMenu_Initialize(dropdown, function()
          for i = 1, tlen(menu) do
            UIDropDownMenu_AddButton(menu[i])
          end
        end, "MENU")
        ToggleDropDownMenu(1, nil, dropdown, whisperBtn, 0, 0)
      end
    end)

    pop:Hide()
  end

  local pop = BRP_RecipePopup
  pop.currentData = data
  pop.title:SetText(data.recipe or "Rezept")
  
  -- Use item ID if available (from recipeData)
  local itemID = nil
  local iconTexture = nil
  
  if data.recipeData then
    itemID = data.recipeData.itemID
    iconTexture = data.recipeData.icon
  end
  
  -- PRIORITY 1: Use stored icon texture (from scan) - NO CACHING!
  if iconTexture and type(iconTexture) == "string" and string.len(iconTexture) > 0 then
    pop.iconTexture:SetTexture(iconTexture)
    debug("Icon: Using stored texture: " .. iconTexture)
  -- PRIORITY 2: Try GetItemInfo WITHOUT caching
  elseif itemID then
    local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(itemID)
    
    if texture then
      pop.iconTexture:SetTexture(texture)
      debug("Icon: Loaded from ItemID: " .. tostring(itemID))
    else
      -- Fallback to profession icon - NO CACHING!
      local professionIcons = {
        ["Alchemy"] = "Interface\\Icons\\Trade_Alchemy",
        ["Blacksmithing"] = "Interface\\Icons\\Trade_BlackSmithing",
        ["Enchanting"] = "Interface\\Icons\\Trade_Engraving",
        ["Engineering"] = "Interface\\Icons\\Trade_Engineering",
        ["Leatherworking"] = "Interface\\Icons\\Trade_LeatherWorking",
        ["Tailoring"] = "Interface\\Icons\\Trade_Tailoring",
        ["Cooking"] = "Interface\\Icons\\INV_Misc_Food_15",
        ["First Aid"] = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
      }
      local iconPath = professionIcons[data.prof] or "Interface\\Icons\\INV_Misc_QuestionMark"
      pop.iconTexture:SetTexture(iconPath)
      debug("Icon: Fallback to profession icon")
    end
  else
    -- PRIORITY 3: Legacy - try by name WITHOUT caching
    local _, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(data.recipe)
    
    if itemTexture then
      pop.iconTexture:SetTexture(itemTexture)
      debug("Icon: Loaded from name: " .. (data.recipe or "nil"))
    else
      -- Fallback to profession icon
      local professionIcons = {
        ["Alchemy"] = "Interface\\Icons\\Trade_Alchemy",
        ["Blacksmithing"] = "Interface\\Icons\\Trade_BlackSmithing",
        ["Enchanting"] = "Interface\\Icons\\Trade_Engraving",
        ["Engineering"] = "Interface\\Icons\\Trade_Engineering",
        ["Leatherworking"] = "Interface\\Icons\\Trade_LeatherWorking",
        ["Tailoring"] = "Interface\\Icons\\Trade_Tailoring",
        ["Cooking"] = "Interface\\Icons\\INV_Misc_Food_15",
        ["First Aid"] = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
      }
      local iconPath = professionIcons[data.prof] or "Interface\\Icons\\INV_Misc_QuestionMark"
      pop.iconTexture:SetTexture(iconPath)
      debug("Icon: Fallback to profession icon (no name match)")
    end
  end
  
  -- Set tooltip item for hover
  if itemID then
    pop.currentRecipeName = "item:" .. tostring(itemID)
  else
    pop.currentRecipeName = data.recipe
  end
  
  -- Reset quantity box
  pop.qtyBox:SetText(tostring(BRP_RecipeQuantity))
  
  BRP_UpdateRecipePopupContent(pop, data)

  pop:Show()
end

-- STEP 3: Update popup content with inventory check first, then crafter list at bottom
function BRP_UpdateRecipePopupContent(pop, data)
  local qty = BRP_RecipeQuantity
  local db = ensureDB()
  
  local infoText = ""
  local missing = {}
  
  -- Show last bank scan
  if db.bankScanned then
    infoText = infoText .. "|cffaaaaaa(Bank: " .. db.bankScanned .. ")|r\n\n"
  end
  
  if type(data.recipeData) == "table" and data.recipeData.reagents then
    local reagents = data.recipeData.reagents
    if tlen(reagents) > 0 then
      infoText = infoText .. "|cffffff00Materialien (x" .. qty .. "):|r\n\n"
      infoText = infoText .. "|cffaaaaaa Benötigt:|r\n"
      
      -- First: Show all required items
      for i = 1, tlen(reagents) do
        local r = reagents[i]
        local needed = (r.count or 1) * qty
        infoText = infoText .. string.format("• %dx %s\n", needed, r.name or "?")
      end
      
      infoText = infoText .. "\n|cffaaaaaa Verfügbar (Bank):|r\n"
      
      -- Second: Show inventory for each item
      for i = 1, tlen(reagents) do
        local r = reagents[i]
        local needed = (r.count or 1) * qty
        local haveBags = getItemCountInBags(r.name or "")
        local haveBank = getItemCountInBank(r.name or "")
        local haveTotal = haveBags + haveBank
        
        local status = ""
        local haveColor = ""
        
        if haveTotal >= needed then
          status = " |cff00ff00✓|r"
          haveColor = "|cff00ff00"
        else
          status = " |cffff0000✗|r"
          haveColor = "|cffff0000"
          local missingCount = needed - haveTotal
          table.insert(missing, missingCount .. "x " .. (r.name or "?"))
        end
        
        -- Show: Name: Total (Bank only)
        local countStr = ""
        if haveBank > 0 then
          countStr = string.format("%d (%d)", haveTotal, haveBank)
        else
          countStr = tostring(haveTotal)
        end
        
        infoText = infoText .. "• " .. (r.name or "?") .. ": " .. haveColor .. countStr .. "|r" .. status .. "\n"
      end
    end
  end
  
  -- NOW: Add crafter list at the bottom
  infoText = infoText .. "\n|cffffff00━━━━━━━━━━━━━━━━━━━━━━|r\n"
  infoText = infoText .. "|cffffff00Kann hergestellt werden von:|r\n\n"
  
  if data.crafters and tlen(data.crafters) > 0 then
    -- Sort crafters: online first, then by name
    local sortedCrafters = {}
    for i = 1, tlen(data.crafters) do
      table.insert(sortedCrafters, data.crafters[i])
    end
    table.sort(sortedCrafters, function(a, b)
      if a.online ~= b.online then
        return a.online  -- online first
      end
      return a.player < b.player
    end)
    
    -- Display ALL crafters (online and offline)
    for i = 1, tlen(sortedCrafters) do
      local crafter = sortedCrafters[i]
      local statusColor = crafter.online and "|cff00ff00" or "|cff888888"
      local statusText = crafter.online and "Online" or "Offline"
      
      infoText = infoText .. "• " .. statusColor .. crafter.player .. "|r"
      infoText = infoText .. " |cffaaaaaa(" .. (data.prof or "") .. " " .. crafter.rank .. "/" .. crafter.maxRank .. ") " .. statusText .. "|r\n"
    end
  else
    infoText = infoText .. "|cffff0000Keine Hersteller gefunden|r\n"
  end

  pop.text:SetText(infoText)
  local textHeight = pop.text:GetHeight()
  pop.content:SetHeight(math.max(textHeight + 20, 400))
  
  -- Update missing summary
  if tlen(missing) > 0 then
    pop.missingSummary:SetText("|cffff0000Fehlen:|r " .. table.concat(missing, ", "))
  else
    pop.missingSummary:SetText("|cff00ff00Alle Materialien vorhanden!|r")
  end
end

-- -------------------------
-- UI: Refresh
-- -------------------------
function BRP_UI_Refresh()
  local f = BRP_UI
  if not f or not f:IsShown() then return end

  local allData = uiBuildData()
  local filtered = uiFilterData(allData)
  local totalItems = tlen(filtered)

  local sb = f.scrollbar
  if sb then
    local maxScroll = math.max(0, totalItems - f.visibleRows)
    sb:SetMinMaxValues(0, maxScroll)
    
    if UI_ScrollOffset > maxScroll then UI_ScrollOffset = maxScroll end
    if UI_ScrollOffset < 0 then UI_ScrollOffset = 0 end
    
    sb:SetValue(UI_ScrollOffset)
    
    if maxScroll > 0 then sb:Show() else sb:Hide() end
  end

  for i = 1, f.visibleRows do
    local row = f.rows[i]
    local dataIndex = UI_ScrollOffset + i

    if dataIndex <= totalItems then
      local data = filtered[dataIndex]
      
      -- Count online vs total crafters
      local onlineCount = 0
      local totalCount = tlen(data.crafters)
      
      for c = 1, totalCount do
        if data.crafters[c].online then
          onlineCount = onlineCount + 1
        end
      end
      
      -- Display recipe name
      row.recipe:SetText("|cffffffff" .. (data.recipe or ""))
      
      -- Display crafter info
      local crafterText = ""
      if onlineCount > 0 then
        crafterText = "|cff00ff00" .. onlineCount .. " Online|r"
      else
        crafterText = "|cff888888" .. totalCount .. " Offline|r"
      end
      
      if totalCount > 1 then
        crafterText = crafterText .. " |cffaaaaaa(" .. totalCount .. " Gesamt)|r"
      end
      
      crafterText = crafterText .. " |cff888888- " .. (data.prof or "") .. "|r"
      row.who:SetText(crafterText)
      
      row.data = data
      row:Show()
    else
      row:Hide()
    end
  end
end

-- -------------------------
-- UI: Create
-- -------------------------
local function uiCreate()
  if BRP_UI then return end

  local f = CreateFrame("Frame", "BRP_MainFrame", UIParent)
  BRP_UI = f
  f:SetWidth(520)
  f:SetHeight(460)  -- Increased from 420 to 460 for tabs
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", f, "TOP", 0, -18)
  title:SetText("BananaRepublicProfs — Craft-Suche")

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)

  -- STEP 4: Banana background image
  local banana = f:CreateTexture(nil, "BACKGROUND")
  banana:SetTexture("Interface\\Icons\\INV_Misc_Food_41")  -- Banana icon
  banana:SetPoint("CENTER", f, "CENTER", 0, 0)
  banana:SetWidth(256)
  banana:SetHeight(256)
  banana:SetAlpha(0.05)  -- Very transparent (5%)

  local searchLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  searchLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -62)
  searchLabel:SetText("Suche:")

  local search = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  search:SetWidth(180)  -- Made narrower to fit checkbox
  search:SetHeight(20)
  search:SetPoint("LEFT", searchLabel, "RIGHT", 10, 0)
  search:SetAutoFocus(false)
  search:SetScript("OnEnterPressed", function() this:ClearFocus() end)
  search:SetScript("OnTextChanged", function()
    UI_Search = this:GetText() or ""
    UI_ScrollOffset = 0
    BRP_UI_Refresh()
  end)

  local dd = CreateFrame("Frame", "BRP_FilterDropDown", f, "UIDropDownMenuTemplate")
  dd:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -54)
  f.filterDD = dd

  local function BRP_FilterDD_OnClick()
    UI_FilterProf = this.value or "ALL"
    UIDropDownMenu_SetSelectedValue(dd, UI_FilterProf)
    UIDropDownMenu_SetText(UI_FilterProf, dd)
    UI_ScrollOffset = 0
    
    -- Show/hide subcategory filter for professions with categories
    local profsWithSubs = {
      ["Enchanting"] = true,
      ["Leatherworking"] = true,
      ["Alchemy"] = true,
      ["Blacksmithing"] = true,
      ["Engineering"] = true,
      ["Jewelcrafting"] = true,
      ["Tailoring"] = true
    }
    
    if profsWithSubs[UI_FilterProf] then
      BRP_UI.subDD:Show()
      -- Reinitialize dropdown for new profession
      UIDropDownMenu_Initialize(BRP_UI.subDD, BRP_SubDD_Initialize)
      UI_EnchantSlot = "ALL"
      UIDropDownMenu_SetSelectedValue(BRP_UI.subDD, UI_EnchantSlot)
      UIDropDownMenu_SetText(UI_EnchantSlot, BRP_UI.subDD)
    else
      BRP_UI.subDD:Hide()
      UI_EnchantSlot = "ALL"  -- Reset subcategory filter
    end
    
    BRP_UI_Refresh()
  end

  local function BRP_FilterDD_Initialize()
    local list = uiGetProfessionList()
    local info
    for i = 1, tlen(list) do
      info = {}
      info.text = list[i]
      info.value = list[i]
      info.func = BRP_FilterDD_OnClick
      UIDropDownMenu_AddButton(info)
    end
  end

  UIDropDownMenu_Initialize(dd, BRP_FilterDD_Initialize)
  UIDropDownMenu_SetWidth(150, dd)
  UIDropDownMenu_SetSelectedValue(dd, UI_FilterProf)
  UIDropDownMenu_SetText(UI_FilterProf, dd)

  -- Subcategory Filter (visible for professions with categories)
  local subDD = CreateFrame("Frame", "BRP_SubcategoryDropDown", f, "UIDropDownMenuTemplate")
  subDD:SetPoint("TOPRIGHT", dd, "BOTTOMRIGHT", 0, 10)
  f.subDD = subDD
  subDD:Hide()  -- Hidden by default
  
  local function BRP_SubDD_OnClick()
    UI_EnchantSlot = this.value or "ALL"
    UIDropDownMenu_SetSelectedValue(subDD, UI_EnchantSlot)
    UIDropDownMenu_SetText(UI_EnchantSlot, subDD)
    UI_ScrollOffset = 0
    BRP_UI_Refresh()
  end
  
  local function BRP_SubDD_Initialize()
    -- Define subcategories for each profession
    -- IMPORTANT: These must match EXACT header names from WoW profession window!
    local categories = {
      ["Alchemy"] = {
        "ALL",
        "Flasks",
        "Protection Potions", 
        "Health and Mana Potions",
        "Transmutes",
        "Defensive Potions and Elixirs",
        "Offensive Potions and Elixirs",
        "Miscellaneous"
      },
      ["Enchanting"] = {
        "ALL",
        "Shield",
        "Misc",
        "Weapon",
        "2HWeapon",
        "Boots",
        "Glove",
        "Bracer",
        "Chest",
        "Cloak"
      },
      ["Tailoring"] = {
        "ALL",
        "Helm",
        "Shoulders",
        "Cloak",
        "Chest",
        "Bracers",
        " Gloves ",
        "Belt",
        "Pants ",
        "Boots",
        "Bags",
        "Shirt",
        "Misc"
      },
      ["Mining"] = {
        "ALL",
        "Smelting",
      },  
      ["Leatherworking"] = {
        "ALL",
        "Dragonscale",
        "Elemental",
        "Tribal",
        "Helm",
        "Shoulders",
        "Cloak",
        "Chest",
        "Chest",
        "Bracers",
        "Gloves",
        "Belt",
        "Pants",
        "Boots",
        "Bags",
        "Misc"
      },
      ["Blacksmithing"] = {
        "ALL",
        "Armorsmith",
        "Weaponsmith",
        "Axesmith",
        "Hammersmith",
        "Swordsmith",
        "Helm",
        "Shoulders",
        "Chest",
        "Bracers",
        "Gloves",
        "Belt",
        "Pants",
        "Boots",
        "Axes",
        "Swords",
        "Maces",
        "Fist",
        "Daggers",
        "Buckles",
        "Misc"
      },
      ["Engineering"] = {
        "ALL",
        "Gnomish",
        "Goblin",
        "Equipment",
        " Trinkets",
        "Explosives",
        "Weapons",
        "Parts",
        "Misc"
      },
      ["Jewelcrafting"] = {
        "ALL",
        "Gemology",
        "Goldsmithing",
        "Gemstones",
        "Rings",
        "Amulets",
        "Helm",
        "Bracers",
        "OffHands ",
        "Staves",
        "Trinkets",
        "Misc"
      },
      ["Tailoring"] = {
        "ALL",
        "Helm",
        "Shoulders",
        "Cloak",
        "Chest",
        "Bracers",
        " Gloves ",
        "Belt",
        "Pants ",
        "Boots",
        "Bags",
        "Shirt",
        "Misc"
      }
    }
    
    local slots = categories[UI_FilterProf] or {"ALL"}
    local info
    for i = 1, tlen(slots) do
      info = {}
      info.text = slots[i]
      info.value = slots[i]
      info.func = BRP_SubDD_OnClick
      UIDropDownMenu_AddButton(info)
    end
  end
  
  UIDropDownMenu_Initialize(subDD, BRP_SubDD_Initialize)
  UIDropDownMenu_SetWidth(150, subDD)
  UIDropDownMenu_SetSelectedValue(subDD, UI_EnchantSlot)
  UIDropDownMenu_SetText(UI_EnchantSlot, subDD)

  -- Banana Republic Logo (top right, where send button was)
  local logoFrame = CreateFrame("Frame", nil, f)
  logoFrame:SetWidth(80)
  logoFrame:SetHeight(80)
  logoFrame:SetPoint("TOPRIGHT", dd, "BOTTOMRIGHT", -40, -10)
  
  local logoTexture = logoFrame:CreateTexture(nil, "ARTWORK")
  logoTexture:SetTexture("Interface\\AddOns\\BananaRepublicProfs\\BananaRepublicIcon")
  logoTexture:SetAllPoints(logoFrame)
  logoTexture:SetAlpha(0.9)  -- Bright and clear!
  f.logoFrame = logoFrame

  -- Tab system (at bottom)
  local tab1 = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  tab1:SetWidth(120)
  tab1:SetHeight(24)
  tab1:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, 8)
  tab1:SetText("Rezepte")
  f.tab1 = tab1
  
  local tab2 = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  tab2:SetWidth(120)
  tab2:SetHeight(24)
  tab2:SetPoint("LEFT", tab1, "RIGHT", 5, 0)
  tab2:SetText("Admin")
  f.tab2 = tab2
  
  local tab3 = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  tab3:SetWidth(150)
  tab3:SetHeight(24)
  tab3:SetPoint("LEFT", tab2, "RIGHT", 5, 0)
  tab3:SetText("Datenbank teilen")
  tab3:SetScript("OnClick", function()
    -- Share ALL profession data to guild
    msg("Teile Datenbank mit der Gilde...")
    local count = 0
    local profs = {"Alchemy", "Blacksmithing", "Enchanting", "Engineering", "Jewelcrafting", "Leatherworking", "Tailoring"}
    local db = ensureDB()
    for _, profName in ipairs(profs) do
      if db.me.profs[profName] and db.me.profs[profName].recipes then
        BRP_SendAllRecipesForProfession(profName)
        count = count + 1
      end
    end
    if count > 0 then
      msg("✅ " .. count .. " Beruf(e) an Gilde gesendet!")
    else
      msg("Keine Berufe zum Teilen. Scanne zuerst deine Berufe!")
    end
  end)
  f.tab3 = tab3
  
  local function switchTab(tabNum)
    UI_CurrentTab = tabNum
    if tabNum == 1 then
      f.recipePage:Show()
      f.adminPage:Hide()
      tab1:Disable()
      tab2:Enable()
    else
      f.recipePage:Hide()
      f.adminPage:Show()
      f.refreshAdminPage()
      tab1:Enable()
      tab2:Disable()
    end
  end
  
  tab1:SetScript("OnClick", function() switchTab(1) end)
  tab2:SetScript("OnClick", function() switchTab(2) end)

  -- Recipe page (existing list)
  local recipePage = CreateFrame("Frame", nil, f)
  recipePage:SetAllPoints(f)
  f.recipePage = recipePage

  local listBg = CreateFrame("Frame", nil, recipePage)
  listBg:SetPoint("TOPLEFT", recipePage, "TOPLEFT", 18, -130)
  listBg:SetPoint("BOTTOMRIGHT", recipePage, "BOTTOMRIGHT", -38, 40)  -- 40 from bottom for tabs
  listBg:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  listBg:SetBackdropColor(0, 0, 0, 0.95)  -- Much darker to cover other images!
  f.listBg = listBg
  
  -- Banana Republic Logo (watermark in main window)
  local mainLogo = listBg:CreateTexture(nil, "ARTWORK")  -- Changed to ARTWORK layer
  mainLogo:SetTexture("Interface\\AddOns\\BananaRepublicProfs\\BananaRepublicIcon")
  mainLogo:SetWidth(350)  -- Even bigger!
  mainLogo:SetHeight(350)
  mainLogo:SetPoint("CENTER", listBg, "CENTER", 0, -20)
  mainLogo:SetAlpha(0.4)  -- Much more visible (was 0.12)
  f.mainLogo = mainLogo

  f.visibleRows = BRP_VISIBLE_ROWS
  f.rowHeight = BRP_ROW_HEIGHT
  f.rows = {}

  local sb = CreateFrame("Slider", "BRP_Scrollbar", recipePage)
  f.scrollbar = sb
  sb:SetOrientation("VERTICAL")
  sb:SetPoint("TOPRIGHT", listBg, "TOPRIGHT", -6, -6)
  sb:SetPoint("BOTTOMRIGHT", listBg, "BOTTOMRIGHT", -6, 6)
  sb:SetWidth(16)
  sb:SetMinMaxValues(0, 0)
  sb:SetValue(0)
  sb:SetValueStep(1)
  
  sb:SetBackdrop({
    bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
    edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
  })
  
  local thumb = sb:CreateTexture(nil, "OVERLAY")
  thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
  thumb:SetWidth(16)
  thumb:SetHeight(24)
  sb:SetThumbTexture(thumb)
  
  sb:SetScript("OnValueChanged", function()
    UI_ScrollOffset = math.floor(this:GetValue() + 0.5)
    BRP_UI_Refresh()
  end)

  local function DoScroll(delta)
    if type(delta) ~= "number" then return end
    
    local allData = uiBuildData()
    local filtered = uiFilterData(allData)
    local totalItems = tlen(filtered)
    local maxScroll = math.max(0, totalItems - f.visibleRows)
    
    UI_ScrollOffset = UI_ScrollOffset - (delta * 3)
    if UI_ScrollOffset < 0 then UI_ScrollOffset = 0 end
    if UI_ScrollOffset > maxScroll then UI_ScrollOffset = maxScroll end
    
    BRP_UI_Refresh()
  end

  listBg:EnableMouseWheel(true)
  listBg:SetScript("OnMouseWheel", function()
    DoScroll(arg1)
  end)

  for i = 1, f.visibleRows do
    local row = CreateFrame("Button", nil, f)
    row:SetHeight(f.rowHeight)
    row:SetPoint("TOPLEFT", listBg, "TOPLEFT", 10, -8 - (i-1)*f.rowHeight)
    row:SetPoint("TOPRIGHT", listBg, "TOPRIGHT", -30, -8 - (i-1)*f.rowHeight)

    row.recipe = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.recipe:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.recipe:SetWidth(280)
    row.recipe:SetJustifyH("LEFT")

    row.who = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.who:SetPoint("LEFT", row, "LEFT", 292, 0)
    row.who:SetWidth(190)
    row.who:SetJustifyH("LEFT")

    row:SetScript("OnClick", function()
      if this and this.data then
        BRP_ShowRecipePopup(this.data)
      end
    end)

    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function()
      DoScroll(arg1)
    end)

    f.rows[i] = row
  end

  -- Admin Page
  local adminPage = CreateFrame("Frame", nil, f)
  adminPage:SetAllPoints(f)
  adminPage:Hide()
  f.adminPage = adminPage
  
  local adminBg = CreateFrame("Frame", nil, adminPage)
  adminBg:SetPoint("TOPLEFT", adminPage, "TOPLEFT", 18, -130)
  adminBg:SetPoint("BOTTOMRIGHT", adminPage, "BOTTOMRIGHT", -38, 40)  -- 40 from bottom for tabs
  adminBg:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  adminBg:SetBackdropColor(0,0,0,0.65)
  
  local adminTitle = adminPage:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  adminTitle:SetPoint("TOP", adminBg, "TOP", 0, -15)
  adminTitle:SetText("Berufe Verwalten")
  
  local adminInfo = adminPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  adminInfo:SetPoint("TOP", adminTitle, "BOTTOM", 0, -10)
  adminInfo:SetWidth(450)
  adminInfo:SetJustifyH("CENTER")
  adminInfo:SetText("Klicke auf einen Beruf um ihn zu löschen und an die Gilde zu senden")
  
  -- Create profession delete buttons (dynamically)
  f.adminButtons = {}
  
  local function refreshAdminPage()
    -- Hide all buttons first
    for i = 1, 10 do
      if f.adminButtons[i] then
        f.adminButtons[i]:Hide()
      end
    end
    
    local db = ensureDB()
    local profList = {}
    for profName, _ in pairs(db.me.profs) do
      table.insert(profList, profName)
    end
    table.sort(profList)
    
    for i = 1, tlen(profList) do
      local profName = profList[i]
      
      if not f.adminButtons[i] then
        local btn = CreateFrame("Button", nil, adminPage, "UIPanelButtonTemplate")
        btn:SetWidth(200)
        btn:SetHeight(28)
        if i == 1 then
          btn:SetPoint("TOP", adminInfo, "BOTTOM", 0, -20)
        else
          btn:SetPoint("TOP", f.adminButtons[i-1], "BOTTOM", 0, -5)
        end
        f.adminButtons[i] = btn
      end
      
      local btn = f.adminButtons[i]
      btn:SetText(profName .. " löschen")
      btn:Show()
      
      btn:SetScript("OnClick", function()
        local db = ensureDB()
        
        -- Remove profession
        db.me.profs[profName] = nil
        
        -- Update guild entry
        if db.guild[playerName()] and db.guild[playerName()].profs then
          db.guild[playerName()].profs[profName] = nil
        end
        
        msg("|cffff0000Gelöscht:|r " .. profName)
        
        -- Broadcast deletion
        local delMsg = "DEL" .. SEP .. safe(playerName()) .. SEP .. safe(profName)
        enqueueSend("GUILD", delMsg)
        
        -- Refresh admin page
        refreshAdminPage()
      end)
    end
    
    if tlen(profList) == 0 then
      adminInfo:SetText("Keine Berufe gespeichert")
    else
      adminInfo:SetText("Klicke auf einen Beruf um ihn zu löschen und an die Gilde zu senden")
    end
  end
  
  f.refreshAdminPage = refreshAdminPage
  
  -- "Datenbank an Gilde teilen" button
  local shareBtn = CreateFrame("Button", nil, adminPage, "UIPanelButtonTemplate")
  shareBtn:SetWidth(220)
  shareBtn:SetHeight(30)
  shareBtn:SetPoint("BOTTOM", adminBg, "BOTTOM", 0, 15)
  shareBtn:SetText("Datenbank an Gilde teilen")
  shareBtn:SetScript("OnClick", function()
    local db = ensureDB()
    local sharedCount = 0
    
    -- Share all professions from current player
    for profName, profData in pairs(db.me.profs) do
      if profData.recipes and tlen(profData.recipes) > 0 then
        broadcastProfessionData(profName)
        sharedCount = sharedCount + 1
      end
    end
    
    if sharedCount > 0 then
      msg(sharedCount .. " Beruf(e) an die Gilde gesendet! 🍌")
    else
      msg("Keine Berufe zum Teilen vorhanden! Scanne zuerst einen Beruf.")
    end
  end)
  
  -- Initial tab state
  recipePage:Show()
  adminPage:Hide()
  tab1:Disable()

  f:Hide()
end

local function uiToggle()
  uiCreate()
  if BRP_UI:IsShown() then
    BRP_UI:Hide()
  else
    -- Cleanup old professions from all players when opening UI
    cleanupOldProfessionsFromAllPlayers()
    
    UI_ScrollOffset = 0
    BRP_UI:Show()
    BRP_UI_Refresh()
  end
end

-- -------------------------
-- CSV Export
-- -------------------------
local function exportToCSV()
  local db = ensureDB()
  local csv = "Spieler,Beruf,Rank,Rezept,Reagenzien\n"
  
  -- Build CSV data
  for player, data in pairs(db.guild) do
    if data.profs then
      for profName, profData in pairs(data.profs) do
        local rank = (profData.rank or 0) .. "/" .. (profData.maxRank or 0)
        
        if profData.recipes then
          for i = 1, tlen(profData.recipes) do
            local recipe = profData.recipes[i]
            local recipeName = recipe.name or "Unknown"
            
            -- Build reagent string
            local reagentStr = ""
            if recipe.reagents then
              for r = 1, tlen(recipe.reagents) do
                local rg = recipe.reagents[r]
                if r > 1 then reagentStr = reagentStr .. "; " end
                reagentStr = reagentStr .. (rg.count or 1) .. "x " .. (rg.name or "?")
              end
            end
            
            -- Escape quotes in strings
            recipeName = string.gsub(recipeName, '"', '""')
            reagentStr = string.gsub(reagentStr, '"', '""')
            
            -- Add row
            csv = csv .. string.format('%s,%s,%s,"%s","%s"\n', 
              player, profName, rank, recipeName, reagentStr)
          end
        end
      end
    end
  end
  
  -- Count lines
  local lineCount = 0
  for _ in string.gmatch(csv, "[^\n]+") do
    lineCount = lineCount + 1
  end
  
  -- Save to global variable
  BRP_CSV_Export = csv
  BRP_CSV_Timestamp = date("%Y-%m-%d %H:%M:%S")
  BRP_CSV_Lines = lineCount
  
  -- Create export popup with copyable text
  if not BRP_ExportFrame then
    local f = CreateFrame("Frame", "BRP_ExportFrame", UIParent)
    f:SetWidth(600)
    f:SetHeight(400)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 32, edgeSize = 32,
      insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    
    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -20)
    title:SetText("CSV Export")
    f.title = title
    
    -- Info text
    local info = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    info:SetPoint("TOP", title, "BOTTOM", 0, -10)
    info:SetWidth(550)
    info:SetJustifyH("CENTER")
    info:SetText("|cff00ff00Strg+A → Strg+C zum Kopieren!|r")
    f.info = info
    
    -- ScrollFrame for EditBox
    local scroll = CreateFrame("ScrollFrame", "BRP_ExportScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -80)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -40, 50)
    
    -- EditBox (copyable!)
    local editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetWidth(520)
    editBox:SetHeight(280)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(GameFontWhite)
    editBox:SetFont("Fonts\\ARIALN.TTF", 11)
    editBox:SetMaxLetters(0)  -- Unlimited
    scroll:SetScrollChild(editBox)
    f.editBox = editBox
    
    editBox:SetScript("OnEscapePressed", function()
      BRP_ExportFrame:Hide()
    end)
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetWidth(100)
    closeBtn:SetHeight(22)
    closeBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 15)
    closeBtn:SetText("Schließen")
    closeBtn:SetScript("OnClick", function()
      BRP_ExportFrame:Hide()
    end)
    
    BRP_ExportFrame = f
  end
  
  -- Set CSV text
  BRP_ExportFrame.editBox:SetText(csv)
  BRP_ExportFrame.editBox:HighlightText()  -- Pre-select all
  BRP_ExportFrame.info:SetText(string.format("|cff00ff00%d Zeilen | %s|r\n|cffffff00Strg+A → Strg+C zum Kopieren!|r", lineCount, BRP_CSV_Timestamp))
  BRP_ExportFrame:Show()
  
  msg("|cff00ff00CSV Export-Fenster geöffnet!|r")
  msg("|cffffff00Strg+A|r → ganzen Text markieren")
  msg("|cffffff00Strg+C|r → kopieren")
  msg("Dann in Notepad einfügen und als .csv speichern!")
end

-- -------------------------
-- Slash commands
-- -------------------------
SLASH_BRP1 = "/brp"
SlashCmdList["BRP"] = function(input)
  input = input or ""
  
  if type(input) ~= "string" then input = "" end

  local cmd = ""
  if input ~= "" and string.len(input) > 0 then
    local success, _, _, c = pcall(string.find, input, "^(%S+)")
    if success and c then
      cmd = c
    end
  end
  cmd = string.lower(cmd or "")

  if cmd == "" or cmd == "help" then
    msg("Befehle:")
    msg("/brp show      — UI öffnen/schließen")
    msg("/brp scan      — aktuell geöffneten Beruf scannen")
    msg("/brp send      — alle Berufe an Gilde senden")
    msg("/brp scanbank  — Bank manuell scannen")
    msg("/brp export    — CSV-Export für Discord/Excel")
    msg("/brp debug     — Debug an/aus")
    return
  end

  if cmd == "show" then uiToggle(); return end
  if cmd == "scan" then 
    LastScannedProf = nil
    scanCurrentTradeSkill()
    return 
  end
  if cmd == "send" then broadcastAll(); return end
  if cmd == "scanbank" then
    scanBank()
    return
  end
  if cmd == "export" then
    exportToCSV()
    return
  end
  if cmd == "debug" then
    DEBUG = not DEBUG
    msg("Debug: " .. (DEBUG and "AN" or "AUS"))
    return
  end

  msg("Unbekannter Befehl. /brp help")
end

-- -------------------------
-- Events
-- -------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("TRADE_SKILL_SHOW")
eventFrame:RegisterEvent("CRAFT_UPDATE")
eventFrame:RegisterEvent("TRADE_SKILL_UPDATE")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("BANKFRAME_OPENED")  -- Auto-scan bank

eventFrame:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" then
    if arg1 == ADDON_NAME then
      ensureDB()
      if RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(PREFIX)
        debug("Prefix registriert: " .. PREFIX)
      end
    end
    return
  end

  if event == "PLAYER_LOGIN" then
    ensureDB()
    local db = ensureDB()
    
    -- Data migration: Fix old corrupted profession data
    local cleaned = 0
    for profName, profData in pairs(db.me.profs) do
      if type(profData) ~= "table" then
        -- Corrupted data - remove it
        db.me.profs[profName] = nil
        cleaned = cleaned + 1
        debug("Migration: Entferne korrupte Daten für " .. profName)
      elseif not profData.scannedAt then
        -- Old data without timestamp - add current timestamp
        profData.scannedAt = now()
        debug("Migration: Timestamp hinzugefügt für " .. profName)
      elseif parseTimestamp(profData.scannedAt) == nil then
        -- Invalid timestamp format - add current timestamp
        profData.scannedAt = now()
        debug("Migration: Invaliden Timestamp ersetzt für " .. profName)
      end
    end
    
    -- Clean ALL guild players' invalid timestamps
    for player, data in pairs(db.guild) do
      if data.profs then
        for profName, profData in pairs(data.profs) do
          if type(profData) == "table" then
            if not profData.scannedAt then
              profData.scannedAt = now()
              debug("Migration: Timestamp für " .. player .. " - " .. profName)
              elseif parseTimestamp(profData.scannedAt) == nil then
              -- Invalid timestamp format - repair instead of deleting
              profData.scannedAt = now()
              cleaned = cleaned + 1
              debug("Migration: Invaliden Timestamp repariert für " .. player .. " - " .. profName)
            end
          end
        end
      end
    end
    
    if cleaned > 0 then
      msg("Datenbank bereinigt: " .. cleaned .. " korrupte Einträge entfernt")
    end
    
    db.guild[playerName()] = { updated = db.me.updated, profs = copyTable(db.me.profs) }
    
    -- Cleanup old professions on login (2 minutes)
    cleanupOldProfessions()
    
    msg("geladen. /brp show")
    return
  end

  if event == "TRADE_SKILL_SHOW" then
    scanCurrentTradeSkill()
    return
  end

  if event == "CRAFT_SHOW" or event == "CRAFT_UPDATE" then
  scanCurrentCraft() -- neu
  return
  end

  if event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_UPDATE" then
  scanCurrentTradeSkill()
  return
  end

  if event == "CHAT_MSG_ADDON" then
    handleAddonMessage(arg1, arg2, arg3, arg4)
    return
  end

  if event == "BANKFRAME_OPENED" then
    -- Auto-scan bank when opened
    scanBank()
    return
  end
end)
