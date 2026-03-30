# Shader Graph System - Vulkan Learning Plan (Odin)

> **Vision**: Build a Houdini + Substance Designer inspired shader graph system on Vulkan
>
> **Current Phase**: Phase 2 COMPLETE - Ready for shader hot-reload (Phase 3)
> **Future Direction**: Node-based shader authoring → see `future_direction.md`
>
> Learning Vulkan to build shader tooling, not a traditional 3D editor. Each lesson implements one major Vulkan system with visible/debuggable milestones.

---

## Table of Contents
1. [Introduction](#introduction)
2. [Phase 0: Vulkan Mental Model](#phase-0-vulkan-mental-model) ✅
3. [Phase 1: Vulkan Bootstrap](#phase-1-vulkan-bootstrap-the-gauntlet) ✅
4. [Phase 2: First Triangle](#phase-2-first-triangle) ✅
5. [Phase 3: Shader Hot-Reload](#phase-3-shader-hot-reload)
6. [Phase 4: Minimal Shader Graph](#phase-4-minimal-shader-graph)
7. [Phase 5: Node Library & Parameters](#phase-5-node-library--parameters)
8. [Phase 6: Visual Editor UI](#phase-6-visual-editor-ui)
9. [Resources](#resources)

---

## Introduction

### Why Vulkan Instead of OpenGL?

You're going against all advice. Good. Here's what you get:

**Pros:**
- **Understand everything**: Vulkan hides nothing. You'll know exactly what the GPU is doing.
- **Explicit control**: Memory management, synchronization, command recording - you control it all.
- **Modern API**: This is how graphics APIs work now (DX12, Metal are similar).
- **Performance**: When you know what you're doing, Vulkan is faster.
- **Pipeline knowledge**: Understanding Vulkan teaches you GPU architecture.

**Cons:**
- **Massive boilerplate**: 1000+ lines before you draw a triangle.
- **Easy to crash**: Validation layers will yell at you constantly (this is good).
- **Synchronization hell**: CPU-GPU sync is manual. Mess it up = artifacts or crashes.
- **Steep learning curve**: You need to understand GPU architecture, not just API calls.

### What's Different from OpenGL?

| Concept | OpenGL | Vulkan |
|---------|--------|--------|
| **State** | Global state machine | Explicit state objects |
| **Errors** | Query errors after calls | Validation layers (debug only) |
| **Commands** | Immediate execution | Record into command buffers |
| **Sync** | Implicit (mostly) | Explicit fences/semaphores |
| **Memory** | Driver manages | You manage GPU memory |
| **Shaders** | GLSL text at runtime | SPIR-V bytecode (Slang compiled ahead) |
| **Setup** | ~50 lines | ~1000+ lines |

### The Vulkan Mindset

Vulkan doesn't hold your hand. It trusts you to know what you're doing. You need to think like the GPU:

1. **Everything is explicit**: If you don't tell Vulkan something, it doesn't happen.
2. **Asynchronous execution**: CPU records commands, GPU executes later.
3. **Resource lifetimes**: You must ensure resources live until GPU is done with them.
4. **Synchronization**: You tell Vulkan when CPU and GPU need to coordinate.

### Development Environment

Same Nix flake, but add Vulkan packages:

```nix
# In flake.nix, update buildInputs:
buildInputs = [
  odin
  ols
  glfw
  vulkan-headers
  vulkan-loader
  vulkan-validation-layers
  shader-slang  # Slang shader compiler (to SPIR-V)
];
```

Build commands remain the same:
```bash
odin build . -debug
```

---

## Phase 0: Vulkan Mental Model ✅

**Status**: COMPLETE (2026-03-07)

📄 **[Full Lesson: Mental Model](vulkan_lessons/lesson_00_mental_model.md)**

**Goal**: Understand Vulkan's architecture before writing code.

**What was learned:**
- Vulkan's 11-stage mandatory pipeline (instance → device → swapchain → pipeline → commands → present)
- Memory model (manual allocation, binding, mapping)
- Command recording vs execution (async model)
- Synchronization primitives (fences, semaphores, barriers)
- Validation layers as learning tool

**Milestone**: Conceptual understanding validated with quiz (6/6 perfect score)

### Lesson 0.1: The Vulkan Pipeline Overview

Vulkan separates concerns that OpenGL mixes together. Here's the full stack:

```
Application (Odin)
    ↓
Vulkan Instance (vkCreateInstance)
    ↓
Physical Device (GPU hardware query)
    ↓
Logical Device (interface to GPU)
    ↓
Queue Family (command submission pipeline)
    ↓
Swapchain (images to present to screen)
    ↓
Render Pass (describes rendering operations)
    ↓
Framebuffer (attachments for render pass)
    ↓
Pipeline (complete GPU state: shaders, blending, etc.)
    ↓
Command Buffer (recorded GPU commands)
    ↓
Submission (send to GPU)
    ↓
Synchronization (fences/semaphores)
    ↓
Present (show image on screen)
```

**Every single one of these is mandatory.** You can't skip steps.

### Lesson 0.2: Memory Model

Vulkan has multiple memory heaps and types. You must:

1. **Query available memory types** (VRAM, RAM, cached, etc.)
2. **Allocate memory** from appropriate heap
3. **Bind memory** to resources (buffers, images)
4. **Map/unmap** for CPU access if needed
5. **Free memory** when done

**No automatic memory management.** You allocate, you free.

### Lesson 0.3: Command Recording vs Execution

OpenGL:
```c
glDrawArrays(...)  // Executes immediately (mostly)
```

Vulkan:
```odin
// 1. Begin recording
vk.BeginCommandBuffer(cmd_buffer, &begin_info)

// 2. Record commands (GPU not executing yet!)
vk.CmdDraw(cmd_buffer, 3, 1, 0, 0)

// 3. End recording
vk.EndCommandBuffer(cmd_buffer)

// 4. Submit to queue (GPU starts executing)
vk.QueueSubmit(queue, 1, &submit_info, fence)

// 5. Wait for GPU to finish
vk.WaitForFences(device, 1, &fence, true, UINT64_MAX)
```

**Recording is fast** (CPU just writes commands).
**Execution is async** (GPU processes commands later).

### Lesson 0.4: Synchronization Primitives

You need to coordinate:
- **CPU ↔ GPU**: Use **fences** (CPU waits for GPU)
- **GPU ↔ GPU**: Use **semaphores** (GPU waits for GPU)
- **Memory visibility**: Use **pipeline barriers** (ensure writes are visible)

Example:
```
Frame N:
  CPU records commands → Submit to GPU with fence
  GPU renders while CPU moves on

Frame N+1:
  CPU waits for Frame N fence before reusing command buffer
  CPU records new commands
  Submit with semaphore (wait for swapchain image available)
```

**Miss synchronization = corruption, crashes, or GPU hangs.**

### Lesson 0.5: Validation Layers

Vulkan's safety net. Catches:
- Invalid API usage
- Memory leaks
- Synchronization errors
- Performance warnings

**Enable validation layers during development.** They're verbose but essential.

```odin
// Add validation layers to instance creation
instance_layers := []cstring{"VK_LAYER_KHRONOS_validation"}
```

Validation layers print messages like:
```
VKLOG: Validation Error: [ VUID-vkCmdDraw-None-02697 ]
Object 0: handle = 0x..., type = VK_OBJECT_TYPE_COMMAND_BUFFER
Draw cannot be called prior to binding a pipeline.
```

**Read these messages.** They tell you exactly what's wrong.

### Checklist for Phase 0:
- [ ] Understand Vulkan's multi-stage setup
- [ ] Know difference between physical/logical device
- [ ] Understand command recording vs execution
- [ ] Know when to use fences vs semaphores
- [ ] Understand validation layers purpose

---

## Phase 1: Vulkan Bootstrap (The Gauntlet) ✅

**Status**: COMPLETE (Lessons 1-7, 2026-03-29)

**Goal**: Set up all Vulkan infrastructure to display a colored window.

This phase is **pure boilerplate**. No rendering yet. Just getting the pipeline ready.

Each lesson adds one major system with a milestone to verify it works.

**Completed lessons:**
- ✅ Lesson 1: Instance + Debug Messenger ([vulkan_lessons/lesson_01_instance_debug.md](vulkan_lessons/lesson_01_instance_debug.md))
- ✅ Lesson 2: Surface + Physical Device ([vulkan_lessons/lesson_02_surface_physical_device.md](vulkan_lessons/lesson_02_surface_physical_device.md))
- ✅ Lesson 3: Logical Device + Queues ([vulkan_lessons/lesson_03_logical_device_queues.md](vulkan_lessons/lesson_03_logical_device_queues.md))
- ✅ Lesson 4: Swapchain ([vulkan_lessons/lesson_04_swapchain.md](vulkan_lessons/lesson_04_swapchain.md))
- ✅ Lesson 5: Render Pass + Framebuffers ([vulkan_lessons/lesson_05_render_pass.md](vulkan_lessons/lesson_05_render_pass.md))
- ✅ Lesson 6: Command Pools + Buffers ([vulkan_lessons/lesson_06_command_buffers.md](vulkan_lessons/lesson_06_command_buffers.md))
- ✅ Lesson 7: Synchronization ([vulkan_lessons/lesson_07_synchronization.md](vulkan_lessons/lesson_07_synchronization.md)) - Correct semaphore indexing (per frame vs per swapchain image)

**Key achievements:**
- Vulkan instance with validation layers catching all API errors
- Physical device selection with queue family discovery
- Logical device representing application's GPU connection
- Swapchain managing 2-3 images for presentation (no tearing)
- Render pass defining rendering structure (clear + color attachment)
- Framebuffers binding swapchain images to render pass
- Command pools and buffers for recording GPU commands
- Synchronization primitives (fences for CPU↔GPU, semaphores for GPU↔GPU)

**Critical learning:**
- Semaphore indexing: `image_available_semaphores[current_frame]` vs `image_finished_semaphores[image_index]`
- Why: Swapchain images (3) ≠ frames in flight (2). Different ownership semantics.
- Validation-driven development: Trust the error messages, they're precise.

See individual lesson files in `vulkan_lessons/` for detailed code and explanations.

---

## Phase 2: First Triangle ✅

**Status**: COMPLETE (2026-03-29)

**Goal**: Clear screen to color, then render RGB triangle.

**Completed lessons:**
- ✅ Lesson 8: Clearing the Screen ([vulkan_lessons/lesson_08_clear_screen.md](vulkan_lessons/lesson_08_clear_screen.md))
- ✅ Lesson 9: Graphics Pipeline + Triangle ([vulkan_lessons/lesson_09_triangle.md](vulkan_lessons/lesson_09_triangle.md))

**Key achievements:**
- Render loop with fence-based frame synchronization
- Command buffer recording (render pass begin/end, pipeline binding, draw calls)
- Queue submission with semaphore coordination
- Slang shader compilation to SPIR-V (vertex + fragment shaders)
- Graphics pipeline creation (all stages: vertex input, assembly, viewport, rasterizer, multisampling, blending)
- Triangle rendered with RGB vertex colors

**Milestone**: Blue screen clears every frame, RGB triangle visible in center.

See individual lesson files in `vulkan_lessons/` for complete code.

---

## Phase 3: Shader Hot-Reload

**Goal**: Load and reload Slang shaders at runtime without restart

**Status**: NOT STARTED (begins after Lesson 9 complete)

**What you're building:**
1. File watcher (detect shader changes on disk using OS APIs)
2. Slang compilation wrapper (invoke `slangc` from Odin)
3. Pipeline recreation (destroy old pipeline, create new with updated shaders)
4. Error display (show Slang compiler errors in console/UI)

**Implementation steps:**
- Monitor `shaders/*.slang` for file modifications
- On change: compile to SPIR-V, validate, recreate pipeline
- Handle errors gracefully (keep old pipeline if new one fails)
- Add keyboard shortcut (F5?) to force reload

**Milestone**: Edit `triangle.slang`, save file, see updated shader without restarting app.

**Why this phase**: Proves dynamic Slang compilation works. Foundation for graph-generated shaders.

**Resources:**
- Odin file watching: `core:os` file stat polling or platform-specific APIs
- Slang compilation: `core:os` process spawning (`slangc` command)
- Error parsing: Parse `slangc` stderr output

---

## Phase 4: Minimal Shader Graph

**Goal**: Hardcode 2-3 nodes, generate Slang code, render result

**Status**: NOT STARTED (begins after Phase 3)

**What you're building:**
1. Simple graph data structure (3 nodes, 2 connections)
2. Code generator (traverse graph, emit Slang functions)
3. Compile and render generated shader

**Hardcoded nodes:**
- **UV Coords** (no inputs, output: `vec2`)
- **Checker Pattern** (input: `vec2 uv`, output: `float`)
- **Color Output** (input: `float mask`, output: `vec4` color)

**Graph structure:**
```
[UV Coords] → [Checker Pattern] → [Color Output]
```

**Generated Slang example:**
```slang
float2 node_uv() { return input.uv; }
float node_checker(float2 uv) {
    return step(0.5, frac(uv.x * 5.0) * frac(uv.y * 5.0));
}
float4 node_color(float mask) {
    return float4(mask, mask, mask, 1.0);
}

[shader("fragment")]
float4 fragmentMain(float2 uv : TEXCOORD) : SV_Target {
    float2 coords = node_uv();
    float pattern = node_checker(coords);
    return node_color(pattern);
}
```

**Implementation:**
- No UI yet - graph is hardcoded in Odin
- Topological sort to determine node execution order
- String building for Slang code generation
- Use Phase 3's hot-reload to compile generated code

**Milestone**: Run program, see black/white checkerboard pattern rendered from generated shader.

**Why this phase**: Validates core concept (graph → code → render) before building complex UI.

---

## Phase 5: Node Library & Parameters

**Goal**: 10-15 useful nodes with exposed parameters

**Status**: NOT STARTED

**Node categories to implement:**
- **Inputs**: UV coords, vertex color, time uniform
- **Generators**: Perlin noise, Simplex noise, gradients, circles
- **Math**: Add, multiply, clamp, saturate, lerp, power
- **Color**: Color ramp (gradient), HSV adjust, blend modes (multiply, add, overlay)
- **Outputs**: Base color, roughness, metallic, emission

**Parameter system:**
```odin
Parameter :: union {
    Float_Param:  struct { value: f32, min: f32, max: f32 },
    Color_Param:  struct { value: [3]f32 },
    Choice_Param: struct { options: []string, selected: int },
}

Node :: struct {
    // ... other fields
    parameters: map[string]Parameter,
}
```

**Features:**
- Type checking (can't connect `vec3` output to `float` input without cast)
- Default values for unconnected inputs
- Parameter changes trigger shader regeneration
- Node registration system (add new nodes without recompiling core)

**Milestone**: Build rust metal material:
- Noise → Color Ramp (rust orange/brown gradient)
- Noise (different scale) → roughness output
- Fixed value (0.8) → metallic output

**Implementation timeline**: ~10-15 sessions (one node type per session)

---

## Phase 6: Visual Editor UI

**Goal**: Full Houdini-style node canvas with Substance-style thumbnails

**Status**: NOT STARTED

**UI framework decision**: TBD (options: custom ImGui-style, Raylib, microui, native OS)

**Features to build:**

### Canvas System
- Pan (middle-mouse drag), zoom (scroll wheel)
- Infinite 2D workspace
- Grid background (helps with alignment)
- Box select (drag to select multiple nodes)

### Node Manipulation
- Tab menu for node creation (search by name)
- Drag nodes to reposition
- Delete nodes (Del key)
- Copy/paste nodes (Ctrl+C/V)
- Duplicate nodes (Ctrl+D)
- Undo/redo stack

### Wiring System
- Drag from output socket → input socket
- Auto-routing (avoid node overlap, clean curves)
- Bezier curves for connections
- Type-color coding (vec3 = yellow, float = white, sampler2D = purple)
- Prevent invalid connections (type mismatch)
- Detect circular dependencies

### Parameter Panel
- Right-side panel shows active node's parameters
- Float sliders, color pickers, dropdown menus
- Real-time updates (change parameter → regenerate shader)
- Parameter linking (control multiple nodes with one slider)

### Thumbnails (Substance Designer style)
- Render each node's output to 64x64 or 128x128 texture
- Display thumbnail on node
- Click thumbnail to view full-size
- Multi-output nodes: dropdown to select which output to preview
- Cache thumbnails (don't re-render unchanged nodes)

### Save/Load System
- Serialize graph to JSON (human-readable) or binary (compact)
- Auto-save every N minutes
- Load graph from file
- Export generated Slang code to file

**Milestone**: Build complex shader (10+ nodes, multiple blends) entirely in visual editor.

**Technical challenges:**
- Thumbnail rendering: N nodes = N render passes (expensive)
  - Solution: lazy evaluation (only render visible), caching, LOD
- UI responsiveness: Large graphs (100+ nodes)
  - Solution: spatial indexing, viewport culling
- Parameter changes: Don't regenerate shader for every slider tweak
  - Solution: use push constants for parameters

**Implementation timeline**: ~20-30 sessions (this is the big one)

---

## Resources

### Vulkan Learning (Phase 0-2)
- **Vulkan Tutorial**: https://vulkan-tutorial.com (C++, translate to Odin)
- **Vulkan Guide**: https://vkguide.dev (excellent explanations)
- **Vulkan Spec**: https://registry.khronos.org/vulkan/
- **RenderDoc**: Frame debugger for Vulkan
- **Vulkan Configurator**: Manage layers and settings

### Shader Graph Development (Phase 3-6)
- **Slang Documentation**: https://shader-slang.com/
- **Slang GitHub**: https://github.com/shader-slang/slang
- **Slang Modules**: https://shader-slang.com/slang/user-guide/modules.html
- **Houdini Network View**: https://www.sidefx.com/docs/houdini/network/index.html
- **Substance Designer**: https://substance3d.adobe.com/documentation/sddoc/
- **Topological Sort**: https://en.wikipedia.org/wiki/Topological_sorting (for graph traversal)

### Odin Libraries
- **Odin Core**: File I/O (`core:os`), strings, containers
- **Odin Vendor**: Vulkan bindings (`vendor:vulkan`), GLFW (`vendor:glfw`)
- **UI Options**: Raylib, microui, custom ImGui-style (decision pending Phase 6)

### Project Documentation
- **Future Direction**: See `future_direction.md` for detailed shader graph vision
- **Learning Journal**: `learning_journal/` for session notes and progress tracking
- **Lesson Files**: `vulkan_lessons/` for detailed lesson breakdowns

---

## Project Roadmap

**Where we are**: Phase 2 complete (triangle rendering working)
**Next milestone**: Phase 3 (shader hot-reload) to prove dynamic Slang compilation
**Long-term goal**: Phase 6 (full visual node editor) for shader authoring

**Estimated timeline to working prototype:**
- Phase 3 (hot-reload): 2-3 sessions
- Phase 4 (minimal graph): 5-7 sessions
- Phase 5 (node library): 10-15 sessions
- Phase 6 (visual editor): 20-30 sessions

**Total**: ~40-55 sessions from current point to full visual shader graph system.

---

## Final Notes

### On Learning Vulkan (Phases 0-2)

Vulkan is **hard**. You'll spend more time fighting validation errors than writing rendering code initially. That's normal.

The payoff: you'll understand **exactly** what's happening between your code and the GPU. No magic, no hidden state, no "it just works" (until you make it work).

Take each lesson slowly. Get each milestone working before moving on. Use validation layers religiously. Read the error messages.

### On Building the Shader Graph (Phases 3-6)

This is a **real tool** for technical artists, not a toy project. You're building:
- Compiler infrastructure (graph → code generation)
- Visual programming system (node canvas, wiring)
- Real-time GPU feedback (thumbnail rendering)

Leverage your Pipeline TD experience. You know what tools artists need. Build something you'd actually use.

**The hardest parts:**
- Phase 4: Proving the graph → code → render pipeline works
- Phase 6: Building responsive UI for large node graphs

**The most rewarding:**
- Phase 4: First time you generate and render a shader from a graph
- Phase 6: Creating a complex shader entirely visually

You're learning how modern GPUs *and* modern shader tools work. That knowledge is worth the effort.
