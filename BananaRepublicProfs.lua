-- BananaRepublicProfs (BRP) v0.6 - Turtle/Vanilla 1.12 (Lua 5.0) compatible
-- Fixed SetSize() error (not available in 1.12) and scrollbar initialization

local ADDON_NAME = "BananaRepublicProfs"
local DB_NAME = "BRPDB"
local PREFIX = "BRP0" -- <= 16 chars

local tlen = table.getn

-- -------------------------
-- Utility
-- -------------------------
local function msg(text)
  DEFAULT_CHAT_FRAME:AddMessage("|cffffd200BRP:|r " .. text)
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
  return db
end

local function copyTable(t)
  local r = {}
  for k, v in pairs(t or {}) do r[k] = v end
  return r
end

local function norm(s)
  if not s then return "" end
  return string.lower(s)
end

-- -------------------------
-- Protocol safety (no pipes!)
-- -------------------------
local SEP = "^"

local function safe(str)
  if str == nil then return "" end
  if type(str) ~= "string" then str = tostring(str) end
  str = string.gsub(str, "%^", "/")
  str = string.gsub(str, "|", "/")
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
-- Reagent Scanner (batchweise, verhindert Freeze)
-- -------------------------
local BRP_ReagentScan = { running = false }
local BRP_ReagentFrame = CreateFrame("Frame")
BRP_ReagentFrame:Hide()

local function BRP_StartReagentScan(profName, recipes)
  BRP_ReagentScan.running = true
  BRP_ReagentScan.profName = profName
  BRP_ReagentScan.recipes = recipes
  BRP_ReagentScan.i = 1
  BRP_ReagentFrame:Show()
end

BRP_ReagentFrame:SetScript("OnUpdate", function()
  if not BRP_ReagentScan.running then
    BRP_ReagentFrame:Hide()
    return
  end

  local recipes = BRP_ReagentScan.recipes
  if not recipes then
    BRP_ReagentScan.running = false
    BRP_ReagentFrame:Hide()
    return
  end

  local perFrame = 6
  local n = tlen(recipes)

  for k = 1, perFrame do
    local i = BRP_ReagentScan.i
    if i > n then
      BRP_ReagentScan.running = false
      BRP_ReagentFrame:Hide()
      if BRP_UI and BRP_UI:IsShown() then BRP_UI_Refresh() end
      return
    end

    local rec = recipes[i]
    if type(rec) == "table" and not rec.reagentsLoaded then
      local ti = rec.tradeIndex
      if ti then
        local reagents = {}
        local numReagents = GetTradeSkillNumReagents and GetTradeSkillNumReagents(ti)
        if numReagents and numReagents > 0 then
          for r = 1, numReagents do
            local rName, _, rCount = GetTradeSkillReagentInfo(ti, r)
            if rName and rName ~= "" and rCount then
              table.insert(reagents, { name = rName, count = rCount })
            end
          end
        end
        rec.reagents = reagents
      end
      rec.reagentsLoaded = true
    end

    BRP_ReagentScan.i = i + 1
  end
end)

-- -------------------------
-- Scan TradeSkill
-- -------------------------
local function scanCurrentTradeSkill()
  if not GetTradeSkillLine or not GetNumTradeSkills or not GetTradeSkillInfo then
    msg("TradeSkill API nicht verfügbar.")
    return
  end

  local profName, rank, maxRank = GetTradeSkillLine()
  if not profName or profName == "" then return end

  local n = GetNumTradeSkills()
  if not n or n <= 0 then return end

  local recipes = {}
  local currentHeader = nil

  for i = 1, n do
    local name, skillType = GetTradeSkillInfo(i)
    if name and skillType then
      if skillType == "header" then
        currentHeader = name
      else
        table.insert(recipes, {
          name = name,
          header = currentHeader,
          reagents = nil,
          reagentsLoaded = false,
          tradeIndex = i,
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

  BRP_StartReagentScan(profName, recipes)

  local gname = GetGuildInfo and GetGuildInfo("player")
  if gname and gname ~= "" then
    BRP_BroadcastProfession(profName)
  end
end

-- -------------------------
-- Broadcast (chunked)
-- -------------------------
function BRP_BroadcastProfession(profName)
  local db = ensureDB()
  local entry = db.me.profs[profName]
  if not entry then return end

  local p = playerName()
  local rank = entry.rank or 0
  local maxRank = entry.maxRank or 0
  local recipes = entry.recipes or {}

  local chunks = {}
  local buf = ""

  for i = 1, tlen(recipes) do
    local recipeStr = ""

    if type(recipes[i]) == "table" then
      local nm = recipes[i].name or ""
      local hd = recipes[i].header
      if hd and hd ~= "" then
        recipeStr = hd .. " > " .. nm
      else
        recipeStr = nm
      end
    else
      recipeStr = recipes[i] or ""
    end

    local r = safe(recipeStr)
    if r and r ~= "" then
      local line = r .. "\n"
      if string.len(buf .. line) > 200 then
        table.insert(chunks, buf)
        buf = line
      else
        buf = buf .. line
      end
    end
  end

  if string.len(buf) > 0 then
    table.insert(chunks, buf)
  end

  local total = tlen(chunks)
  local startMsg = "S" .. SEP .. safe(p) .. SEP .. safe(profName) .. SEP .. tostring(rank) .. SEP .. tostring(maxRank) .. SEP .. tostring(total)
  enqueueSend("GUILD", startMsg)

  for idx = 1, total do
    local chunkMsg = "C" .. SEP .. safe(p) .. SEP .. safe(profName) .. SEP .. tostring(idx) .. SEP .. safe(chunks[idx])
    enqueueSend("GUILD", chunkMsg)
  end

  local endMsg = "E" .. SEP .. safe(p) .. SEP .. safe(profName)
  enqueueSend("GUILD", endMsg)

  msg("Broadcast gestartet: " .. profName .. " (" .. total .. " chunks)")
end

local function broadcastAll()
  local db = ensureDB()
  local count = 0
  for profName, _ in pairs(db.me.profs) do
    BRP_BroadcastProfession(profName)
    count = count + 1
  end
  if count > 0 then
    msg("Sende " .. count .. " Beruf(e) an die Gilde...")
  else
    msg("Keine Berufe zum Senden. /brp scan")
  end
end

-- -------------------------
-- Receive
-- -------------------------
local function handleAddonMessage(prefix, text, distrib, sender)
  if prefix ~= PREFIX then return end
  if sender == playerName() then return end

  local _, _, cmd = string.find(text, "^([^"..SEP.."]+)")
  if not cmd then return end

  local db = ensureDB()

  if cmd == "S" then
    local _, _, _, player, prof, rankS, maxS, totalS = string.find(text, "^([^"..SEP.."]+)"..SEP.."([^"..SEP.."]+)"..SEP.."([^"..SEP.."]+)"..SEP.."([^"..SEP.."]+)"..SEP.."([^"..SEP.."]+)"..SEP.."([^"..SEP.."]+)")
    if player and prof then
      local pend = getPending(player, prof)
      pend.total = tonumber(totalS) or 0
      pend.rank = tonumber(rankS) or 0
      pend.maxRank = tonumber(maxS) or 0
      pend.chunks = {}
    end
    return
  end

  if cmd == "C" then
    local _, _, _, player, prof, idxS, chunk = string.find(text, "^([^"..SEP.."]+)"..SEP.."([^"..SEP.."]+)"..SEP.."([^"..SEP.."]+)"..SEP.."([^"..SEP.."]+)"..SEP.."(.*)")
    if player and prof and idxS and chunk then
      local pend = getPending(player, prof)
      local idx = tonumber(idxS)
      if idx then
        pend.chunks[idx] = chunk
      end
    end
    return
  end

  if cmd == "E" then
    local _, _, _, player, prof = string.find(text, "^([^"..SEP.."]+)"..SEP.."([^"..SEP.."]+)"..SEP.."([^"..SEP.."]+)")
    if player and prof then
      local pend = getPending(player, prof)
      local total = pend.total or 0
      local got = 0
      for k, v in pairs(pend.chunks) do
        if v then got = got + 1 end
      end

      if got >= total and total > 0 then
        local full = ""
        for i = 1, total do
          if pend.chunks[i] then
            full = full .. pend.chunks[i]
          end
        end

        local recipes = {}
        local idx = 1
        while idx <= string.len(full) do
          local e = string.find(full, "\n", idx)
          if e then
            local line = string.sub(full, idx, e - 1)
            if line and line ~= "" then
              table.insert(recipes, { name = line, header = nil, reagents = nil, reagentsLoaded = false })
            end
            idx = e + 1
          else
            local line = string.sub(full, idx)
            if line and line ~= "" then
              table.insert(recipes, { name = line, header = nil, reagents = nil, reagentsLoaded = false })
            end
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

        msg("Empfangen: " .. player .. " — " .. prof .. " (" .. pend.rank .. "/" .. pend.maxRank .. ") — " .. tlen(recipes) .. " Rezepte")

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
local UI_ScrollOffset = 0
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
  local results = {}

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
            table.insert(results, {
              player = player,
              prof = profName,
              rank = profData.rank or 0,
              maxRank = profData.maxRank or 0,
              recipe = rname,
              recipeData = rec,
            })
          end
        end
      end
    end
  end

  return results
end

local function uiFilterData(data)
  local filtered = {}
  local searchL = norm(UI_Search)

  for i = 1, tlen(data) do
    local row = data[i]
    local profMatch = (UI_FilterProf == "ALL" or row.prof == UI_FilterProf)
    if profMatch then
      if searchL == "" then
        table.insert(filtered, row)
      else
        local rL = norm(row.recipe)
        if string.find(rL, searchL, 1, true) then
          table.insert(filtered, row)
        end
      end
    end
  end

  table.sort(filtered, function(a, b)
    if a.recipe ~= b.recipe then return a.recipe < b.recipe end
    return a.player < b.player
  end)

  return filtered
end

-- -------------------------
-- UI: Recipe Popup
-- -------------------------
local BRP_RecipePopup = nil

function BRP_ShowRecipePopup(data)
  if not BRP_RecipePopup then
    local pop = CreateFrame("Frame", "BRP_RecipePopup", UIParent)
    BRP_RecipePopup = pop
    pop:SetWidth(360)
    pop:SetHeight(280)
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

    local close = CreateFrame("Button", nil, pop, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", pop, "TOPRIGHT", -6, -6)

    local scrollBg = CreateFrame("Frame", nil, pop)
    scrollBg:SetPoint("TOPLEFT", pop, "TOPLEFT", 18, -50)
    scrollBg:SetPoint("BOTTOMRIGHT", pop, "BOTTOMRIGHT", -38, 50)
    scrollBg:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    scrollBg:SetBackdropColor(0, 0, 0, 0.8)

    local scroll = CreateFrame("ScrollFrame", "BRP_RecipePopupScrollFrame", pop, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", scrollBg, "TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", scrollBg, "BOTTOMRIGHT", -28, 8)
    pop.scroll = scroll

    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(280)
    content:SetHeight(400)
    scroll:SetScrollChild(content)
    pop.content = content

    local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    text:SetWidth(280)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    pop.text = text

    local whisperBtn = CreateFrame("Button", nil, pop, "UIPanelButtonTemplate")
    whisperBtn:SetWidth(140)
    whisperBtn:SetHeight(24)
    whisperBtn:SetPoint("BOTTOM", pop, "BOTTOM", 0, 18)
    whisperBtn:SetText("Whisper")
    pop.whisperBtn = whisperBtn

    pop:Hide()
  end

  local pop = BRP_RecipePopup
  pop.title:SetText(data.recipe or "Rezept")

  local infoText = "|cffffffff" .. (data.recipe or "") .. "|r\n\n"
  infoText = infoText .. "|cff00ff00Spieler:|r " .. (data.player or "") .. "\n"
  infoText = infoText .. "|cff00ff00Beruf:|r " .. (data.prof or "") .. " (" .. (data.rank or 0) .. "/" .. (data.maxRank or 0) .. ")\n\n"

  if type(data.recipeData) == "table" and data.recipeData.reagents then
    local reagents = data.recipeData.reagents
    if tlen(reagents) > 0 then
      infoText = infoText .. "|cffffff00Materialien:|r\n"
      for i = 1, tlen(reagents) do
        local r = reagents[i]
        infoText = infoText .. "  " .. (r.count or 1) .. "x " .. (r.name or "?") .. "\n"
      end
    end
  end

  pop.text:SetText(infoText)
  local textHeight = pop.text:GetHeight()
  pop.content:SetHeight(math.max(textHeight + 20, 400))

  pop.whisperBtn:SetScript("OnClick", function()
    if data.player then
      local editbox = DEFAULT_CHAT_FRAME.editBox or ChatFrameEditBox
      if editbox then
        editbox:SetText("/w " .. data.player .. " ")
        editbox:Show()
        editbox:SetFocus()
      end
    end
  end)

  pop:Show()
end

-- -------------------------
-- UI: Refresh (Manual scrolling)
-- -------------------------
function BRP_UI_Refresh()
  local f = BRP_UI
  if not f or not f:IsShown() then return end

  local allData = uiBuildData()
  local filtered = uiFilterData(allData)
  local totalItems = tlen(filtered)

  -- Update scrollbar
  local sb = f.scrollbar
  if sb then
    local maxScroll = math.max(0, totalItems - f.visibleRows)
    sb:SetMinMaxValues(0, maxScroll)
    
    -- Clamp offset
    if UI_ScrollOffset > maxScroll then
      UI_ScrollOffset = maxScroll
    end
    if UI_ScrollOffset < 0 then
      UI_ScrollOffset = 0
    end
    
    sb:SetValue(UI_ScrollOffset)
    
    -- Show/hide scrollbar based on need
    if maxScroll > 0 then
      sb:Show()
    else
      sb:Hide()
    end
  end

  -- Update rows
  for i = 1, f.visibleRows do
    local row = f.rows[i]
    local dataIndex = UI_ScrollOffset + i

    if dataIndex <= totalItems then
      local data = filtered[dataIndex]
      row.recipe:SetText("|cffffffff" .. (data.recipe or ""))
      row.who:SetText("|cff888888" .. (data.player or "") .. " (" .. (data.prof or "") .. " " .. (data.rank or 0) .. "/" .. (data.maxRank or 0) .. ")")
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
  f:SetHeight(420)
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

  local searchLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  searchLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -62)
  searchLabel:SetText("Suche:")

  local search = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  search:SetWidth(240)
  search:SetHeight(20)
  search:SetPoint("LEFT", searchLabel, "RIGHT", 10, 0)
  search:SetAutoFocus(false)
  search:SetScript("OnEnterPressed", function() this:ClearFocus() end)
  search:SetScript("OnTextChanged", function()
    UI_Search = this:GetText() or ""
    UI_ScrollOffset = 0  -- Reset scroll on search
    BRP_UI_Refresh()
  end)

  -- Dropdown Filter
  local dd = CreateFrame("Frame", "BRP_FilterDropDown", f, "UIDropDownMenuTemplate")
  dd:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -54)
  f.filterDD = dd

  local function BRP_FilterDD_OnClick()
    UI_FilterProf = this.value or "ALL"
    UIDropDownMenu_SetSelectedValue(dd, UI_FilterProf)
    UIDropDownMenu_SetText(UI_FilterProf, dd)
    UI_ScrollOffset = 0  -- Reset scroll on filter change
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

  -- Send button
  local sendBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  sendBtn:SetWidth(160)
  sendBtn:SetHeight(22)
  sendBtn:SetPoint("TOPRIGHT", dd, "BOTTOMRIGHT", -18, -6)
  sendBtn:SetText("An Gilde senden")
  sendBtn:SetScript("OnClick", function() broadcastAll() end)

  -- List background
  local listBg = CreateFrame("Frame", nil, f)
  listBg:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -130)
  listBg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -38, 18)
  listBg:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  listBg:SetBackdropColor(0,0,0,0.65)

  f.visibleRows = BRP_VISIBLE_ROWS
  f.rowHeight = BRP_ROW_HEIGHT
  f.rows = {}

  -- Manual Scrollbar
  local sb = CreateFrame("Slider", "BRP_Scrollbar", f)
  f.scrollbar = sb
  sb:SetOrientation("VERTICAL")
  sb:SetPoint("TOPRIGHT", listBg, "TOPRIGHT", -6, -6)
  sb:SetPoint("BOTTOMRIGHT", listBg, "BOTTOMRIGHT", -6, 6)
  sb:SetWidth(16)
  sb:SetMinMaxValues(0, 0)
  sb:SetValue(0)
  sb:SetValueStep(1)
  
  -- Scrollbar textures (Vanilla 1.12 compatible - use SetWidth/SetHeight instead of SetSize)
  sb:SetBackdrop({
    bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
    edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
  })
  
  local thumb = sb:CreateTexture(nil, "OVERLAY")
  thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
  thumb:SetWidth(16)  -- Use SetWidth/SetHeight instead of SetSize for 1.12
  thumb:SetHeight(24)
  sb:SetThumbTexture(thumb)
  
  sb:SetScript("OnValueChanged", function()
    UI_ScrollOffset = math.floor(this:GetValue() + 0.5)
    BRP_UI_Refresh()
  end)

  -- Mousewheel scrolling helper
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

  -- Enable mousewheel on list background
  listBg:EnableMouseWheel(true)
  listBg:SetScript("OnMouseWheel", function()
    DoScroll(arg1)
  end)

  -- Rows
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

    -- Mousewheel on rows
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function()
      DoScroll(arg1)
    end)

    f.rows[i] = row
  end

  f:Hide()
end

local function uiToggle()
  uiCreate()
  if BRP_UI:IsShown() then
    BRP_UI:Hide()
  else
    UI_ScrollOffset = 0  -- Reset scroll when opening
    BRP_UI:Show()
    BRP_UI_Refresh()
  end
end

-- -------------------------
-- Slash commands
-- -------------------------
SLASH_BRP1 = "/brp"
SlashCmdList["BRP"] = function(input)
  input = input or ""

  local cmd = ""
  if input ~= "" then
    local _, _, c = string.find(input, "^(%S+)")
    cmd = c or ""
  end
  cmd = string.lower(cmd)

  if cmd == "" or cmd == "help" then
    msg("Befehle:")
    msg("/brp show   — UI öffnen/schließen")
    msg("/brp scan   — aktuell geöffneten Beruf scannen")
    msg("/brp send   — alle gespeicherten Berufe an die Gilde senden")
    return
  end

  if cmd == "show" then uiToggle(); return end
  if cmd == "scan" then scanCurrentTradeSkill(); return end
  if cmd == "send" then broadcastAll(); return end

  msg("Unbekannter Befehl. /brp help")
end

-- -------------------------
-- Events
-- -------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("TRADE_SKILL_SHOW")
eventFrame:RegisterEvent("TRADE_SKILL_UPDATE")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")

eventFrame:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" then
    if arg1 == ADDON_NAME then
      ensureDB()
      if RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(PREFIX)
      end
    end
    return
  end

  if event == "PLAYER_LOGIN" then
    ensureDB()
    local db = ensureDB()
    db.guild[playerName()] = { updated = db.me.updated, profs = copyTable(db.me.profs) }
    msg("geladen. /brp show")
    return
  end

  if event == "TRADE_SKILL_SHOW" then
    scanCurrentTradeSkill()
    return
  end

  if event == "TRADE_SKILL_UPDATE" then
    scanCurrentTradeSkill()
    return
  end

  if event == "CHAT_MSG_ADDON" then
    handleAddonMessage(arg1, arg2, arg3, arg4)
    return
  end
end)
