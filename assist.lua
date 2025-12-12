local STEER_SENSI = 13 -- Steering response speed multiplier
local FFB_GAIN = 3.2 -- Strength of FFB effect
local GYRO_GAIN = 4.6 -- Strength of gyro sensor
local MOUSE_SENSI = 25 -- Raw Mouse input multiplier
local VELOCITY_ANGLE_SMOOTHING = 0.15 -- Smoothing for drift angle (0.05=very smooth, 0.3=responsive, 1.0=instant/no smoothing)

-- Transition Mode Configuration (Left Mouse Button)
-- Boost steering SPEED while reducing FFB resistance - drift tracking stays intact
-- Pressing LMB will ramp in transition mode, releasing will ramp out
local TRANSITION_STEER_SPEED_BOOST = 1.0 -- How much faster steering responds during transition
local TRANSITION_FFB_REDUCTION = 0.7 -- FFB multiplier during transition
local TRANSITION_GYRO_REDUCTION = 0.7 -- Gyro multiplier during transition
local TRANSITION_RAMP_TIME_PRESS = 0.55 -- Time to ramp IN when LMB pressed (0% to 100%)
local TRANSITION_RAMP_TIME_RELEASE = 0.15 -- Time to ramp OUT when LMB released (100% to 0%)

-- Braking Configuration Variables
local BRAKE_CAP = 0.35 -- Maximum braking force (0.0 to 1.0) - limits how hard the brakes can be applied
local BRAKE_SMOOTHNESS = 0.15 -- Braking smoothness factor (0.0 to 1.0) - higher values = smoother braking transitions

local gas = 0
local brake = 0
local targetBrake = 0
local targetGas = 0 	

local kmh = 0

local steerAngle = 0
local steerVelocity = 0
local MidSteer = 0
local mouseSteer = 0
local keySteerHB = 0
local keySteerCL = 0
local transitionBlend = 0 -- 0 = normal, 1 = full transition mode (smoothly interpolated)
local smoothedVelocityAngle = 0 -- Smoothed version of velocity angle to prevent oscillation

local gameCfg = ac.INIConfig.load(ac.getFolder(ac.FolderID.Cfg) .. "\\controls.ini")

if gameCfg then
	keySteerHB = gameCfg:get("HANDBRAKE", "KEY", keySteerHB)
	keySteerCL = gameCfg:get("CLUTCH", "KEY", keySteerCL)
end

local STOP_AUTO_CLUTCH = true -- Automatically engages clutch when stopped. true to enable, false to disable.
local HANDBRAKE_CLUTCH_LINK = true

-- Reset steering angle when car is reset (probably)
ac.onCarJumped(0, function()
	steerAngle = 0
	steerVelocity = 0
end)

function script.update(dt, deltaX)
	local data = ac.getJoypadState()
	local car = ac.getCar(0)

	-- Safety check for deltaX
	deltaX = deltaX or 0

	mouseSteer = math.clamp(mouseSteer + deltaX * MOUSE_SENSI, -1, 1)
	local kmh = math.clamp(1 - data.speedKmh / 1, 0.9999, 1)
	MidSteer = math.clamp(mouseSteer * kmh, -1, 1)

	local tyreSpeed = {}
	tyreSpeed[0] = car.wheels[0].angularSpeed * car.wheels[0].tyreRadius
	tyreSpeed[1] = car.wheels[1].angularSpeed * car.wheels[1].tyreRadius

	local isDrive = math.min(data.speedKmh / 36, 1)
	local isForward = math.clamp(tyreSpeed[0] + tyreSpeed[1], 0, 10) / 10
	local rawVelocityAngle = math.atan2(car.localVelocity.x, car.localVelocity.z) / (math.pi / 2.75) * isDrive * isForward
	
	-- Smooth the velocity angle to prevent feedback loop oscillation
	-- Lower smoothing = more stable but slower reaction, higher = more responsive but can oscillate
	smoothedVelocityAngle = smoothedVelocityAngle + (rawVelocityAngle - smoothedVelocityAngle) * VELOCITY_ANGLE_SMOOTHING
	local velocityAngle = smoothedVelocityAngle

	if velocityAngle < 0 and kmh < 0.551 then
		MidSteer = math.clamp(mouseSteer * kmh, -0.35, 0.55)
	end
	if velocityAngle > 0 and kmh < 0.551 then
		MidSteer = math.clamp(mouseSteer * kmh, -0.55, 0.35)
	end

	-- Calculate steering velocity
	-- Transition mode: boost steering speed + reduce FFB resistance when LMB held
	-- VK_LBUTTON = 1 (Windows virtual key code for left mouse button)
	local isTransitionMode = ac.isKeyDown(1)
	
	-- Smooth ramp: blend toward 1 when LMB held, toward 0 when released
	local targetBlend = isTransitionMode and 1.0 or 0.0
	if transitionBlend < targetBlend then
		-- Pressing: ramp up
		local rampSpeed = 1.0 / math.max(TRANSITION_RAMP_TIME_PRESS, 0.001)
		transitionBlend = math.min(transitionBlend + rampSpeed * dt, targetBlend)
	else
		-- Releasing: ramp down
		local rampSpeed = 1.0 / math.max(TRANSITION_RAMP_TIME_RELEASE, 0.001)
		transitionBlend = math.max(transitionBlend - rampSpeed * dt, targetBlend)
	end
	
	-- Interpolate multipliers based on blend (0 = normal values, 1 = transition values)
	local steerSpeedMultiplier = 1.0 + (TRANSITION_STEER_SPEED_BOOST - 1.0) * transitionBlend
	local ffbMultiplier = 1.0 + (TRANSITION_FFB_REDUCTION - 1.0) * transitionBlend
	local gyroMultiplier = 1.0 + (TRANSITION_GYRO_REDUCTION - 1.0) * transitionBlend
	
	-- VelocityAngle stays at 100% - steering still follows drift angle
	-- But steering SPEED is boosted and FFB resistance is reduced
	steerVelocity = (MidSteer - velocityAngle - steerAngle) * STEER_SENSI * steerSpeedMultiplier
		- data.ffb * FFB_GAIN * ffbMultiplier
		+ data.localAngularVelocity.y * GYRO_GAIN * isForward * gyroMultiplier -- Helps countersteering (reduce GYRO_GAIN if oscillating)

	steerAngle = math.clamp(steerAngle + steerVelocity * 450 / data.steerLock * dt, -1, 1)

	if ac.isKeyDown(keySteerHB) then
		data.clutch = 0
		data.handbrake = 1
	end

	if STOP_AUTO_CLUTCH then
		data.clutch = data.clutch * math.clamp((car.rpm - 1000) / 2000, 0, 1)
	end

	if HANDBRAKE_CLUTCH_LINK then
		data.clutch = math.min(data.clutch, 1 - data.handbrake)
	end

	data.steer = steerAngle

	-- Braking Logic with Cap and Smoothness
	-- Apply brake cap to limit maximum braking force
	targetBrake = math.clamp(data.brake * BRAKE_CAP, 0, BRAKE_CAP)
	targetGas = data.gas
	
	-- Smooth braking transitions to prevent jitter and improve control
	brake = brake + (targetBrake - brake) * BRAKE_SMOOTHNESS
	gas = gas + (targetGas - gas) * BRAKE_SMOOTHNESS
	
	-- Apply the smoothed values back to the data
	data.brake = brake
	data.gas = gas

	-- Debug display
	ac.debug("MidSteer", MidSteer)
	ac.debug("GYRO_GAIN", GYRO_GAIN)
	ac.debug("steerAngle", steerAngle)
	ac.debug("velocityAngle", velocityAngle)
	ac.debug("kmh", kmh)
	ac.debug("brake", brake)
	ac.debug("targetBrake", targetBrake)
	ac.debug("gas", gas)
	ac.debug("deltaX", deltaX)
	ac.debug("mouseSteer", mouseSteer)
	ac.debug("transitionBlend", transitionBlend)


	-- Reset process when steering goes out of bounds
	if data.steer ~= data.steer then
		steerAngle = 0
		data.steer = 0
	end
end