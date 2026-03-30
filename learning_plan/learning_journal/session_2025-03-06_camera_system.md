# Learning Session: March 6, 2025 - Camera System Implementation

## Session Overview
Implementing camera controls for 3D navigation - WASD movement and mouse look.

---

## Key Questions & Explorations

### 1. Constructor Pattern for Default Values
**Question**: "Since Odin is flat and doesn't let me provide defaults for structs, should I make a function to provide default values?"

**Answer**: Yes. That's the standard pattern.

**Why it's useful**:
- Centralizes default configuration
- Makes initialization consistent
- Documents what "reasonable defaults" are
- Easy to change defaults in one place

**Pattern**:
```odin
Camera :: struct {
    position: [3]f32,
    yaw: f32,
    pitch: f32,
    speed: f32,
    // ...
}

camera_create :: proc(position: [3]f32 = {0, 0, 3}) -> Camera {
    return Camera{
        position = position,
        front = {0, 0, -1},
        up = {0, 1, 0},
        yaw = -90.0,        // Face -Z
        pitch = 0.0,
        speed = 2.5,
        sensitivity = 0.1,
    }
}
```

**Alternative without constructor**: Direct initialization every time (tedious, error-prone):
```odin
cam := Camera{
    position = {0, 0, 3},
    front = {0, 0, -1},
    // ... repeat magic numbers everywhere
}
```

**Best practice**: Write a constructor proc. Clean, clear, maintainable.

---

### 2. Cross Product for Strafe Movement
**Question**: "In the document when handling input, `la.cross` is used - should it be `vector_cross`?"

**Answer**: `la.cross` is correct. It's the cross product function from `core:math/linalg`.

**What it does**:
Cross product of two vectors gives a third vector perpendicular to both.

```odin
right := la.cross(front, up)
```

- `front` = direction camera looks (forward vector)
- `up` = {0, 1, 0} (world up)
- `right` = perpendicular to both (camera's right direction)

**Why for strafing**:
- W/S: Move along `front` vector (forward/back)
- A/D: Move along `right` vector (left/right strafe)

`la.normalize(la.cross(front, up))` gives you the normalized right vector for sideways movement.

**There is no `vector_cross`**: Odin's linalg package uses `cross`, not `vector_cross`.

---

### 3. Alternative Input Scheme: Alt + Middle Mouse for Pan
**Question**: "Instead of WASD for movement, I want to use Alt + middle mouse drag."

**Context**: This is standard in 3D DCC tools (Maya, Blender, Houdini). Professional workflow pattern.

**Implementation approach**:

**Track mouse button + modifier state**:
- Check if Alt key is down: `glfw.GetKey(window, glfw.KEY_LEFT_ALT)`
- Check if middle mouse is pressed: `glfw.GetMouseButton(window, glfw.MOUSE_BUTTON_MIDDLE)`
- Track mouse delta (current pos - last pos)

**Pan movement**:
```odin
camera_process_pan :: proc(cam: ^Camera, delta_x, delta_y: f32, delta_time: f32) {
    right := la.normalize(la.cross(cam.front, cam.up))

    // Move camera along right vector (X delta) and up vector (Y delta)
    cam.position -= right * delta_x * cam.pan_speed * delta_time
    cam.position += cam.up * delta_y * cam.pan_speed * delta_time
}
```

**In main loop**:
```odin
// Track mouse position
current_mouse_x, current_mouse_y := glfw.GetCursorPos(g_window)
delta_x := f32(current_mouse_x - last_mouse_x)
delta_y := f32(current_mouse_y - last_mouse_y)

// Check Alt + Middle Mouse
if glfw.GetKey(g_window, glfw.KEY_LEFT_ALT) == glfw.PRESS &&
   glfw.GetMouseButton(g_window, glfw.MOUSE_BUTTON_MIDDLE) == glfw.PRESS {
    camera_process_pan(&camera, delta_x, delta_y, delta_time)
}
```

**DCC-style camera controls**:
- Alt + LMB = Orbit/rotate around target
- Alt + MMB = Pan (translate camera)
- Alt + RMB = Dolly/zoom (move forward/back)
- Scroll wheel = Zoom

**Decision needed**: Full DCC controls, or just Alt+MMB pan for now?

---
