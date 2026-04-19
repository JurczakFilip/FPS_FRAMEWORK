local Modules = {
    CameraHandler = require(script.Parent.Modules.CameraHandler),
    LeanHandler   = require(script.Parent.Modules.LeanHandler),
}

-- CameraHandler must run first — it disables AutoRotate and controls body yaw
local CameraHandler = Modules.CameraHandler.Setup()
local LeanHandler   = Modules.LeanHandler.Setup()

