--[[
================================================================================
  [IRNV_FPS] V1 — INSTALLATION GUIDE
================================================================================

  This .rbxm contains four labeled folders. Drag each one's CONTENTS into
  the matching Roblox service:

    1. "[Drop into] ReplicatedStorage"
         → ReplicatedStorage

    2. "[Drop into] ServerScriptService"
         → ServerScriptService

    3. "[Drop into] StarterPlayerScripts"
         → StarterPlayer.StarterPlayerScripts

    4. "[Drop into] StarterCharacterScripts" (if present)
         → StarterPlayer.StarterCharacterScripts

  After dropping the children into their services, delete this install package
  folder along with this README.

================================================================================
  REQUIRED ASSETS (NOT INCLUDED — YOU MUST PROVIDE)
================================================================================

  Inside ReplicatedStorage["[IRNV_FPS] V1 (REP)"] you must populate:

    • Viewmodel/<ViewmodelName>     — first-person rig (Model)
    • WeaponModels/<WeaponName>     — third-person weapon model (Model)
    • WeaponConfig/<WeaponName>     — per-weapon ModuleScript (see Glock17/M4A1)
    • WeaponEffects/Sound/Whiz/...  — Sound objects, grouped by category
    • WeaponEffects/Visual/Muzzle/  — muzzle flash templates
    • WeaponEffects/Visual/Tracers/ — tracer templates

  See GlobalConfig.luau for tunables (sensitivity, recoil, ADS, crouch keys).

================================================================================
  CONFIGURATION ENTRY POINT
================================================================================

  ReplicatedStorage > [IRNV_FPS] V1 (REP) > GlobalConfig

  Set:
    GlobalConfig.Viewmodel        — name of the Viewmodel rig to load
    GlobalConfig.Crouch.Animations.Idle / .Walk
    GlobalConfig.Sounds.*         — global UI sounds (fire-mode swap, empty mag)

================================================================================
  LICENSE
================================================================================

  Free and open-source. Programmed by Filip Jurczak.

--]]

return {}
