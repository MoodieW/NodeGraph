# Future Direction: Shader Graph System

**Status**: Vision document - implementation begins after Lesson 9 completion

**Last Updated**: 2026-03-25

---

## Vision Statement

Build a **node-based shader graph editor** on top of Slang that generates shader code for the 3D editor. Combines:
- **Houdini's network paradigm**: Node canvas, procedural workflows, cook-on-demand
- **Substance Designer's visual feedback**: Real-time thumbnail previews per node
- **Slang's modern architecture**: Multi-target compilation, modules, reflection

**Why**: Leverage Pipeline TD experience to build tools that technical artists actually want to use.

---

## Core Influences

### Houdini Network Editor

**What to adopt:**
- **Node canvas**: Infinite 2D workspace, pan/zoom, free arrangement
- **Wiring system**: Click output → click input, automatic routing
- **Cook on demand**: Only evaluate dirty nodes (changed parameters or upstream)
- **Parameter panes**: Right-side panel shows active node's settings
- **Typed connections**: Color-coded by data type (vec3, float, sampler2D)
- **Network navigation**: Dive into subnetworks, breadcrumb trail back up
- **Copy/paste/duplicate**: Standard node manipulation

**Houdini mental model:**
- Data flows left-to-right (inputs on left, outputs on right)
- Each node is a function (inputs → processing → outputs)
- Network topology = execution order
- No spaghetti - clear data flow

### Substance Designer Thumbnails

**What to adopt:**
- **Per-node preview**: Each node shows real-time thumbnail of its output
- **Visual debugging**: See exactly what each node produces (no guessing)
- **Immediate feedback**: Change parameter, see thumbnail update
- **Output selection**: Multi-output nodes show dropdown to pick preview

**Why it matters:**
- Artists work visually, not algebraically
- Spot errors immediately (wrong blend mode, bad UVs)
- Faster iteration (no compile-run-check cycle)

**Technical challenge:**
- Requires rendering each node's output to texture
- GPU cost: N nodes = N render passes (optimize later)
- Cache results: Don't re-render unchanged nodes

### Slang Foundation

**Why Slang:**
- **Code generation target**: Nodes → Slang functions → SPIR-V
- **Modules**: Each node is a Slang module (clean imports)
- **Interfaces**: Define node contracts (what a "blend node" looks like)
- **Generics**: Parameterize nodes (works for float, vec3, vec4)
- **Reflection**: Query shader inputs/outputs programmatically
- **Multi-target**: One graph → Vulkan, D3D12, Metal

**Not GLSL because:**
- String concatenation hell (no real module system)
- Vendor-specific extensions (NVIDIA != AMD)
- Single target (SPIR-V only, can't cross-compile)

---

## Architecture Overview

### High-Level Pipeline

```
User Interaction (Node Graph UI)
    ↓
Graph Data Structure (nodes, connections, parameters)
    ↓
Dependency Resolution (topological sort, mark dirty nodes)
    ↓
Slang Code Generation (traverse graph, emit functions)
    ↓
Slang Compiler (slangc → SPIR-V)
    ↓
Vulkan (load shader module, create pipeline)
    ↓
Render (use shader in 3D viewport)
```

### Node Representation

**In-memory structure:**
```odin
Node :: struct {
    id:         u64,                // Unique identifier
    type:       Node_Type,          // "Blend", "Noise", "UV", etc.
    position:   [2]f32,             // Canvas position
    inputs:     []Node_Input,       // Input sockets
    outputs:    []Node_Output,      // Output sockets
    parameters: map[string]Parameter, // Exposed settings
    thumbnail:  vk.ImageView,       // Preview texture (nullable)
    dirty:      bool,               // Needs recompute
}

Node_Input :: struct {
    name:       string,
    type:       Data_Type,          // float, vec3, sampler2D
    connection: Maybe(Node_Connection),
    default:    Node_Value,         // If not connected
}

Node_Output :: struct {
    name:       string,
    type:       Data_Type,
    connections: []Node_Connection, // Can feed multiple nodes
}

Node_Connection :: struct {
    from_node:   u64,
    from_output: string,
    to_node:     u64,
    to_input:    string,
}
```

### Code Generation Strategy

**Topological sort → emit functions:**

Example graph:
```
[UV Coords] → [Noise] → [Blend] → [Final Output]
                ↑          ↑
           [Color Ramp] ──┘
```

**Generated Slang:**
```slang
// Node: UV Coords
float2 node_uv_coords() {
    return input.uv;
}

// Node: Noise
float node_noise(float2 uv) {
    return perlin_noise(uv * 5.0); // Parameter: scale = 5.0
}

// Node: Color Ramp
float3 node_color_ramp(float t) {
    // Gradient lookup from parameter
    return lerp(float3(0,0,0), float3(1,1,1), t);
}

// Node: Blend
float3 node_blend(float3 a, float3 b, float mask) {
    return lerp(a, b, mask);
}

// Final shader entry point
[shader("fragment")]
float4 fragmentMain(float2 uv : TEXCOORD) : SV_Target
{
    float2 coords = node_uv_coords();
    float noise_val = node_noise(coords);
    float3 ramped = node_color_ramp(noise_val);
    float3 blended = node_blend(ramped, float3(1,0,0), noise_val);
    return float4(blended, 1.0);
}
```

**Key insight**: Each node = one function. Final shader = call nodes in order.

---

## Implementation Phases

### Phase 0: Foundation (Lessons 1-9) [IN PROGRESS]

**Goal**: Complete Vulkan rendering pipeline

- ✅ Lessons 1-6: Instance, device, swapchain, render pass, command buffers
- ⏸️ Lesson 7: Synchronization (fences, semaphores)
- ⏸️ Lesson 8: Clear screen (first render loop)
- ⏸️ Lesson 9: Triangle (first vertex/fragment shader)

**Milestone**: Render a hardcoded triangle with Slang shader.

### Phase 1: Shader Hot-Reload [AFTER LESSON 9]

**Goal**: Load external Slang files at runtime

**What to build:**
1. File watcher (detect shader changes on disk)
2. Slang compilation wrapper (`slangc` invocation)
3. Pipeline recreation (destroy old, create new with updated shader)
4. Error display (show Slang compiler errors in UI)

**Milestone**: Edit `triangle.slang`, save, see changes without restart.

**Why first**: Proves you can compile and load Slang dynamically. Foundation for graph codegen.

### Phase 2: Minimal Node Graph [PROTOTYPE]

**Goal**: 2-3 hardcoded nodes, generate Slang

**Nodes to implement:**
1. **UV Coords** (output: vec2)
2. **Checker Pattern** (input: vec2, output: float)
3. **Color** (input: float, output: vec3)

**What to build:**
- Simple graph data structure (3 nodes, 2 connections)
- Slang code generator (traverse graph, emit functions)
- Compile and render generated shader

**Milestone**: Click "Generate", see checker pattern rendered.

**Skip for now**: UI, saving/loading, parameters. Prove the core idea first.

### Phase 3: Node Library + Parameters [ITERATION]

**Goal**: 10-15 useful nodes, exposed parameters

**Node categories:**
- **Inputs**: UV coords, vertex color, time
- **Generators**: Noise (Perlin, Simplex), gradients, shapes
- **Math**: Add, multiply, clamp, saturate, lerp
- **Color**: Color ramp, HSV adjust, blend modes
- **Outputs**: Base color, normal, roughness, emission

**What to build:**
- Parameter system (float sliders, color pickers, dropdowns)
- Node registration (add new nodes without recompiling)
- Type checking (can't connect vec3 to float without cast)

**Milestone**: Create a rust metal shader from nodes (noise + color ramp + roughness).

### Phase 4: Visual Editor UI [POLISH]

**Goal**: Full node editor with Houdini-like UX

**UI features:**
- **Canvas**: Pan (middle-mouse), zoom (scroll), box select
- **Node creation**: Tab menu, search by name
- **Wiring**: Drag from output to input, auto-routing
- **Parameter pane**: Right-side panel, per-node settings
- **Thumbnails**: Render each node output to texture, display on node
- **Undo/redo**: Full history stack
- **Save/load**: Serialize graph to JSON/binary

**Milestone**: Build a complex shader (layered noise, multiple blends) entirely in UI.

### Phase 5: Advanced Features [STRETCH GOALS]

**Nice-to-haves (future):**
- **Subgraphs**: Collapse nodes into reusable blocks
- **Node library browser**: Drag-drop from asset panel
- **Material preview sphere**: 3D preview alongside node graph
- **GPU-accelerated thumbnails**: Render all previews in one compute pass
- **Shader export**: Save generated Slang to file
- **Shader import**: Parse existing Slang into node graph (harder)

---

## Technical Challenges

### Challenge 1: Thumbnail Rendering

**Problem**: N nodes = N render passes. Expensive.

**Solutions:**
1. **Lazy evaluation**: Only render visible nodes in viewport
2. **Cached textures**: Don't re-render unchanged nodes
3. **LOD thumbnails**: Low-res (64x64) previews for off-screen nodes
4. **Batch rendering**: Single compute shader evaluates multiple nodes

**Defer until Phase 4**. Get basic graph working first.

### Challenge 2: Type System

**Problem**: Slang has complex types (vec2, vec3, mat4, samplers). How to validate connections?

**Solutions:**
1. **Strict typing**: Only allow exact matches (vec3 → vec3)
2. **Auto-casting**: vec3 → float (take .x), float → vec3 (replicate)
3. **Explicit cast nodes**: Force user to insert "float to vec3" node

**Decision**: Start strict (Phase 2), add auto-casting later (Phase 3).

### Challenge 3: Circular Dependencies

**Problem**: User connects Node A → Node B → Node A. Infinite loop.

**Solutions:**
1. **Reject on connection**: Check for cycles when wiring
2. **Topological sort failure**: Detect during codegen, show error

**Decision**: Check during wiring (immediate feedback).

### Challenge 4: Dynamic Parameters

**Problem**: Node parameter changes → regenerate Slang → recompile → recreate pipeline. Slow.

**Solutions:**
1. **Push constants**: Small parameters (< 128 bytes) via push constants (no recompile)
2. **Uniform buffers**: Larger parameter sets in UBO (no recompile)
3. **Shader variants**: Pre-compile common variations

**Decision**: Use push constants for parameters (Phase 3). Only regenerate for topology changes.

---

## Why This Approach Makes Sense

### For the User (Technical Artist)

**Familiar workflow:**
- If you know Houdini, you know this
- If you know Substance, you know this
- Visual feedback = faster iteration

**Powerful enough:**
- Not toy node editor (looking at you, Unity Shader Graph limitations)
- Expose full Slang capabilities (custom functions, modules)

### For the Developer (You)

**Learning project:**
- Compiler theory (DAG traversal, code generation)
- UI programming (canvas, node manipulation)
- GPU rendering (dynamic shader compilation)
- Systems programming (file watching, process spawning)

**Portfolio piece:**
- Shows VFX pipeline experience
- Shows low-level graphics knowledge
- Shows tool-building capability
- Directly applicable to TD/tools roles in film/games

### For the Codebase

**Clean architecture:**
- Slang handles cross-platform (you don't)
- Nodes are data, not code (easy to serialize)
- Graph is independent of renderer (could target other backends)

**Extensible:**
- New node = new Slang function + registration
- Custom nodes for studio-specific workflows
- Plugin system possible (load nodes from DLLs)

---

## Non-Goals (Things to Avoid)

**Don't build:**
1. **Full material system**: Just shaders. Not PBR pipeline, lighting, shadows.
2. **Animation/rigging**: Pure shader authoring, no deformation.
3. **Texture painting**: Not Substance Painter. Procedural only.
4. **Production renderer**: Not Arnold/Renderman. Learning tool for shaders.

**Keep scope tight**: Node-based shader authoring. Nothing else.

---

## Success Metrics

**Phase 2 success**: Generate and render 3-node graph
**Phase 3 success**: Create rust metal material from 8+ nodes
**Phase 4 success**: Build complex shader (10+ nodes) without writing code
**Phase 5 success**: Ship a tool that artists would actually use

---

## When to Start

**Not now.** Finish Vulkan bootstrap first (Lessons 7-9).

**Timeline estimate:**
- Lessons 7-9: ~3-5 sessions
- Phase 1 (hot-reload): ~2-3 sessions
- Phase 2 (minimal graph): ~5-7 sessions
- Phase 3 (node library): ~10-15 sessions
- Phase 4 (full UI): ~20-30 sessions

**Realistic target**: Minimal working prototype (Phase 2) by ~15-20 total sessions from now.

---

## Resources for Future Reference

### Slang Documentation
- Shader Slang: https://shader-slang.com/
- GitHub: https://github.com/shader-slang/slang
- Modules: https://shader-slang.com/slang/user-guide/modules.html

### Node Graph References
- Houdini Network View: https://www.sidefx.com/docs/houdini/network/index.html
- Substance Designer: https://substance3d.adobe.com/documentation/sddoc/
- ImNodes (C++ node editor): https://github.com/Nelarius/imnodes
- Dear ImGui (for UI): https://github.com/ocornut/imgui

### Graph Theory / Codegen
- Topological Sort: https://en.wikipedia.org/wiki/Topological_sorting
- DAG (Directed Acyclic Graph): https://en.wikipedia.org/wiki/Directed_acyclic_graph
- SSA Form (for optimization): https://en.wikipedia.org/wiki/Static_single-assignment_form

### Odin UI Libraries
- Raylib (immediate mode): https://github.com/raysan5/raylib
- Microui (minimal immediate): https://github.com/rxi/microui
- Custom ImGui-style (build your own)

---

## Open Questions (To Resolve During Implementation)

1. **UI framework**: Build custom vs use existing? (ImGui-style, Raylib, native?)
2. **Serialization format**: JSON (readable) vs binary (compact)?
3. **Slang integration**: CLI invocation vs API (if binding exists)?
4. **Thumbnail resolution**: 64x64? 128x128? User-configurable?
5. **Multi-output nodes**: How to visualize? Dropdown? Multiple thumbnails?
6. **Node layout**: Auto-layout (Graphviz-style) or manual-only?

---

**Status**: Vision captured. Implementation begins after Lesson 9 completion.

**Next milestone**: Complete Lessons 7-9, then revisit this document.
