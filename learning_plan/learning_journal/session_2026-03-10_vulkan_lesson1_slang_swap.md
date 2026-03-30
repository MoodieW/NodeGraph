# Session 2026-03-10: Vulkan Lesson 1 Start + Slang Pivot

**Date**: 2026-03-10
**Phase**: Phase 1 - Vulkan Bootstrap
**Current Lesson**: Lesson 1 (Instance + Debug Messenger)
**Status**: In progress - segfault before instance creation

---

## Session Overview

This session had two main objectives:
1. **Strategic pivot**: Swap shader language from GLSL to Slang
2. **Debugging**: Fix segfault in `editor/main.odin` preventing Vulkan instance creation

---

## Part 1: GLSL → Slang Migration

### Decision Rationale

Chose to switch from GLSL to Slang for shader development:

**Why Slang?**
- Industry momentum: NVIDIA, Epic, and production pipelines adopting it
- Multi-backend compilation: Single source → SPIR-V, DXIL, Metal, etc.
- Better tooling and type system
- Learning investment aligns with industry direction (same logic as choosing Vulkan over OpenGL)

**Trade-offs:**
- Additional complexity in learning project
- Less documentation/examples than GLSL
- More modern, less "standard" (but that's the point)

### Files Updated

1. **`flake.nix`**:
   - Removed: `glslls`, `glsl_analyzer`
   - Added: `slang`

2. **`CLAUDE.md`**:
   - Updated shader compilation commands
   - Changed from `glslc` to `slangc` with appropriate flags

3. **`3d_editor_vulkan_learning_plan.md`**:
   - Updated shader examples (GLSL → Slang)
   - Changed compilation commands

4. **`vulkan_lessons/lesson_09_triangle.md`**:
   - Rewrote shader from separate `.vert`/`.frag` GLSL files
   - Single `triangle.slang` file with multiple entry points
   - Updated compilation section

### Key Differences: GLSL vs Slang

| Aspect | GLSL | Slang |
|--------|------|-------|
| **File structure** | Separate `.vert`/`.frag` files | Single `.slang` file, multiple entry points |
| **Entry points** | `void main()` | `[shader("vertex")]` attribute + named function |
| **Semantics** | `layout(location = N)` | HLSL-style semantics (`:SV_Position`, `:COLOR`) |
| **Compilation** | `glslc file.vert -o file.spv` | `slangc file.slang -target spirv -entry vertexMain -stage vertex -o file.spv` |
| **Arrays** | `vec2[]` constructor syntax | C-style `float2[]` initialization |

### Example: Triangle Shader

**Before (GLSL - two files):**
```glsl
// triangle.vert
#version 450
layout(location = 0) out vec3 fragColor;
void main() {
    gl_Position = vec4(positions[gl_VertexIndex], 0.0, 1.0);
    fragColor = colors[gl_VertexIndex];
}

// triangle.frag
#version 450
layout(location = 0) in vec3 fragColor;
layout(location = 0) out vec4 outColor;
void main() {
    outColor = vec4(fragColor, 1.0);
}
```

**After (Slang - one file):**
```slang
[shader("vertex")]
float4 vertexMain(uint vertexID : SV_VertexID, out float3 fragColor : COLOR) : SV_Position
{
    static const float2 positions[3] = { /* ... */ };
    static const float3 colors[3] = { /* ... */ };
    fragColor = colors[vertexID];
    return float4(positions[vertexID], 0.0, 1.0);
}

[shader("fragment")]
float4 fragmentMain(float3 fragColor : COLOR) : SV_Target
{
    return float4(fragColor, 1.0);
}
```

**Compilation:**
```bash
# GLSL (old)
glslc shaders/triangle.vert -o shaders/triangle.vert.spv
glslc shaders/triangle.frag -o shaders/triangle.frag.spv

# Slang (new)
slangc shaders/triangle.slang -target spirv -entry vertexMain -stage vertex -o shaders/triangle.vert.spv
slangc shaders/triangle.slang -target spirv -entry fragmentMain -stage fragment -o shaders/triangle.frag.spv
```

---

## Part 2: Vulkan Instance Creation - Segfault Debugging

### Problem

`editor/main.odin` segfaulting **before** `vk.CreateInstance()` call.

**Console output:**
```
1
2
2  (duplicate print - line 132)
3
12
Creating application info
Getting extensions
Creating instance info
Creating Instances
[segfault here]
```

### Root Cause Analysis

**Issue**: Calling `vk.CreateInstance()` before loading global-level Vulkan function pointers.

**Explanation:**
Vulkan loader works in two stages:
1. **Global functions**: Loaded with `vk.load_proc_addresses(nil)`
   - Includes: `vkCreateInstance`, `vkEnumerateInstanceExtensionProperties`
   - Must be loaded **before** creating instance
2. **Instance functions**: Loaded with `vk.load_proc_addresses(instance)`
   - Includes: `vkCreateDevice`, `vkCreateDebugUtilsMessengerEXT`, etc.
   - Loaded **after** instance creation

**What happened:**
- Line 66: `vk.CreateInstance(&create_info, nil, &g_instance)`
- `vk.CreateInstance` is a function pointer (initially null)
- Dereferencing null pointer → segfault

### Solution

Add `vk.load_proc_addresses(nil)` in `main()` **before** calling `init_vulkan()`.

**Location in code:**
```odin
main :: proc() {
    fmt.println("1")
    if !glfw.Init() { /* ... */ }
    defer glfw.Terminate()

    fmt.println("2")
    vk.load_proc_addresses(nil)  // <-- ADD THIS
    fmt.println("2.5 - Loaded global Vulkan functions")

    glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
    // ... rest of main
}
```

Keep existing `vk.load_proc_addresses(g_instance)` on line 75 (in `create_instance()`) for instance-level functions.

---

## Concepts Reinforced

### Vulkan Function Loading

Vulkan doesn't link functions at compile time. The loader provides function pointers at runtime in stages:

1. **Application startup**: Load global functions (no Vulkan objects needed)
2. **After instance creation**: Load instance-specific functions
3. **After device creation**: Load device-specific functions (future lesson)

**Why this design?**
- Multi-GPU systems: Different devices may support different functions
- Explicit control: You know exactly when functions become available
- Extensibility: Extensions add new functions dynamically

### Mental Model

Think of Vulkan function loading like database connections:

```
vk.load_proc_addresses(nil)         → Open connection to "database server" (Vulkan loader)
vk.CreateInstance()                 → Create database
vk.load_proc_addresses(instance)    → Get database-specific operations
```

---

## Current State

**Completed:**
- ✅ Swapped all lesson files from GLSL to Slang
- ✅ Updated `flake.nix` with Slang compiler
- ✅ Updated `CLAUDE.md` with Slang examples
- ✅ Identified root cause of segfault

**Blocked:**
- ⏸️ Lesson 1 implementation (waiting for segfault fix to be applied)

**Next Steps:**
1. Apply the fix: Add `vk.load_proc_addresses(nil)` to `main()`
2. Test Vulkan instance creation
3. Complete Lesson 1: Instance + Debug Messenger
4. Validate Slang is available in Nix environment (`nix develop`, then `slangc --version`)

---

## Learning Notes

### Slang Syntax Highlights

**Entry point attributes:**
```slang
[shader("vertex")]      // Vertex shader
[shader("fragment")]    // Fragment shader
[shader("compute")]     // Compute shader (future)
```

**Semantics (HLSL-style):**
- `SV_VertexID` - Vertex index (replaces `gl_VertexIndex`)
- `SV_Position` - Clip-space position (replaces `gl_Position`)
- `SV_Target` - Render target output (replaces `layout(location = 0) out`)
- `COLOR` - Custom interpolated value

**Static arrays:**
```slang
static const float2 positions[3] = { /* ... */ };
```
- `static` = compile-time constant (not per-invocation)
- `const` = immutable

**Output parameters:**
```slang
float4 vertexMain(uint vertexID : SV_VertexID, out float3 fragColor : COLOR)
```
- `out` = output from vertex shader → input to fragment shader
- Replaces GLSL's `layout(location = 0) out`

---

## Questions for Future Sessions

1. **Slang reflection**: Does Slang provide better reflection than SPIR-V tools?
2. **Hot reloading**: Can Slang compilation be integrated into build for faster iteration?
3. **Modules**: Slang supports modules - how to structure shader code as project grows?
4. **Autodiff**: Slang has automatic differentiation - relevant for future rendering techniques?

---

## Session Summary

**Duration**: ~45 minutes (estimated)

**Achievements:**
- Strategic technology swap (GLSL → Slang) completed across all lesson files
- Deep-dived Vulkan function loading mechanism
- Diagnosed segfault root cause

**Blockers Identified:**
- Need to apply fix and verify Vulkan initialization works
- Need to confirm Slang package available in Nix

**Key Insight:**
Choosing learning-oriented technologies (Vulkan, Slang) over "beginner-friendly" options pays off in understanding fundamentals. The pain is the pedagogy.

---

## References

- Slang GitHub: https://github.com/shader-slang/slang
- Slang Docs: https://shader-slang.com/
- Vulkan Tutorial (GLSL-based, but concepts transfer): https://vulkan-tutorial.com
- Khronos Vulkan Loader: https://github.com/KhronosGroup/Vulkan-Loader

---

**Status**: Session paused. Ready to apply fix and continue Lesson 1 implementation.
