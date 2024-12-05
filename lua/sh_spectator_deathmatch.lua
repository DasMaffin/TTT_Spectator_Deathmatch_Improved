include("specdm_config.lua")
include("specdm_von.lua")

if SpecDM.AutoIncludeWeapons then
    SpecDM.Ghost_weapons.primary = {}
    SpecDM.Ghost_weapons.secondary = {}
    SpecDM.Loadout_Icons = {}

    -- Function to wrap methods and ensure base calls
    local function wrapMethodWithBaseCall(weapon, methodName)
        if weapon[methodName] then
            local originalMethod = weapon[methodName]

            -- Wrap the method
            weapon[methodName] = function(self, ...)
                originalMethod(self, ...)
                -- Call the parent class method if it exists
                if self.BaseClass and self.BaseClass[methodName] then
                    return self.BaseClass[methodName](self, ...)
                end
            end
        end
    end

    hook.Add("Initialize", "SharedInitialize_Ghost", function()
        -- Create ghost variants of every primary/secondary non T/D weapon
        for _, weapon in ipairs(weapons.GetList()) do
            if weapon.Kind 
            and weapon.Base == "weapon_tttbase" 
            and weapon.CanBuy == nil 
            and (weapon.Kind == WEAPON_HEAVY or weapon.Kind == WEAPON_PISTOL) 
            and weapon.ClassName:match("^weapon_%w+_%w+$") then -- THIS NAMING CONVENTION IS IMPORTANT! ANY OTHER WILL BREAK THE REST OF THE MOD MAKING GUNS NOT SPAWN

                -- Create a copy of the weapon
                local ghostWeapon = table.Copy(weapon)
                ghostWeapon.SoundLevel = 0
                ghostWeapon.Base = "weapon_ghost_base" -- Change the inheritance
                ghostWeapon.ClassName = weapon.ClassName:gsub("^weapon_[^_]+_", "weapon_ghost_") -- THIS NAMING CONVENTION IS IMPORTANT! ANY OTHER WILL BREAK THE REST OF THE MOD MAKING GUNS NOT SPAWN
                ghostWeapon.AutoSpawnable = false
                ghostWeapon.Primary.DefaultClip = 90
                ghostWeapon.Primary.Ammo = weapon.Primary.Ammo

                -- Wrap methods like Reload to ensure base methods are called
                wrapMethodWithBaseCall(ghostWeapon, "Reload")

                -- Register the new weapon
                weapons.Register(ghostWeapon, ghostWeapon.ClassName)
            end
        end

        for _, w in ipairs(weapons.GetList()) do
            if w.Kind and w.Base == "weapon_ghost_base" and (w.Kind == WEAPON_HEAVY or w.Kind == WEAPON_PISTOL) then
                if w.Kind == WEAPON_HEAVY then
                    table.insert(SpecDM.Ghost_weapons.primary, w.ClassName)
                else
                    table.insert(SpecDM.Ghost_weapons.secondary, w.ClassName)
                end

                if w.Icon then
                    SpecDM.Loadout_Icons[w.ClassName] = w.Icon
                end
            end
        end
    end)
end


local meta = FindMetaTable("Player")

function meta:IsGhost()
	return self:GetNWBool("SpecDM_Enabled", false)
end

hook.Add("PlayerFootstep", "PlayerFootstep_Ghost", function(ply, pos, foot, sound, volume, rf)
	if ply:IsGhost() then
		return true
	end
end)

hook.Add("OnEntityCreated", "OnEntityCreated_Ghost", function(ent)
	if ent:IsPlayer() then
		ent:SetCustomCollisionCheck(true)
	end

	if SERVER and ent:IsNPC() then
		for _, v in ipairs(player.GetAll()) do
			if v:IsGhost() then
				ent:AddEntityRelationship(v, D_NU, 99)
			end
		end
	end
end)

hook.Add("ShouldCollide", "ShouldCollide_Ghost", function(ent1, ent2)
	if IsValid(ent1) and IsValid(ent2) then
		if ent1:IsPlayer() and ent1:IsGhost() and not (ent2:IsPlayer() and ent2:IsGhost()) then
			return false
		end

		if ent2:IsPlayer() and ent2:IsGhost() and not (ent1:IsPlayer() and ent1:IsGhost()) then
			return false
		end
	end
end)

hook.Add("Move", "Move_Ghost", function(ply, mv)
	if ply:IsGhost() then
		local basemul = 1
		local slowed = false
		local wep = ply:GetActiveWeapon()

		if IsValid(wep) and wep.GetIronsights and wep:GetIronsights() then
			basemul = 120 / 220
			slowed = true
		end

		local mul = hook.Call("TTTPlayerSpeedModifier", GAMEMODE, ply, slowed, mv) or 1
		mul = basemul * mul

		mv:SetMaxClientSpeed(mv:GetMaxClientSpeed() * mul)
		mv:SetMaxSpeed(mv:GetMaxSpeed() * mul)
	end
end)
