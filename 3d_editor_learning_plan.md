# 3D Model Editor Learning Plan - Odin for Python Developers

> A comprehensive guide to learning Odin by building a 3D model editor from scratch.
> Tailored for developers coming from Python with basic Odin syntax knowledge.

---

## Table of Contents
1. [Introduction](#introduction)
2. [Phase 0: Odin Fundamentals](#phase-0-odin-fundamentals-week-1)
3. [Phase 1: Foundation](#phase-1-foundation-weeks-2-3)
4. [Phase 2: Basic 3D Rendering](#phase-2-basic-3d-rendering-weeks-4-5)
5. [Phase 3: Model Editor Core](#phase-3-model-editor-core-weeks-6-7)
6. [Phase 4: Materials & Textures](#phase-4-materials--textures-weeks-8-9)
7. [Phase 5: Advanced Features](#phase-5-advanced-features-weeks-10-12)
8. [Phase 6: Polish & Export](#phase-6-polish--export-weeks-13)
9. [Resources](#resources)

---

## Introduction

### Why Odin for 3D Graphics?
- **Performance**: Systems-level control like C/C++, crucial for real-time 3D
- **Simplicity**: Cleaner syntax than C++, easier to reason about
- **Control**: Explicit memory management for graphics resources
- **Modern**: Built-in features like defer, slices, and context system

### Python → Odin Mindset Shift

| Concept | Python | Odin |
|---------|--------|------|
| **Memory** | Garbage collected, automatic | Manual allocation, explicit control |
| **Types** | Dynamic, duck typing | Static, explicit types |
| **Errors** | Exceptions (`try/except`) | Union types, explicit returns |
| **OOP** | Classes, methods, inheritance | Structs, procedures, composition |
| **Build** | Interpreted/JIT | Compiled to native code |
| **Imports** | `import module` | `import "package"` |

### What You'll Build
A full-featured 3D model editor with:
- 3D viewport with camera controls
- Model loading (OBJ format - simple, learnable)
- Transform gizmos (move, rotate, scale)
- Material and texture system
- Mesh editing tools
- Scene hierarchy
- Export functionality

---

## Phase 0: Odin Fundamentals (Week 1)

- [x] **Phase 0 Complete**

**Goal**: Understand systems programming concepts that Python abstracts away.

### Step 0.1: Memory Management Basics
- [x] Read and understand this section

#### Python vs Odin Memory Model

**Python:**
```python
# Everything is a reference, garbage collected
my_list = [1, 2, 3]  # Allocated somewhere in memory
my_dict = {"key": "value"}  # You never think about where
# Memory freed automatically when no references exist
```

**Odin:**
```odin
package main

import "core:fmt"

main :: proc() {
    // Stack allocation (fast, automatic cleanup)
    stack_array: [3]int = {1, 2, 3}  // Lives on stack, dies at end of scope

    // Heap allocation (manual, you control lifetime)
    heap_slice := make([]int, 3)  // Allocates on heap
    defer delete(heap_slice)       // YOU must free it (defer = cleanup at scope exit)

    // Dynamic array (grows like Python list)
    dynamic_array := make([dynamic]int)
    defer delete(dynamic_array)
    append(&dynamic_array, 1, 2, 3)
}
```

**Key Concepts:**
- **Stack**: Fast, small, automatic cleanup. Use for local variables.
- **Heap**: Slower, large, manual cleanup. Use for long-lived or large data.
- **defer**: Like Python's `with` or `finally`, but for any cleanup code.

#### Memory Leak Example (Common Python Developer Mistake)

```odin
// BAD - Memory leak!
make_vertex_buffer :: proc() -> []f32 {
    data := make([]f32, 1000)  // Allocates memory
    // ... fill data ...
    return data  // Caller must delete, but might forget!
}

// GOOD - Clear ownership
make_vertex_buffer :: proc(allocator := context.allocator) -> []f32 {
    data := make([]f32, 1000, allocator)  // Use provided allocator
    return data  // Caller knows they own this memory
}

// Usage:
main :: proc() {
    vbo_data := make_vertex_buffer()
    defer delete(vbo_data)  // Explicit cleanup
    // Use vbo_data...
}
```

**Memory Management Rules:**
1. Every `make()` needs a `delete()`
2. Every `new()` needs a `free()`
3. Use `defer` immediately after allocation
4. When in doubt, allocate on stack (fixed-size arrays)

### Step 0.2: Allocators and Context
- [x] Read and understand this section

#### What is `context`?

In Python, you never think about *where* memory comes from. In Odin, you can control it.

```odin
package main

import "core:fmt"
import "core:mem"

main :: proc() {
    // Default allocator (uses heap)
    data1 := make([]int, 100)  // Uses context.allocator (heap)
    defer delete(data1)

    // Arena allocator (bulk allocation, single free)
    arena: mem.Arena
    arena_allocator := mem.arena_allocator(&arena)
    defer mem.arena_destroy(&arena)  // Frees everything at once

    // Temporarily change context allocator
    context.allocator = arena_allocator
    {
        // All allocations in this scope use arena
        temp_data := make([]int, 100)
        more_data := make([]f32, 200)
        // No need to delete individually!
    }
    // Arena destroyed above, all memory freed
}
```

**Why This Matters for 3D Graphics:**
- Loading a model: Use arena, load all data, free all at once
- Per-frame temp data: Use temp allocator, auto-clears each frame
- Long-lived GPU buffers: Use heap allocator

### Step 0.3: Pointers vs Values
- [ ] Read and understand this section

Python: Everything is a reference (pointer).
Odin: You choose!

```odin
Vector3 :: struct {
    x, y, z: f32,
}

// Pass by value (copy) - good for small structs
add_vectors :: proc(a: Vector3, b: Vector3) -> Vector3 {
    return Vector3{a.x + b.x, a.y + b.y, a.z + b.z}
}

// Pass by pointer (reference) - good for large structs or when modifying
scale_vector :: proc(v: ^Vector3, scale: f32) {
    v.x *= scale  // Modifies original
    v.y *= scale
    v.z *= scale
}

main :: proc() {
    v1 := Vector3{1, 2, 3}
    v2 := Vector3{4, 5, 6}

    result := add_vectors(v1, v2)  // v1, v2 copied
    scale_vector(&v1, 2.0)         // v1 modified in place

    fmt.println(v1)  // {2, 4, 6}
}
```

**Rule of Thumb:**
- Small data (< 16 bytes): Pass by value
- Large data or modifying: Pass by pointer
- Slices/maps/dynamic arrays: Already references, no pointer needed

### Step 0.4: Error Handling (No Exceptions!)
- [x] Read and understand this section

Python:
```python
def load_file(path):
    try:
        with open(path) as f:
            return f.read()
    except FileNotFoundError:
        print("File not found!")
        return None
```

Odin:
```odin
package main

import "core:os"
import "core:fmt"

// Option 1: Multiple return values
load_file :: proc(path: string) -> (data: []byte, ok: bool) {
    data, success := os.read_entire_file(path)
    if !success {
        return nil, false
    }
    return data, true
}

// Option 2: Union types (like Rust's Result)
load_file_v2 :: proc(path: string) -> (data: []byte, err: os.Errno) {
    data, errno := os.read_entire_file(path, context.allocator)
    if errno != 0 {
        return nil, errno
    }
    return data, 0
}

main :: proc() {
    // Check errors explicitly
    data, ok := load_file("model.obj")
    if !ok {
        fmt.println("Failed to load file")
        return
    }
    defer delete(data)

    // Use the data...
}
```

**No Try/Catch:**
- Functions return success/error explicitly
- You must check return values
- Compiler warns about unused returns

### Step 0.5: Structs and Procedures (Not Classes!)
- [x] Read and understand this section

Python:
```python
class Mesh:
    def __init__(self, vertices):
        self.vertices = vertices
        self.transform = Matrix4x4()

    def translate(self, offset):
        self.transform = self.transform.translate(offset)
```

Odin:
```odin
package main

import "core:math/linalg"

// Just data, no methods
Mesh :: struct {
    vertices: []f32,
    transform: matrix[4, 4]f32,
}

// Procedures that operate on Mesh
mesh_create :: proc(vertices: []f32) -> Mesh {
    return Mesh{
        vertices = vertices,
        transform = linalg.MATRIX4F32_IDENTITY,
    }
}

mesh_translate :: proc(mesh: ^Mesh, offset: [3]f32) {
    mesh.transform = linalg.matrix4_translate_f32(offset) * mesh.transform
}

// Can use "using" for method-like syntax
mesh_translate_v2 :: proc(using mesh: ^Mesh, offset: [3]f32) {
    transform = linalg.matrix4_translate_f32(offset) * transform
    // 'using' unpacks fields into scope
}

main :: proc() {
    vertices := make([]f32, 100)
    defer delete(vertices)

    mesh := mesh_create(vertices)
    mesh_translate(&mesh, {1, 2, 3})
}
```

### Step 0.6: Slices vs Dynamic Arrays
- [x] Read and understand this section

```odin
package main

import "core:fmt"

main :: proc() {
    // Fixed-size array (on stack, size known at compile time)
    fixed: [5]int = {1, 2, 3, 4, 5}

    // Slice (view into an array, size known at runtime)
    slice := make([]int, 5)  // Allocates backing array
    defer delete(slice)

    // Dynamic array (growable, like Python list)
    dynamic := make([dynamic]int)
    defer delete(dynamic)
    append(&dynamic, 1, 2, 3)  // Grows as needed

    // Slice from fixed array
    view := fixed[1:4]  // {2, 3, 4} - no allocation, just a view

    // Subslice (view of a view)
    sub := slice[0:2]  // No allocation

    fmt.println(len(fixed))    // 5
    fmt.println(len(slice))    // 5
    fmt.println(len(dynamic))  // 3
    fmt.println(cap(dynamic))  // Capacity (may be > len)
}
```

**Python List → Odin:**
- Python `list` → Odin `[dynamic]T`
- Python `list[start:end]` → Odin `slice[start:end]` (creates view, not copy!)

### Step 0.7: Maps (Dictionaries)
- [x] Read and understand this section

```odin
package main

import "core:fmt"

main :: proc() {
    // Create map
    materials := make(map[string]int)  // Like Python dict
    defer delete(materials)

    // Add items
    materials["wood"] = 1
    materials["metal"] = 2

    // Check if key exists
    if id, ok := materials["wood"]; ok {
        fmt.println("Wood ID:", id)
    }

    // Iterate (order not guaranteed, like Python 3.7+)
    for name, id in materials {
        fmt.printfln("%s: %d", name, id)
    }

    // Delete key
    delete_key(&materials, "wood")
}
```

### Practice Exercise 0: Memory Management
- [x] Complete this exercise

Before moving to 3D graphics, practice with this:

```odin
package main

import "core:fmt"
import "core:mem"

// Exercise: Fix the memory leaks in this code
Particle :: struct {
    position: [3]f32,
    velocity: [3]f32,
}

// TODO: Make sure this doesn't leak memory
particle_system_create :: proc(count: int) -> []Particle {
    particles := make([]Particle, count)
    for i in 0..<count {
        particles[i].position = {0, 0, 0}
        particles[i].velocity = {1, 1, 1}
    }
    return particles
}

main :: proc() {
    // Track allocations
    track: mem.Tracking_Allocator
    mem.tracking_allocator_init(&track, context.allocator)
    context.allocator = mem.tracking_allocator(&track)
    defer {
        if len(track.allocation_map) > 0 {
            fmt.println("Memory leaks detected!")
            for _, entry in track.allocation_map {
                fmt.printfln("Leaked %d bytes", entry.size)
            }
        }
        mem.tracking_allocator_destroy(&track)
    }

    particles := particle_system_create(100)
    // TODO: Clean up particles

    // What else might leak?
}
```

**Checklist for Phase 0:**
- [x] Understand stack vs heap
- [x] Can write and use `defer` correctly
- [x] Understand when to use pointers
- [x] Know how to check errors (no exceptions!)
- [ ] Comfortable with slices and dynamic arrays
- [x] Understand struct-based design vs OOP

---

## Phase 1: Foundation (Weeks 2-3)

- [ ] **Phase 1 Complete**

**Goal**: Set up windowing, OpenGL context, and render your first triangle.

### Step 1: Project Setup
- [x] Complete this step

#### Directory Structure
```
vfx_tools/
├── 3d_editor/
│   ├── main.odin           # Entry point
│   ├── window.odin         # Window management
│   ├── renderer.odin       # OpenGL abstraction
│   ├── shaders/
│   │   ├── basic.vert      # Vertex shader
│   │   └── basic.frag      # Fragment shader
│   └── assets/
│       └── models/         # .obj files
└── flake.nix
```

#### Update flake.nix

Add GLFW to your existing setup:
```nix
# Add glfw3 to buildInputs in flake.nix
buildInputs = [ odin ols raylib glfw ];
```

### Step 2: Create Window with GLFW
- [ ] Complete this step

**Memory Consideration**: GLFW is a C library. Its allocations don't use Odin's allocator.

```odin
package main

import "core:fmt"
import "core:c"
import "vendor:glfw"
import gl "vendor:OpenGL"

// Global state (in 3D apps, some globals are OK)
g_window: glfw.WindowHandle

// GLFW error callback
glfw_error_callback :: proc "c" (error: c.int, description: cstring) {
    context = runtime.default_context()  // Callbacks need context!
    fmt.eprintfln("GLFW Error %d: %s", error, description)
}

init_window :: proc() -> bool {
    // Initialize GLFW
    glfw.SetErrorCallback(glfw_error_callback)

    if !glfw.Init() {
        fmt.eprintln("Failed to initialize GLFW")
        return false
    }

    // Configure OpenGL version (3.3 core)
    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

    // Create window
    g_window = glfw.CreateWindow(1280, 720, "3D Model Editor", nil, nil)
    if g_window == nil {
        fmt.eprintln("Failed to create window")
        glfw.Terminate()
        return false
    }

    glfw.MakeContextCurrent(g_window)
    glfw.SwapInterval(1)  // VSync

    // Load OpenGL functions (MUST do after creating context)
    gl.load_up_to(3, 3, glfw.gl_set_proc_address)

    return true
}

main :: proc() {
    if !init_window() {
        return
    }
    defer glfw.Terminate()

    // Main loop
    for !glfw.WindowShouldClose(g_window) {
        // Clear screen
        gl.ClearColor(0.1, 0.1, 0.15, 1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT)

        // Swap buffers and poll events
        glfw.SwapBuffers(g_window)
        glfw.PollEvents()
    }

    fmt.println("Exiting...")
}
```

**Python Developer Notes:**
- `proc "c"` means C calling convention (for callbacks)
- Must set `context` in C callbacks (Odin implicit context)
- GLFW manages its own memory, we just call `Terminate()`

**Build and Run:**
```bash
cd 3d_editor
odin build . -debug
./3d_editor
```

You should see a dark blue window!

### Step 3: First Triangle (Understanding GPU Memory)
- [ ] Complete this step

**Memory Model for Graphics:**
```
CPU Memory (RAM)          GPU Memory (VRAM)
┌──────────────┐         ┌──────────────┐
│ Vertex Array │ ──────> │ VBO (buffer) │
│ [dynamic]f32 │  Upload │ Fast GPU RAM │
└──────────────┘         └──────────────┘
     ↑                          ↑
     │                          │
  Odin manages           OpenGL manages
```

**Important**: GPU buffers are NOT part of Odin's memory system. OpenGL manages them.

```odin
package main

import "core:fmt"
import "core:c"
import "vendor:glfw"
import gl "vendor:OpenGL"

// Shader compilation helper
compile_shader :: proc(source: cstring, shader_type: u32) -> (u32, bool) {
    shader := gl.CreateShader(shader_type)
    gl.ShaderSource(shader, 1, &source, nil)
    gl.CompileShader(shader)

    // Check for errors
    success: i32
    gl.GetShaderiv(shader, gl.COMPILE_STATUS, &success)
    if success == 0 {
        info_log: [512]u8
        gl.GetShaderInfoLog(shader, 512, nil, raw_data(info_log[:]))
        fmt.eprintfln("Shader compilation failed:\n%s", cstring(raw_data(info_log[:])))
        return 0, false
    }

    return shader, true
}

// Shader program creation
create_shader_program :: proc(vertex_src: cstring, fragment_src: cstring) -> (u32, bool) {
    vertex_shader, vs_ok := compile_shader(vertex_src, gl.VERTEX_SHADER)
    if !vs_ok do return 0, false
    defer gl.DeleteShader(vertex_shader)

    fragment_shader, fs_ok := compile_shader(fragment_src, gl.FRAGMENT_SHADER)
    if !fs_ok do return 0, false
    defer gl.DeleteShader(fragment_shader)

    program := gl.CreateProgram()
    gl.AttachShader(program, vertex_shader)
    gl.AttachShader(program, fragment_shader)
    gl.LinkProgram(program)

    // Check linking
    success: i32
    gl.GetProgramiv(program, gl.LINK_STATUS, &success)
    if success == 0 {
        info_log: [512]u8
        gl.GetProgramInfoLog(program, 512, nil, raw_data(info_log[:]))
        fmt.eprintfln("Program linking failed:\n%s", cstring(raw_data(info_log[:])))
        return 0, false
    }

    return program, true
}

main :: proc() {
    // Window setup (from Step 2)
    if !init_window() do return
    defer glfw.Terminate()

    // Vertex data (triangle positions)
    // In CPU memory - will upload to GPU
    vertices := [?]f32{
        // X     Y      Z
        -0.5, -0.5,  0.0,  // Bottom left
         0.5, -0.5,  0.0,  // Bottom right
         0.0,  0.5,  0.0,  // Top
    }

    // Create VAO (Vertex Array Object)
    vao: u32
    gl.GenVertexArrays(1, &vao)
    defer gl.DeleteVertexArrays(1, &vao)
    gl.BindVertexArray(vao)

    // Create VBO (Vertex Buffer Object) - GPU memory!
    vbo: u32
    gl.GenBuffers(1, &vbo)
    defer gl.DeleteBuffers(1, &vbo)  // Clean up GPU memory
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)

    // Upload vertex data to GPU
    gl.BufferData(
        gl.ARRAY_BUFFER,
        size_of(vertices),
        raw_data(vertices[:]),
        gl.STATIC_DRAW,  // Data won't change
    )

    // Tell OpenGL how to interpret vertex data
    gl.VertexAttribPointer(
        0,                  // Location 0 in shader
        3,                  // 3 components (x, y, z)
        gl.FLOAT,           // Type
        gl.FALSE,           // Don't normalize
        3 * size_of(f32),   // Stride (bytes between vertices)
        0,                  // Offset
    )
    gl.EnableVertexAttribArray(0)

    // Shaders (GLSL)
    vertex_shader_src := `#version 330 core
    layout (location = 0) in vec3 aPos;

    void main() {
        gl_Position = vec4(aPos, 1.0);
    }
    `

    fragment_shader_src := `#version 330 core
    out vec4 FragColor;

    void main() {
        FragColor = vec4(1.0, 0.5, 0.2, 1.0);  // Orange
    }
    `

    shader_program, ok := create_shader_program(vertex_shader_src, fragment_shader_src)
    if !ok {
        fmt.eprintln("Failed to create shader program")
        return
    }
    defer gl.DeleteProgram(shader_program)

    // Main loop
    for !glfw.WindowShouldClose(g_window) {
        // Clear
        gl.ClearColor(0.1, 0.1, 0.15, 1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT)

        // Draw triangle
        gl.UseProgram(shader_program)
        gl.BindVertexArray(vao)
        gl.DrawArrays(gl.TRIANGLES, 0, 3)

        glfw.SwapBuffers(g_window)
        glfw.PollEvents()
    }
}
```

**Memory Management Notes:**
1. **CPU memory**: `vertices` array - stack allocated, auto-cleanup
2. **GPU memory**: VBO - manually created/deleted with OpenGL calls
3. **Defer**: Used for GPU resource cleanup (like Python context managers)

**Common Python Developer Mistake:**
```odin
// BAD - Memory leak!
vbo: u32
gl.GenBuffers(1, &vbo)
// Forgot to delete! GPU memory leaks

// GOOD
vbo: u32
gl.GenBuffers(1, &vbo)
defer gl.DeleteBuffers(1, &vbo)  // Always defer cleanup immediately
```

### Step 4: Delta Time and Game Loop
- [ ] Complete this step

Python game loops often look like:
```python
while running:
    for event in pygame.event.get():
        handle_event(event)
    update(1/60)  # Assume 60 FPS
    render()
```

**Problem**: What if frame rate varies? Everything moves at different speeds!

**Solution**: Delta time

```odin
package main

import "core:fmt"
import "vendor:glfw"

main :: proc() {
    // Setup...

    last_time := glfw.GetTime()

    for !glfw.WindowShouldClose(g_window) {
        // Calculate delta time
        current_time := glfw.GetTime()
        delta_time := f32(current_time - last_time)
        last_time = current_time

        // Update (frame-rate independent)
        update(delta_time)

        // Render
        render()

        glfw.SwapBuffers(g_window)
        glfw.PollEvents()
    }
}

// Example: Move something at 2 units per second
Camera :: struct {
    position: [3]f32,
}

update :: proc(delta: f32) {
    speed: f32 = 2.0  // Units per second

    // Move right
    camera.position.x += speed * delta
    // Now moves same distance regardless of frame rate!
}
```

**Checklist for Phase 1:**
- [ ] Window opens and stays open
- [ ] Orange triangle renders
- [ ] Understand CPU vs GPU memory
- [ ] Using `defer` for all cleanup
- [ ] Delta time working

---

## Phase 2: Basic 3D Rendering (Weeks 4-5)

- [ ] **Phase 2 Complete**

**Goal**: Render 3D cubes with a camera that you can move around.

### Step 5: 3D Math with `core:math/linalg`
- [ ] Complete this step

**Python + NumPy Background:**
```python
import numpy as np

# Matrix multiplication
mat1 = np.array([[1, 0], [0, 1]])
mat2 = np.array([[2, 0], [0, 2]])
result = mat1 @ mat2  # Python 3.5+ operator
```

**Odin:**
```odin
package main

import "core:fmt"
import la "core:math/linalg"

main :: proc() {
    // Vectors (like numpy arrays)
    v1 := la.Vector3f32{1, 2, 3}
    v2 := la.Vector3f32{4, 5, 6}

    // Vector operations
    sum := v1 + v2
    scaled := v1 * 2.0
    dot := la.dot(v1, v2)
    cross := la.cross(v1, v2)
    length := la.length(v1)
    normalized := la.normalize(v1)

    fmt.printfln("Sum: %v", sum)
    fmt.printfln("Dot: %f", dot)

    // Matrices (column-major, like OpenGL)
    identity := la.MATRIX4F32_IDENTITY

    // Transformations
    translation := la.matrix4_translate_f32({1, 2, 3})
    rotation := la.matrix4_rotate_f32(la.to_radians(f32(45)), {0, 1, 0})
    scale := la.matrix4_scale_f32({2, 2, 2})

    // Combine transformations (order matters!)
    // Scale -> Rotate -> Translate
    model := translation * rotation * scale

    // Projection matrix (like gluPerspective)
    fov := la.to_radians(f32(45))
    aspect := f32(1280) / f32(720)
    near := f32(0.1)
    far := f32(100.0)
    projection := la.matrix4_perspective_f32(fov, aspect, near, far)

    // View matrix (camera)
    eye := la.Vector3f32{0, 0, 3}    // Camera position
    center := la.Vector3f32{0, 0, 0} // Look at point
    up := la.Vector3f32{0, 1, 0}     // Up direction
    view := la.matrix4_look_at_f32(eye, center, up)
}
```

**Important for Python Developers:**
- Odin matrices are **column-major** (OpenGL standard)
- NumPy is **row-major** by default
- Matrix multiplication order matters: `A * B != B * A`

### Step 6: Rendering a 3D Cube
- [ ] Complete this step

**Memory Planning:**
- Cube vertices: Stack array (small, fixed size)
- VBO/VAO: GPU memory (OpenGL manages)
- Shader uniforms: Temporary (no allocation needed)

```odin
package main

import "core:fmt"
import "core:c"
import "vendor:glfw"
import gl "vendor:OpenGL"
import la "core:math/linalg"

// Cube vertex data (position + color)
// 36 vertices (6 faces * 2 triangles * 3 vertices)
CUBE_VERTICES := [?]f32{
    // Positions        // Colors
    // Front face
    -0.5, -0.5,  0.5,   1.0, 0.0, 0.0,
     0.5, -0.5,  0.5,   1.0, 0.0, 0.0,
     0.5,  0.5,  0.5,   1.0, 0.0, 0.0,
    -0.5, -0.5,  0.5,   1.0, 0.0, 0.0,
     0.5,  0.5,  0.5,   1.0, 0.0, 0.0,
    -0.5,  0.5,  0.5,   1.0, 0.0, 0.0,

    // Back face
    -0.5, -0.5, -0.5,   0.0, 1.0, 0.0,
     0.5,  0.5, -0.5,   0.0, 1.0, 0.0,
     0.5, -0.5, -0.5,   0.0, 1.0, 0.0,
    -0.5, -0.5, -0.5,   0.0, 1.0, 0.0,
    -0.5,  0.5, -0.5,   0.0, 1.0, 0.0,
     0.5,  0.5, -0.5,   0.0, 1.0, 0.0,

    // ... (Add other 4 faces with different colors)
    // Left, Right, Top, Bottom
}

// Updated vertex shader with matrices
VERTEX_SHADER := `#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aColor;

out vec3 ourColor;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

void main() {
    gl_Position = projection * view * model * vec4(aPos, 1.0);
    ourColor = aColor;
}
`

FRAGMENT_SHADER := `#version 330 core
in vec3 ourColor;
out vec4 FragColor;

void main() {
    FragColor = vec4(ourColor, 1.0);
}
`

main :: proc() {
    // Window setup...

    // Enable depth testing (3D!)
    gl.Enable(gl.DEPTH_TEST)

    // Create VAO/VBO for cube
    vao, vbo: u32
    gl.GenVertexArrays(1, &vao)
    gl.GenBuffers(1, &vbo)
    defer gl.DeleteVertexArrays(1, &vao)
    defer gl.DeleteBuffers(1, &vbo)

    gl.BindVertexArray(vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
    gl.BufferData(
        gl.ARRAY_BUFFER,
        size_of(CUBE_VERTICES),
        raw_data(CUBE_VERTICES[:]),
        gl.STATIC_DRAW,
    )

    // Position attribute
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 6 * size_of(f32), 0)
    gl.EnableVertexAttribArray(0)

    // Color attribute
    gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 6 * size_of(f32), 3 * size_of(f32))
    gl.EnableVertexAttribArray(1)

    // Compile shaders
    shader_program, ok := create_shader_program(VERTEX_SHADER, FRAGMENT_SHADER)
    if !ok do return
    defer gl.DeleteProgram(shader_program)

    // Get uniform locations
    model_loc := gl.GetUniformLocation(shader_program, "model")
    view_loc := gl.GetUniformLocation(shader_program, "view")
    proj_loc := gl.GetUniformLocation(shader_program, "projection")

    // Main loop
    for !glfw.WindowShouldClose(g_window) {
        // Clear
        gl.ClearColor(0.1, 0.1, 0.15, 1.0)
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)

        // Create transformation matrices
        model := la.MATRIX4F32_IDENTITY
        model = la.matrix4_rotate_f32(f32(glfw.GetTime()), {0.5, 1.0, 0.0}) * model

        view := la.matrix4_look_at_f32(
            {0, 0, 3},   // Camera position
            {0, 0, 0},   // Look at origin
            {0, 1, 0},   // Up vector
        )

        projection := la.matrix4_perspective_f32(
            la.to_radians(f32(45)),
            1280.0 / 720.0,
            0.1,
            100.0,
        )

        // Send matrices to shader
        gl.UseProgram(shader_program)
        gl.UniformMatrix4fv(model_loc, 1, gl.FALSE, &model[0, 0])
        gl.UniformMatrix4fv(view_loc, 1, gl.FALSE, &view[0, 0])
        gl.UniformMatrix4fv(proj_loc, 1, gl.FALSE, &projection[0, 0])

        // Draw cube
        gl.BindVertexArray(vao)
        gl.DrawArrays(gl.TRIANGLES, 0, 36)

        glfw.SwapBuffers(g_window)
        glfw.PollEvents()
    }
}
```

**Memory Notes:**
- `CUBE_VERTICES`: Global constant, no allocation needed
- Matrix data sent to GPU via `UniformMatrix4fv` - copied, no allocation
- No dynamic memory in rendering loop = fast!

### Step 7: Camera System with Input
- [ ] Complete this step

**Python (Pygame) Background:**
```python
keys = pygame.key.get_pressed()
if keys[pygame.K_w]:
    camera.move_forward()
```

**Odin + GLFW:**
```odin
package main

import "core:fmt"
import "vendor:glfw"
import la "core:math/linalg"

Camera :: struct {
    position: la.Vector3f32,
    front: la.Vector3f32,
    up: la.Vector3f32,
    yaw: f32,
    pitch: f32,
    speed: f32,
    sensitivity: f32,
}

camera_create :: proc() -> Camera {
    return Camera{
        position = {0, 0, 3},
        front = {0, 0, -1},
        up = {0, 1, 0},
        yaw = -90.0,
        pitch = 0.0,
        speed = 2.5,
        sensitivity = 0.1,
    }
}

camera_get_view_matrix :: proc(using cam: ^Camera) -> la.Matrix4f32 {
    return la.matrix4_look_at_f32(position, position + front, up)
}

camera_process_keyboard :: proc(using cam: ^Camera, window: glfw.WindowHandle, delta_time: f32) {
    velocity := speed * delta_time

    if glfw.GetKey(window, glfw.KEY_W) == glfw.PRESS {
        position += front * velocity
    }
    if glfw.GetKey(window, glfw.KEY_S) == glfw.PRESS {
        position -= front * velocity
    }
    if glfw.GetKey(window, glfw.KEY_A) == glfw.PRESS {
        position -= la.normalize(la.cross(front, up)) * velocity
    }
    if glfw.GetKey(window, glfw.KEY_D) == glfw.PRESS {
        position += la.normalize(la.cross(front, up)) * velocity
    }
}

// Mouse callback (must be "c" calling convention)
g_first_mouse := true
g_last_x: f64 = 640.0
g_last_y: f64 = 360.0
g_camera: Camera

mouse_callback :: proc "c" (window: glfw.WindowHandle, xpos, ypos: f64) {
    context = runtime.default_context()

    if g_first_mouse {
        g_last_x = xpos
        g_last_y = ypos
        g_first_mouse = false
    }

    xoffset := f32(xpos - g_last_x)
    yoffset := f32(g_last_y - ypos)  // Reversed: y goes from bottom to top
    g_last_x = xpos
    g_last_y = ypos

    xoffset *= g_camera.sensitivity
    yoffset *= g_camera.sensitivity

    g_camera.yaw += xoffset
    g_camera.pitch += yoffset

    // Clamp pitch
    if g_camera.pitch > 89.0 do g_camera.pitch = 89.0
    if g_camera.pitch < -89.0 do g_camera.pitch = -89.0

    // Update camera front vector
    direction: la.Vector3f32
    direction.x = la.cos(la.to_radians(g_camera.yaw)) * la.cos(la.to_radians(g_camera.pitch))
    direction.y = la.sin(la.to_radians(g_camera.pitch))
    direction.z = la.sin(la.to_radians(g_camera.yaw)) * la.cos(la.to_radians(g_camera.pitch))
    g_camera.front = la.normalize(direction)
}

main :: proc() {
    // Window setup...

    g_camera = camera_create()

    // Set mouse callback
    glfw.SetCursorPosCallback(g_window, mouse_callback)
    glfw.SetInputMode(g_window, glfw.CURSOR, glfw.CURSOR_DISABLED)

    // Main loop
    last_time := glfw.GetTime()

    for !glfw.WindowShouldClose(g_window) {
        current_time := glfw.GetTime()
        delta_time := f32(current_time - last_time)
        last_time = current_time

        // Input
        camera_process_keyboard(&g_camera, g_window, delta_time)

        // Render with camera
        view := camera_get_view_matrix(&g_camera)
        // ... rest of rendering
    }
}
```

**Python Developer Notes:**
- Global state for camera (callbacks can't capture closures easily)
- `using cam: ^Camera` unpacks struct fields into scope
- Mouse callback needs `context = runtime.default_context()`

**Checklist for Phase 2:**
- [ ] Spinning 3D cube renders
- [ ] Depth testing working (no faces rendering in wrong order)
- [ ] WASD camera movement
- [ ] Mouse look working
- [ ] Understand model/view/projection matrices

---

## Phase 3: Model Editor Core (Weeks 6-7)

- [ ] **Phase 3 Complete**

**Goal**: Load OBJ files and implement object selection.

### Step 8: OBJ File Parser
- [ ] Complete this step

**Memory Strategy:**
- Parse file line by line
- Use dynamic arrays for vertices (unknown count)
- Clean up file data after parsing

```odin
package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:strconv"
import la "core:math/linalg"

// Mesh structure
Mesh :: struct {
    vertices: [dynamic]f32,        // Interleaved: x,y,z, nx,ny,nz, u,v
    indices: [dynamic]u32,
    vertex_count: int,
}

mesh_destroy :: proc(using mesh: ^Mesh) {
    delete(vertices)
    delete(indices)
}

// Parse OBJ file
load_obj :: proc(filepath: string, allocator := context.allocator) -> (Mesh, bool) {
    context.allocator = allocator

    // Read entire file
    data, ok := os.read_entire_file(filepath)
    if !ok {
        fmt.eprintfln("Failed to read file: %s", filepath)
        return {}, false
    }
    defer delete(data)  // Clean up file data when done

    // Temporary arrays for parsed data
    positions := make([dynamic]la.Vector3f32)
    normals := make([dynamic]la.Vector3f32)
    uvs := make([dynamic]la.Vector2f32)
    defer delete(positions)
    defer delete(normals)
    defer delete(uvs)

    // Final mesh data
    mesh: Mesh
    mesh.vertices = make([dynamic]f32)
    mesh.indices = make([dynamic]u32)

    // Parse line by line
    content := string(data)
    lines := strings.split_lines(content)
    defer delete(lines)

    for line in lines {
        line := strings.trim_space(line)
        if len(line) == 0 || line[0] == '#' do continue

        parts := strings.split(line, " ")
        defer delete(parts)

        switch parts[0] {
        case "v":  // Vertex position
            if len(parts) >= 4 {
                x, _ := strconv.parse_f32(parts[1])
                y, _ := strconv.parse_f32(parts[2])
                z, _ := strconv.parse_f32(parts[3])
                append(&positions, la.Vector3f32{x, y, z})
            }

        case "vn":  // Vertex normal
            if len(parts) >= 4 {
                x, _ := strconv.parse_f32(parts[1])
                y, _ := strconv.parse_f32(parts[2])
                z, _ := strconv.parse_f32(parts[3])
                append(&normals, la.Vector3f32{x, y, z})
            }

        case "vt":  // Texture coordinate
            if len(parts) >= 3 {
                u, _ := strconv.parse_f32(parts[1])
                v, _ := strconv.parse_f32(parts[2])
                append(&uvs, la.Vector2f32{u, v})
            }

        case "f":  // Face (triangle or quad)
            // Handle: f v1/vt1/vn1 v2/vt2/vn2 v3/vt3/vn3
            if len(parts) >= 4 {
                for i in 1..=3 {  // First triangle
                    vertex_data := strings.split(parts[i], "/")
                    defer delete(vertex_data)

                    // Parse indices (OBJ is 1-indexed!)
                    pos_idx, _ := strconv.parse_int(vertex_data[0])
                    pos_idx -= 1  // Convert to 0-indexed

                    // Add position
                    pos := positions[pos_idx]
                    append(&mesh.vertices, pos.x, pos.y, pos.z)

                    // Add normal if exists
                    if len(vertex_data) >= 3 && len(vertex_data[2]) > 0 {
                        norm_idx, _ := strconv.parse_int(vertex_data[2])
                        norm_idx -= 1
                        norm := normals[norm_idx]
                        append(&mesh.vertices, norm.x, norm.y, norm.z)
                    } else {
                        append(&mesh.vertices, 0, 1, 0)  // Default normal
                    }

                    // Add UV if exists
                    if len(vertex_data) >= 2 && len(vertex_data[1]) > 0 {
                        uv_idx, _ := strconv.parse_int(vertex_data[1])
                        uv_idx -= 1
                        uv := uvs[uv_idx]
                        append(&mesh.vertices, uv.x, uv.y)
                    } else {
                        append(&mesh.vertices, 0, 0)  // Default UV
                    }
                }
                mesh.vertex_count += 3
            }
        }
    }

    fmt.printfln("Loaded mesh: %d vertices", mesh.vertex_count)
    return mesh, true
}

// Example usage
main :: proc() {
    mesh, ok := load_obj("assets/models/cube.obj")
    if !ok {
        fmt.eprintln("Failed to load mesh")
        return
    }
    defer mesh_destroy(&mesh)

    fmt.printfln("Mesh has %d vertices", mesh.vertex_count)
    fmt.printfln("Vertex buffer size: %d floats", len(mesh.vertices))

    // Upload to GPU...
}
```

**Memory Management Breakdown:**
1. **File data**: Allocated with `os.read_entire_file()`, deleted after parsing
2. **Temp arrays** (`positions`, `normals`, `uvs`): Dynamic arrays, deleted after parsing
3. **Split strings**: Each `strings.split()` allocates, must delete
4. **Final mesh**: Returned to caller, caller must call `mesh_destroy()`

**Common Python Developer Mistake:**
```odin
// BAD - Memory leaks!
lines := strings.split_lines(content)
// Forgot to delete!
for line in lines {
    parts := strings.split(line, " ")
    // Forgot to delete!
}

// GOOD - Use defer
lines := strings.split_lines(content)
defer delete(lines)
for line in lines {
    parts := strings.split(line, " ")
    defer delete(parts)  // Cleans up each iteration
}
```

### Step 9: Render Loaded Model
- [ ] Complete this step

```odin
package main

import "core:fmt"
import gl "vendor:OpenGL"

// GPU representation of mesh
GPU_Mesh :: struct {
    vao, vbo: u32,
    vertex_count: int,
}

mesh_upload_to_gpu :: proc(mesh: ^Mesh) -> GPU_Mesh {
    gpu_mesh: GPU_Mesh
    gpu_mesh.vertex_count = mesh.vertex_count

    // Create VAO/VBO
    gl.GenVertexArrays(1, &gpu_mesh.vao)
    gl.GenBuffers(1, &gpu_mesh.vbo)

    gl.BindVertexArray(gpu_mesh.vao)
    gl.BindBuffer(gl.ARRAY_BUFFER, gpu_mesh.vbo)

    // Upload data
    gl.BufferData(
        gl.ARRAY_BUFFER,
        len(mesh.vertices) * size_of(f32),
        raw_data(mesh.vertices),
        gl.STATIC_DRAW,
    )

    // Vertex layout: pos(3) + normal(3) + uv(2) = 8 floats
    stride := 8 * size_of(f32)

    // Position
    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, i32(stride), 0)
    gl.EnableVertexAttribArray(0)

    // Normal
    gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, i32(stride), 3 * size_of(f32))
    gl.EnableVertexAttribArray(1)

    // UV
    gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, i32(stride), 6 * size_of(f32))
    gl.EnableVertexAttribArray(2)

    return gpu_mesh
}

mesh_destroy_gpu :: proc(using gpu_mesh: ^GPU_Mesh) {
    gl.DeleteVertexArrays(1, &vao)
    gl.DeleteBuffers(1, &vbo)
}

mesh_draw :: proc(using gpu_mesh: ^GPU_Mesh) {
    gl.BindVertexArray(vao)
    gl.DrawArrays(gl.TRIANGLES, 0, i32(vertex_count))
}

// Complete workflow
main :: proc() {
    // Window and OpenGL setup...

    // Load mesh from file
    mesh, ok := load_obj("assets/models/teapot.obj")
    if !ok do return
    defer mesh_destroy(&mesh)  // CPU memory

    // Upload to GPU
    gpu_mesh := mesh_upload_to_gpu(&mesh)
    defer mesh_destroy_gpu(&gpu_mesh)  // GPU memory

    // Main loop
    for !glfw.WindowShouldClose(g_window) {
        // Clear, set uniforms, etc.

        // Draw
        mesh_draw(&gpu_mesh)

        // Swap buffers
    }
}
```

**Memory Pattern:**
```
Load OBJ → CPU Memory (Mesh)
            ↓
       Upload to GPU (GPU_Mesh)
            ↓
       Delete CPU Memory (optional, if not modifying)
            ↓
       Render from GPU
            ↓
       Cleanup GPU Memory on exit
```

**Checklist for Phase 3:**
- [ ] Successfully load and parse OBJ file
- [ ] No memory leaks (all `delete` calls present)
- [ ] Model renders correctly
- [ ] Can load different OBJ files
- [ ] Understand CPU vs GPU memory workflow

---

## Phase 4: Materials & Textures (Weeks 8-9)

- [ ] **Phase 4 Complete**

### Step 10: Texture Loading
- [ ] Complete this step

**Using stb_image (C library, needs careful memory handling)**

```odin
package main

import "core:fmt"
import "core:c"
import gl "vendor:OpenGL"
import stbi "vendor:stb/image"

Texture :: struct {
    id: u32,
    width, height: i32,
}

load_texture :: proc(filepath: string) -> (Texture, bool) {
    // stb_image expects C string
    cpath := strings.clone_to_cstring(filepath)
    defer delete(cpath)

    width, height, channels: c.int

    // Load image (stb_image allocates memory!)
    data := stbi.load(cpath, &width, &height, &channels, 4)  // Force RGBA
    if data == nil {
        fmt.eprintfln("Failed to load texture: %s", filepath)
        return {}, false
    }
    defer stbi.image_free(data)  // MUST free stb_image memory!

    // Create OpenGL texture
    tex: Texture
    tex.width = width
    tex.height = height

    gl.GenTextures(1, &tex.id)
    gl.BindTexture(gl.TEXTURE_2D, tex.id)

    // Upload to GPU
    gl.TexImage2D(
        gl.TEXTURE_2D,
        0,
        gl.RGBA,
        width,
        height,
        0,
        gl.RGBA,
        gl.UNSIGNED_BYTE,
        data,
    )
    gl.GenerateMipmap(gl.TEXTURE_2D)

    // Set parameters
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

    return tex, true
}

texture_destroy :: proc(using tex: ^Texture) {
    gl.DeleteTextures(1, &id)
}

texture_bind :: proc(tex: ^Texture, slot: u32 = 0) {
    gl.ActiveTexture(gl.TEXTURE0 + slot)
    gl.BindTexture(gl.TEXTURE_2D, tex.id)
}
```

**Critical Memory Note:**
- `stbi.load()` allocates memory using C's `malloc`
- NOT part of Odin's allocator system
- MUST call `stbi.image_free()`, not `delete()`
- After upload to GPU, CPU copy can be freed

### Step 11: Material System
- [ ] Complete this step

```odin
package main

import la "core:math/linalg"

Material :: struct {
    diffuse_color: la.Vector3f32,
    specular_color: la.Vector3f32,
    shininess: f32,

    diffuse_map: ^Texture,   // Optional textures
    specular_map: ^Texture,
    normal_map: ^Texture,
}

material_create :: proc() -> Material {
    return Material{
        diffuse_color = {1.0, 1.0, 1.0},
        specular_color = {0.5, 0.5, 0.5},
        shininess = 32.0,
    }
}

material_bind :: proc(mat: ^Material, shader: u32) {
    // Bind colors
    diffuse_loc := gl.GetUniformLocation(shader, "material.diffuse")
    specular_loc := gl.GetUniformLocation(shader, "material.specular")
    shininess_loc := gl.GetUniformLocation(shader, "material.shininess")

    gl.Uniform3fv(diffuse_loc, 1, &mat.diffuse_color.x)
    gl.Uniform3fv(specular_loc, 1, &mat.specular_color.x)
    gl.Uniform1f(shininess_loc, mat.shininess)

    // Bind textures if present
    if mat.diffuse_map != nil {
        texture_bind(mat.diffuse_map, 0)
        gl.Uniform1i(gl.GetUniformLocation(shader, "material.diffuseMap"), 0)
    }

    if mat.specular_map != nil {
        texture_bind(mat.specular_map, 1)
        gl.Uniform1i(gl.GetUniformLocation(shader, "material.specularMap"), 1)
    }
}

// Updated fragment shader
PHONG_SHADER := `#version 330 core
in vec3 FragPos;
in vec3 Normal;
in vec2 TexCoords;

out vec4 FragColor;

struct Material {
    vec3 diffuse;
    vec3 specular;
    float shininess;
    sampler2D diffuseMap;
    sampler2D specularMap;
};

uniform Material material;
uniform vec3 lightPos;
uniform vec3 viewPos;

void main() {
    // Ambient
    vec3 ambient = 0.1 * texture(material.diffuseMap, TexCoords).rgb;

    // Diffuse
    vec3 norm = normalize(Normal);
    vec3 lightDir = normalize(lightPos - FragPos);
    float diff = max(dot(norm, lightDir), 0.0);
    vec3 diffuse = diff * texture(material.diffuseMap, TexCoords).rgb;

    // Specular
    vec3 viewDir = normalize(viewPos - FragPos);
    vec3 reflectDir = reflect(-lightDir, norm);
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), material.shininess);
    vec3 specular = spec * texture(material.specularMap, TexCoords).rgb;

    vec3 result = ambient + diffuse + specular;
    FragColor = vec4(result, 1.0);
}
`
```

**Checklist for Phase 4:**
- [ ] Load and display textures on models
- [ ] Understand stb_image memory management
- [ ] Phong lighting with textures working
- [ ] Material system implemented

---

## Phase 5 & 6: Advanced Features (Weeks 10-14+)

- [ ] **Phase 5 Complete**
- [ ] **Phase 6 Complete**

Due to length constraints, here's an outline:

### Step 12-15: Advanced Editor Features
- [ ] Transform gizmos implemented
- [ ] Object picking working
- [ ] Scene graph system complete
- [ ] ImGui integrated
- Transform gizmos (arrow/rotation/scale handles)
- Object picking with raycasting
- Scene graph with parent-child transforms
- ImGui integration for UI panels

### Step 16-18: Export & Polish
- [ ] Save/load scene format implemented
- [ ] Export to OBJ/GLTF working
- [ ] Undo/redo system complete
- [ ] Performance optimization done

**Key Memory Patterns for Advanced Features:**

1. **Scene Graph**:
```odin
Scene_Node :: struct {
    name: string,
    transform: la.Matrix4f32,
    mesh: ^GPU_Mesh,
    material: ^Material,
    children: [dynamic]^Scene_Node,  // Dynamic array of pointers
    parent: ^Scene_Node,
}

scene_node_destroy :: proc(node: ^Scene_Node) {
    delete(node.name)
    for child in node.children {
        scene_node_destroy(child)  // Recursive cleanup
        free(child)
    }
    delete(node.children)
}
```

2. **Undo System**:
```odin
Command :: struct {
    execute: proc(^Command),
    undo: proc(^Command),
    data: rawptr,  // Command-specific data
}

History :: struct {
    commands: [dynamic]Command,
    current_index: int,
}

// Use arena allocator for undo history
history_create :: proc() -> History {
    // Allocate with temp arena, clear on save
}
```

---

## Common Memory Patterns Summary

### Pattern 1: Load → Process → Free
```odin
// Load resource
data, ok := os.read_entire_file("data.txt")
if !ok do return
defer delete(data)  // Free when done

// Process...
```

### Pattern 2: Create → Upload to GPU → Optional CPU Free
```odin
// Create CPU data
mesh, ok := load_obj("model.obj")
defer mesh_destroy(&mesh)

// Upload to GPU
gpu_mesh := mesh_upload_to_gpu(&mesh)
defer mesh_destroy_gpu(&gpu_mesh)

// Can delete CPU data now if not editing
// delete(mesh.vertices)
```

### Pattern 3: Temporary Allocations
```odin
import "core:mem"

process_frame :: proc() {
    // Use temp allocator for per-frame data
    arena: mem.Arena
    temp_allocator := mem.arena_allocator(&arena)
    defer mem.arena_destroy(&arena)  // Free all at end of frame

    context.allocator = temp_allocator
    {
        // All allocations here freed automatically
        temp_data := make([dynamic]f32)
        // No need to delete individually!
    }
}
```

### Pattern 4: Resource Manager
```odin
Resource_Manager :: struct {
    textures: map[string]^Texture,
    meshes: map[string]^GPU_Mesh,
    arena: mem.Arena,
}

resource_manager_create :: proc() -> Resource_Manager {
    rm: Resource_Manager
    mem.arena_init(&rm.arena, make([]byte, 10 * 1024 * 1024))  // 10 MB

    allocator := mem.arena_allocator(&rm.arena)
    rm.textures = make(map[string]^Texture, allocator)
    rm.meshes = make(map[string]^GPU_Mesh, allocator)

    return rm
}

resource_manager_destroy :: proc(rm: ^Resource_Manager) {
    // Destroy all resources
    for _, tex in rm.textures do texture_destroy(tex)
    for _, mesh in rm.meshes do mesh_destroy_gpu(mesh)

    // Free entire arena at once
    mem.arena_destroy(&rm.arena)
}
```

---

## Resources

### Official Odin Resources
- **Website**: https://odin-lang.org
- **Documentation**: https://odin-lang.org/docs/
- **GitHub**: https://github.com/odin-lang/Odin
- **Examples**: Check `examples/` in Odin repo

### Community
- **Discord**: Very active, helpful community
- **r/odinlang**: Subreddit for discussions

### Graphics Learning
- **Learn OpenGL**: https://learnopengl.com (C++, translate to Odin)
- **3D Math Primer**: Book by Fletcher Dunn
- **Real-Time Rendering**: Comprehensive graphics book

### Memory Management
- Check out `core/mem` package documentation
- Study arena allocators for bulk operations
- Read about tracking allocator for debugging leaks

---

## Final Tips for Python Developers

1. **Think About Lifetimes**
   - Python: "When am I done with this?"
   - Odin: "When should this memory be freed?"

2. **Use `defer` Aggressively**
   - Like Python's `with`, but more flexible
   - Put `defer delete()` right after allocation

3. **Start Small with Allocations**
   - Fixed-size arrays when possible
   - Slices for views, dynamic arrays for growth
   - Don't default to heap allocation

4. **Debug Memory Issues**
   ```odin
   import "core:mem"

   track: mem.Tracking_Allocator
   mem.tracking_allocator_init(&track, context.allocator)
   context.allocator = mem.tracking_allocator(&track)

   defer {
       for _, leak in track.allocation_map {
           fmt.printfln("Leaked %d bytes", leak.size)
       }
       mem.tracking_allocator_destroy(&track)
   }
   ```

5. **When in Doubt, Check Examples**
   - Odin's vendor packages have examples
   - Community projects on GitHub
   - Ask on Discord

---

Good luck with your 3D editor! Take it one step at a time, and don't hesitate to revisit earlier phases as you learn more. Building this project will teach you both Odin and 3D graphics programming - it's a great learning journey!
