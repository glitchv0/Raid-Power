-- Auras.lua: who has which buff and for how long. Aura reads are gated on C_Secrets.ShouldAurasBeSecret()
-- and wrapped in pcall (the client can raise when aura access is withdrawn). While auras are hidden, the last
-- readable state is kept and its timers keep counting down, so bars do not turn red in combat.
local _, RP = ...

local Secret, Readable = RP.Secret, RP.Readable
local FAMILY = RP.SPELL_FAMILY
local MAX_AURAS = 40

RP.auraCache = {}   -- guid -> { map = { key = { expires, duration, mine } }, at = GetTime(), stale = bool }

local function ReadUnit(unit)
    local map = {}
    for i = 1, MAX_AURAS do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
        if not aura then return map, true end
        local id = aura.spellId
        if Secret(id) then return map, false end
        local key = FAMILY[id]
        if key and not map[key] then
            local expires, duration = aura.expirationTime, aura.duration
            if Secret(expires) or not expires then expires = 0 end
            if Secret(duration) or not duration then duration = 0 end
            local src = aura.sourceUnit
            local mine = Readable(src) and src == "player" or false
            map[key] = { expires = expires, duration = duration, mine = mine, spell = id }
        end
    end
    return map, true
end

-- Scan one roster member. Returns the cache entry (possibly stale) or nil.
function RP.ScanUnit(m)
    local cache = RP.auraCache[m.guid]
    if RP.AurasHidden() then
        if cache then cache.stale = true end
        return cache
    end
    local ok, map, complete = pcall(ReadUnit, m.unit)
    if not ok or not complete then
        if cache then cache.stale = true end
        return cache
    end
    cache = cache or {}
    cache.map, cache.at, cache.stale = map, GetTime(), false
    RP.auraCache[m.guid] = cache
    return cache
end

function RP.ScanAll()
    for _, m in ipairs(RP.roster) do RP.ScanUnit(m) end
end

-- has: true / false / nil (unknown). remaining: seconds, or nil for no expiry.
function RP.BuffStatus(m, key)
    local cache = RP.auraCache[m.guid]
    if not cache or not cache.map then return nil end
    local a = cache.map[key]
    if not a then
        if cache.stale then return nil end
        return false
    end
    if a.expires and a.expires > 0 then
        local left = a.expires - GetTime()
        if left <= 0 then
            if cache.stale then return false, 0 end
            return false, 0
        end
        return true, left, a.duration, a
    end
    return true, nil, a.duration, a
end

-- After our own successful cast while auras are hidden, assume it landed so the bar stops asking for it.
function RP.NoteCast(m, key, duration)
    if not (m and key) then return end
    local cache = RP.auraCache[m.guid] or { map = {}, at = GetTime(), stale = true }
    cache.map = cache.map or {}
    cache.map[key] = { expires = duration and duration > 0 and (GetTime() + duration) or 0, duration = duration or 0, mine = true }
    RP.auraCache[m.guid] = cache
end

-- Temporary weapon enchants. slot 16 = main hand, 17 = off hand. Returns has, secondsLeft.
function RP.WeaponEnchant(slot)
    if C_Item and C_Item.GetWeaponEnchantInfo then
        local ok, list = pcall(C_Item.GetWeaponEnchantInfo, slot == 16 and 0 or 1)
        if ok and type(list) == "table" then
            for _, e in pairs(list) do
                if type(e) == "table" and e.hasEnchant and not Secret(e.hasEnchant) then
                    local left = e.timeLeft
                    return true, (Readable(left) and left) and left / 1000 or nil
                end
            end
            return false
        end
    end
    if GetWeaponEnchantInfo then
        local hasMH, mhLeft, _, _, hasOH, ohLeft = GetWeaponEnchantInfo()
        if slot == 16 then return hasMH and true or false, mhLeft and mhLeft / 1000 end
        return hasOH and true or false, ohLeft and ohLeft / 1000
    end
    return nil
end

function RP.ForgetUnit(guid) RP.auraCache[guid] = nil end
