
local addonName = ...; ---@type string
local AutoLoot = select(2, ...); ---@class AutoLoot

local Config = {};
local internal = {
  _frame = CreateFrame("frame", nil, UIParent),
  lootThreshold = 10,
  isAnyItemLocked = false,
  isLooting = false,
  lastNumLoot = nil,
  lootFailure = false,
  isHidden = true,
  ElvUI = false,
  ShowElvUILootFrame = nop,
  audioChannel = "master",
  hasEditModeWithLootWindow = type(LootFrame.UpdateShownState) == "function",
  slotsLooted = {},
  inventorySoundPlayed = false,
  lootTicker = nil,
};

local EnumLootSlotItem = Enum.LootSlotType.Item
local EnumLootSlotTypeNone = Enum.LootSlotType.None
local EnumBagIndexKeyring = Enum.BagIndex.Keyring
local EnumBagIndexReagentBag = Enum.BagIndex.ReagentBag

---@param itemLink ItemInfo
---@param itemQuantity number
---@return boolean itemFitsInBag
function AutoLoot:ProcessLootItem(itemLink, itemQuantity)
  local itemStackCount, _, _, _, classID, subclassID, _, _, _, isCraftingReagent = select(8, C_Item.GetItemInfo(itemLink));
  local itemFamily = C_Item.GetItemFamily(itemLink);

  if internal.gameInfo.Keyring and itemFamily == 256 then
    local freeKeyringSlots = C_Container.GetContainerNumFreeSlots(EnumBagIndexKeyring)
    if freeKeyringSlots > 0 then
      return true;
    end
  end

  local inventoryItemCount = C_Item.GetItemCount(itemLink);
  if inventoryItemCount > 0 and itemStackCount > 1 then
    if ((itemStackCount - inventoryItemCount) % itemStackCount) >= itemQuantity then
      return true;
    end
  end

  for bagSlot = BACKPACK_CONTAINER, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS do
    local freeSlots, bagFamily = C_Container.GetContainerNumFreeSlots(bagSlot);
    -- unclear if isCraftingReagent is 100% Reagent bag fitable, seems to be.
    if freeSlots > 0 then
      if bagSlot == EnumBagIndexReagentBag then
        if isCraftingReagent then
          return true;
        end
      else
        if not bagFamily or bagFamily == 0 or (itemFamily and bit.band(itemFamily, bagFamily) > 0) then
          return true;
        end
      end
    end
  end

  return false;
end

---@param slot number
---@return boolean success
function AutoLoot:LootSlot(slot)
  local slotType = GetLootSlotType(slot);
  if slotType == EnumLootSlotTypeNone then
    return true;
  end

  local lootQuantity, _, lootQuality, lootLocked, isQuestItem = select(3, GetLootSlotInfo(slot));
  if lootLocked or (slotType == EnumLootSlotItem and lootQuality and lootQuality >= internal.lootThreshold) then
    internal.isAnyItemLocked = true;
    return false;
  elseif slotType ~= EnumLootSlotItem or (internal.gameInfo.QuestBag and isQuestItem) or self:ProcessLootItem(GetLootSlotLink(slot), lootQuantity) then
    LootSlot(slot);
    if internal.gameInfo.BindOnPickup and Config.global.autoConfirm and not (GetNumGroupMembers() > 1) then
      ConfirmLootSlot(slot)
    end
    if internal.gameInfo.IsGameWrath then
      internal.slotsLooted[slot] = true;
    end
    return true;
  end

  return false;
end

function AutoLoot:SetLootThreshold()
  if internal.gameInfo.IsGameStandard then
    local _, instanceType = IsInInstance();
    local isInRaidInstance = IsInGroup() and instanceType == "raid";
    internal.lootThreshold = isInRaidInstance and 2 or 10;
  else
    local lootMethod = C_PartyInfo.GetLootMethod();
    local usesThreshold = lootMethod == Enum.LootMethod.Group or lootMethod == Enum.LootMethod.Needbeforegreed or lootMethod == Enum.LootMethod.Masterlooter;
    internal.lootThreshold = (IsInGroup() and usesThreshold) and GetLootThreshold() or 10;
  end
end

function AutoLoot:CancelLootTicker()
  if internal.lootTicker then
    internal.lootTicker:Cancel();
  end
end

---@param numItems number
function AutoLoot:StartLooting(numItems)
  self:CancelLootTicker()
  local currentLootSlot = numItems;

  internal.lootTicker = C_Timer.NewTicker(0.033, function()
    if currentLootSlot >= 1 then
      local success = self:LootSlot(currentLootSlot)
      if not success then
        internal.lootFailure = true;
      end
      currentLootSlot = currentLootSlot - 1;
    else
      if internal.lootFailure then
        self:ShowLootFrame();
      end
      -- not really nessecary as the iterations end here
      self:CancelLootTicker();
    end
  end, numItems + 1)
end

---@param autoLoot boolean
function AutoLoot:OnLootReady(autoLoot)
  internal.isLooting = true;

  -- Spamy LOOT_READY autoLoot value can swap states if you spam click, but we already know the 'true' state from the first LOOT_READY event and that's what we really care about
  if not internal.initialAutoLootState then
    internal.initialAutoLootState = autoLoot or (not autoLoot and GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE"));
  end

  local numItems = GetNumLootItems()
  if numItems == 0 or internal.lastNumLoot == numItems then
    return;
  end

  if IsFishingLoot() and not Config.global.fishingSoundDisabled then
    PlaySound(SOUNDKIT.FISHING_REEL_IN, internal.audioChannel);
  end

  if internal.initialAutoLootState then
    self:SetLootThreshold();
    self:StartLooting(numItems);
  else
    self:ShowLootFrame();
  end

  internal.lastNumLoot = numItems;
end

---@param slot number
function AutoLoot:OnBindConfirm(slot)
  if LootSlotHasItem(slot) and internal.isLooting then
    if internal.gameInfo.BindOnPickup and Config.global.autoConfirm and not (GetNumGroupMembers() > 1) then
      ConfirmLootSlot(slot);
    end
    if internal.isHidden then
      self:ShowLootFrame(true);
    end
  end
end

---@param slot number
function AutoLoot:OnSlotChanged(slot)
  -- was a working workaround for bugged stackables in wrath, but might still be useful to keep
  -- Check if we looted the slot internally and loot it again if it still has a item in the slot.
  -- this should block situations where that event fires but there is still something in the slot we previously looted resulting in unlooted stuff
  if internal.isLooting and internal.slotsLooted[slot] and LootSlotHasItem(slot) then
    self:LootSlot(slot);
  end
end
--[[
function AutoLoot:OnSlotCleared(slot)
  if internal.isLooting then
    if internal.slotsLooted[slot] then
      internal.slotsCleared[slot] = true
    end
  end
end
]]
function AutoLoot:OnLootClosed()
  internal.isLooting = false;
  internal.isHidden = true;
  internal.isAnyItemLocked = false;
  internal.inventorySoundPlayed = false;
  internal.lastNumLoot = nil;
  internal.initialAutoLootState = false;
  internal.lootFailure = false;
  self:CancelLootTicker()
  self:ResetLootFrame();
  -- Workaround for TSM Destroy issue, need to test if this still required
  if TSMDestroyBtn and TSMDestroyBtn:IsVisible() then
    C_Timer.NewTicker(0, function() SlashCmdList.TSM("destroy") end, 2);
  end

  if internal.gameInfo.IsGameWrath then
    wipe(internal.slotsLooted);
  end
end

---@param gameErrorIndex number
---@param message string
function AutoLoot:OnErrorMessage(gameErrorIndex, message)
  if tContains(({ERR_INV_FULL,ERR_ITEM_MAX_COUNT,ERR_LOOT_ROLL_PENDING}), message) then
    if internal.isLooting and internal.isHidden then
      self:ShowLootFrame(true);
    end
    if internal.isLooting and message ~= ERR_LOOT_ROLL_PENDING then
      self:PlayInventoryFullSound();
    end
  end
end

function AutoLoot:PlayInventoryFullSound()
  if Config.global.enableSound and not internal.inventorySoundPlayed and not internal.isAnyItemLocked then
    internal.inventorySoundPlayed = true;
    PlaySound(Config.global.InventoryFullSound, internal.audioChannel);
  end
end

-- Reanchor on Show to make sure the frame appears where it should on delayed actions.
function AutoLoot:AnchorLootFrame()
  local f = LootFrame;
  if GetCVarBool("lootUnderMouse") then
    local x, y = GetCursorPosition();
    f:ClearAllPoints();

    if internal.hasEditModeWithLootWindow then
      x = x / (f:GetEffectiveScale()) - 30;
      y = math.max((y / f:GetEffectiveScale()) + 50, 350);
      f:SetPoint("TOPLEFT", nil, "BOTTOMLEFT", x, y);
    else
      x = x / f:GetEffectiveScale();
      y = y / f:GetEffectiveScale();
      f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x - 40, y + 20);
      f:GetCenter();
    end
    f:Raise();
  else
    if internal.hasEditModeWithLootWindow then
      local scale = f:GetScale();
      ---@diagnostic disable-next-line
      f:SetPoint(f.systemInfo.anchorInfo.point, f.systemInfo.anchorInfo.relativeTo, f.systemInfo.anchorInfo.relativePoint, f.systemInfo.anchorInfo.offsetX / scale, f.systemInfo.anchorInfo.offsetY / scale);
    else
      f:ClearAllPoints();
      f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -125);
    end
  end
  --f:Show()
end

---@param delayed boolean?
function AutoLoot:ShowLootFrame(delayed)
  internal.isHidden = false;
  if internal.ElvUI then
    internal.ShowElvUILootFrame();
    return;
  elseif LootFrame:IsEventRegistered("LOOT_OPENED") then
    LootFrame:SetParent(UIParent);
    LootFrame:SetFrameStrata("HIGH");
    self:AnchorLootFrame();
    if delayed then
      self:AnchorLootFrame();
    end
  end
end

function AutoLoot:ResetLootFrame()
  if not internal.ElvUI and LootFrame:IsEventRegistered("LOOT_OPENED") then
    LootFrame:SetParent(internal._frame);
  end
end

function AutoLoot:SetGameInfo()
  -- Game/Family Expansion broke on 12.1.7 ptr, swapping back to porjectid until maybe there is a proper API on all versions
  -- local Family = C_AddOns.GetAddOnMetadata(addonName, "X-Family")
  -- local Game = C_AddOns.GetAddOnMetadata(addonName, "X-Game")
  local isStandard, isForever, isMists, isClassic, isClassicEra, isWrath = false, false, false, false, false, false

  -- if Family == "Mainline" then
  --   if Game == "Camelot" or Game == "Forever" then
  --     isForever = true;
  --   end
  -- elseif Family == "Classic" then
  --     isClassic = true;
  --   if Game == "Vanilla" or Game == "TBC" then
  --     isClassicEra = true;
  --   elseif Game == "Wrath" then
  --     isWrath = true;
  --   end
  -- end

  if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
    isStandard = true;
  elseif WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
    isClassicEra = true;
    isClassic = true;
  elseif WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC then
    isClassicEra = true;
    isClassic = true;
  elseif WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC then
    isWrath = true;
    isClassic = true;
  elseif WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC then
    isMists = true;
    isClassic = true;
  elseif WOW_PROJECT_ID == WOW_PROJECT_CAMELOT then
    isForever = true;
  end

  local function HasKeyringFeature()
    if IsKeyRingEnabled then
      return IsKeyRingEnabled();
    elseif C_ActionBar and C_ActionBar.ShouldShowKeyring then
      return C_ActionBar.ShouldShowKeyring();
    end
    return false;
  end

  internal.gameInfo = {
    BindOnPickup = LE_EXPANSION_LEVEL_CURRENT < LE_EXPANSION_BATTLE_FOR_AZEROTH and not isForever,
    Keyring = HasKeyringFeature(),
    QuestBag = LE_EXPANSION_LEVEL_CURRENT >= LE_EXPANSION_WARLORDS_OF_DRAENOR,
    TradeskillQuality = LE_EXPANSION_LEVEL_CURRENT >= LE_EXPANSION_DRAGONFLIGHT,
    IsGameStandard = isStandard,
    IsGameForever = isForever,
    IsGameMists = isMists,
    IsGameClassic = isClassic,
    IsGameClassicEra = isClassicEra,
    IsGameWrath = isWrath,
  }
  self.gameInfo = internal.gameInfo
end

---@param name string
function AutoLoot:OnAddonLoaded(name)
  if name == addonName then
    SpeedyAutoLootDB = SpeedyAutoLootDB or {};
    Config = SpeedyAutoLootDB;
    Config.global = Config.global or {};

    self:SetGameInfo()

    if internal.gameInfo.BindOnPickup then
      self:InitBindOnPickup();
    end

    if internal.gameInfo.IsGameWrath then
      self:RegisterEvent("LOOT_SLOT_CHANGED", self.OnSlotChanged);
    end

    if Config.global.alwaysEnableAutoLoot then
      C_CVar.SetCVar("autoLootDefault", "1");
    end

    if not Config.global.InventoryFullSound then
      if internal.gameInfo.IsGameStandard then
        Config.global.InventoryFullSound = 44321;
      else
        Config.global.InventoryFullSound = 139;
      end
    end

    C_Timer.After(1, function()
      if (ElvUI and ElvUI[1].private.general.loot) and ElvUI[1]:GetModule("Misc").LOOT_OPENED then
        internal.ElvUI = true;
        local elvOnLootOpened = ElvUI[1]:GetModule("Misc").LOOT_OPENED;
        ElvUI[1]:GetModule("Misc").LOOT_OPENED = nop;
        internal.ShowElvUILootFrame = elvOnLootOpened
      end
      C_Timer.After(5, function() self:ResetLootFrame(); end)
    end)
  end
end

function AutoLoot:RegisterEvent(event, func)
  if not internal._frame:IsEventRegistered(event) then
    internal._frame[event] = func;
    internal._frame:RegisterEvent(event);
  end
end

function AutoLoot:UnregisterEvent(event)
  if internal._frame:IsEventRegistered(event) then
    internal._frame[event] = nil;
    internal._frame:UnregisterEvent(event);
  end
end

function AutoLoot:OnInit()
  internal._frame:SetToplevel(true);
  internal._frame:Hide();

  self:RegisterEvent("ADDON_LOADED", self.OnAddonLoaded);
  self:RegisterEvent("LOOT_READY", self.OnLootReady);
  self:RegisterEvent("LOOT_OPENED", self.OnLootReady);
  self:RegisterEvent("LOOT_CLOSED", self.OnLootClosed);
  self:RegisterEvent("UI_ERROR_MESSAGE", self.OnErrorMessage);

  if not internal.ElvUI and LootFrame:IsEventRegistered("LOOT_OPENED") then
    if internal.hasEditModeWithLootWindow then
      hooksecurefunc(LootFrame, "UpdateShownState", function(self)
        if self.isInEditMode then
          self:SetParent(UIParent)
        else
          self:SetParent(internal._frame)
        end
      end);
    end
  end

  internal._frame:SetScript("OnEvent", function(_,event,...) internal._frame[event](self, ...) end);
end
AutoLoot:OnInit();

function AutoLoot:OnGroupJoined()
  UIParent:RegisterEvent("LOOT_BIND_CONFIRM");
end
function AutoLoot:OnGroupLeft()
  UIParent:UnregisterEvent("LOOT_BIND_CONFIRM");
end

function AutoLoot:AutoConfirmBop()
  if Config.global.autoConfirm then
    self:RegisterEvent("GROUP_LEFT", self.OnGroupLeft);
    self:RegisterEvent("GROUP_JOINED", self.OnGroupJoined);
    -- group events don't fire on a /reload and probably also not when you login while already in a group
    if GetNumGroupMembers() > 1 then
      self:OnGroupJoined();
    else
      self:OnGroupLeft();
    end
  else
    self:UnregisterEvent("GROUP_LEFT");
    self:UnregisterEvent("GROUP_JOINED");
    self:OnGroupJoined();
  end
end

function AutoLoot:InitBindOnPickup()
  self:RegisterEvent("LOOT_BIND_CONFIRM", self.OnBindConfirm);
  self:AutoConfirmBop()
end

local function AddMessage(...) _G.DEFAULT_CHAT_FRAME:AddMessage(strjoin(" ", tostringall(...))) end;
function AutoLoot:Help(msg)
  local fName = "|cffEEE4AESpeedy AutoLoot:|r ";
  local cmd, args = string.match(msg, "%s?(%w+)%s?(.*)")
  if not cmd or cmd == "" or cmd == "help" then
    AddMessage(fName.."   |cff58C6FA/sal    /speedyautoloot    /speedyloot|r");
    AddMessage("  |cff58C6FA/sal display -|r |cffEEE4AEToggle the Loot Display, Default: Off|r");
    AddMessage("  |cff58C6FA/sal anchor -|r |cffEEE4AEToggle the Loot Display anchor|r");
    AddMessage("  |cff58C6FA/sal fish -|r |cffEEE4AEDisable Fishing reel in sound, Default: Off|r");
    AddMessage("  |cff58C6FA/sal sound -|r |cffEEE4AEPlay a Sound when Inventory is full while looting, Default: Off|r,");
    if internal.gameInfo.IsGameStandard then
      AddMessage("  |cff58C6FA/sal set (SoundID) -|r |cffEEE4AESet a Sound (SoundID), Default: 44321|r");
    else
      AddMessage("  |cff58C6FA/sal set (SoundID) -|r |cffEEE4AESet a Sound (SoundID), Default: 139|r");
    end
    if internal.gameInfo.BindOnPickup then
      AddMessage("  |cff58C6FA/sal bop -|r |cffEEE4AEAuto Confirm Bind on Pickups when solo, Default: Off|r");
    end
    AddMessage("  |cff58C6FA/sal auto -|r |cffEEE4AEEnable Auto Looting for all characters (Legacy)|r");
  elseif cmd == "fish" then
    if not Config.global.fishingSoundDisabled then
      AddMessage(fName.."|cffB6B6B6Fishing reel in sound disabled.");
    else
      AddMessage(fName.."|cff37DB33Fishing reel in sound enabled.");
    end
    Config.global.fishingSoundDisabled = not Config.global.fishingSoundDisabled;
  elseif cmd == "auto" then
    if Config.global.alwaysEnableAutoLoot then
      AddMessage(fName.."|cffB6B6B6Auto Loot for all Characters disabled.");
      C_CVar.SetCVar("autoLootDefault", "0");
    else
      AddMessage(fName.."|cff37DB33Auto Loot for all Characters enabled.");
      C_CVar.SetCVar("autoLootDefault", "1");
    end
    Config.global.alwaysEnableAutoLoot = not Config.global.alwaysEnableAutoLoot;
  elseif cmd == "sound" then
    if Config.global.enableSound then
      AddMessage(fName.."|cffB6B6B6Don't play a sound when inventory is full.");
    else
      AddMessage(fName.."|cff37DB33Play a sound when inventory is full.");
    end
    Config.global.enableSound = not Config.global.enableSound;
  elseif cmd == "set" and args ~= "" then
    local SoundID = tonumber(args:match("%d+"));
    if SoundID then
      Config.global.InventoryFullSound = tonumber(args:match("%d+"));
      PlaySound(SoundID, internal.audioChannel);
      AddMessage(fName.."Set Sound|r |cff37DB33"..SoundID.."|r");
    end
  elseif cmd == "anchor" then
    if InCombatLockdown() then
        AddMessage(fName.."|cffFF0000Cannot move Loot Display in combat.");
    else
        AutoLoot:ToggleLootDisplay();
    end
  elseif cmd == "display" then
      Config.global.lootDisplayEnabled = not Config.global.lootDisplayEnabled;
      AddMessage(fName..(Config.global.lootDisplayEnabled and "|cff37DB33Loot Display Enabled." or "|cffB6B6B6Loot Display Disabled."));
  elseif internal.gameInfo.BindOnPickup and cmd == "bop" then
    if Config.global.autoConfirm then
      AddMessage(fName.."|cffB6B6B6Automatically confirm loot when solo disabled.");
    else
      AddMessage(fName.."|cff37DB33Automatically confirm loot when solo enabled.");
    end
    Config.global.autoConfirm = not Config.global.autoConfirm
    AutoLoot:AutoConfirmBop()
  end
end

SLASH_SPEEDYAUTOLOOT1, SLASH_SPEEDYAUTOLOOT2  = "/sal", "/speedyautoloot";
function SlashCmdList.SPEEDYAUTOLOOT(...)
  AutoLoot:Help(...);
end