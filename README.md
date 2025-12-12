# A7 Mouse Steering Assist

A refined mouse steering assist script for Assetto Corsa with drift-focused features for smooth and controllable arcade-style drifting.

---

## ✨ Features

### 🎯 Transition Mode (Left Mouse Button)
Hold **LMB** to reduce steering assist for easier transitions during drifts.

- **Problem solved:** Strong assist makes the car lazy to rotate, requiring excessive mouse flicking
- **Solution:** LMB reduces FFB and gyro assist (default: 30% reduction) so you can transition faster
- **Smooth ramping:** Transitions feel natural, not like an on/off switch
- Fully configurable press/release ramp times

### 🔄 Velocity Angle Smoothing
Eliminates random oversteer and oscillation during drifts.

- **Problem solved:** Steering would overshoot and add more angle than intended
- **Solution:** Smoothed velocity angle prevents the feedback loop that caused instability
- Result: Smooth, consistent drift angles without the "dynamic overcorrection"

### 🖱️ Mouse Sensitivity Control
Adjust steering sensitivity directly in the script—no need to change your mouse DPI.

```lua
local MOUSE_SENSI = 25 -- use this instead of changing your mouse DPI
```

---

## ⚙️ Configuration

All settings are at the top of `assist.lua`:

### Core Settings
| Setting | Default | Description |
|---------|---------|-------------|
| `STEER_SENSI` | 13 | Steering response speed |
| `FFB_GAIN` | 3.2 | Force feedback strength |
| `GYRO_GAIN` | 4.6 | Gyro sensor strength |
| `MOUSE_SENSI` | 25 | Mouse input multiplier |
| `VELOCITY_ANGLE_SMOOTHING` | 0.15 | Drift angle smoothing (lower = more stable) |

### Transition Mode (LMB)
| Setting | Default | Description |
|---------|---------|-------------|
| `TRANSITION_FFB_REDUCTION` | 0.7 | FFB multiplier when LMB held (0.7 = 70%) |
| `TRANSITION_GYRO_REDUCTION` | 0.7 | Gyro multiplier when LMB held |
| `TRANSITION_STEER_SPEED_BOOST` | 1.0 | Steering speed multiplier during transition |
| `TRANSITION_RAMP_TIME_PRESS` | 0.55 | Seconds to ramp in when pressing LMB |
| `TRANSITION_RAMP_TIME_RELEASE` | 0.15 | Seconds to ramp out when releasing LMB |

---

## 🎮 How to Use

1. **Normal Drifting:** Full assist keeps steering locked to drift angle
2. **Transitioning:** Hold **LMB** → assist reduces → flick mouse to new direction → release **LMB**
3. **Tune to taste:** Adjust values in `assist.lua` to match your driving style


---

## 🔧 Troubleshooting

| Issue | Solution |
|-------|----------|
| Steering oscillates/overshoots | Lower `VELOCITY_ANGLE_SMOOTHING` (try 0.08) |
| Car too lazy to rotate | Lower `FFB_GAIN` and `GYRO_GAIN` |
| Transitions still sluggish | Lower `TRANSITION_FFB_REDUCTION` (try 0.5) |
| Steering too sensitive | Lower `MOUSE_SENSI` |
