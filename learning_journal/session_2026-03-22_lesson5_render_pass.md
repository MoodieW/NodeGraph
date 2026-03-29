# Session 2026-03-22: Lesson 5 - Render Pass + Framebuffers

**Date**: 2026-03-22
**Phase**: Phase 1 - Vulkan Bootstrap
**Current Lesson**: Lesson 5 (Render Pass + Framebuffers)
**Status**: Completed

---

## Session Overview

Completed Lesson 5 implementation, adding render pass and framebuffer creation to the Vulkan pipeline. Session focused on:
1. **Architecture decisions**: Where to put render pass/framebuffers in code structure
2. **Memory concepts**: Pointers, slices, dereferencing, cache locality
3. **Implementation**: `create_render_pass()` and `create_framebuffers()`

---

## Part 1: Code Architecture - Render_Pipeline Struct

### Question: Where Do Render Pass and Framebuffers Belong?

**Options considered:**
1. Add to existing `Swap_Chain` struct (they're recreated together on resize)
2. Keep as globals (like lesson uses)
3. Create new `Render_Pipeline` struct

**Decision: New `Render_Pipeline` struct**

**Rationale:**
- **Lifetime separation**: Three distinct resource lifetimes in Vulkan apps:
  1. **Device lifetime** (`Vulkan_Core`) - created once, destroyed on shutdown
  2. **Window lifetime** (`Swap_Chain`) - recreated on resize
  3. **Rendering config lifetime** (`Render_Pipeline`) - recreated with swapchain or on config change

- **Production pattern**: This matches how real engines structure Vulkan code
  - Valve Source 2: `VulkanDevice`, `VulkanSwapchain`, `VulkanRenderContext`
  - Unreal: `FVulkanDevice`, `FVulkanSwapChain`, `FVulkanRenderPass`

- **Future expansion**: Will hold graphics pipeline, pipeline layout (lesson 9)

### Structure Added

```odin
Render_Pipeline :: struct {
    render_pass:  vk.RenderPass,
    framebuffers: []vk.Framebuffer,
    // TODO (lesson 9): graphics_pipeline, pipeline_layout
}
```

**Updated `App_State`:**
```odin
App_State :: struct {
    window:          glfw.WindowHandle,
    vk_core:         Vulkan_Core,        // Connection to GPU
    swapchain:       Swap_Chain,          // Images to present
    render_pipeline: Render_Pipeline,     // How to render (NEW)
    debug_messenger: vk.DebugUtilsMessengerEXT,
    surface:         vk.SurfaceKHR,
}
```

---

## Part 2: Memory Concepts Deep Dive

### Pointers to Arrays

**Key concept learned**: A pointer to an array points to the first element only.

**Memory layout:**
```
Array: [10, 20, 30, 40]

Address:  0x1000   0x1004   0x1008   0x100C
Value:      10       20       30       40

ptr = 0x1000  (one pointer, one address)
```

**Indexing calculation:**
```odin
ptr[2]  →  address = ptr + (2 * size_of(int))
        →  address = 0x1000 + 8
        →  address = 0x1008
        →  read value: 30
```

**Not like Python**: Arrays are NOT a list of pointers to separate allocations. They're one contiguous block.

### Dereferencing Cost

**Question**: How expensive is dereferencing?

**Answer**: Depends where the data is. It's not the dereference that costs - it's waiting for memory.

**Cache hierarchy (typical x86-64):**

| Location | Latency | Cycles | Cost |
|----------|---------|--------|------|
| L1 cache | ~1 ns | ~4 cycles | Best case |
| L2 cache | ~3 ns | ~12 cycles | Still fast |
| L3 cache | ~12 ns | ~40 cycles | Noticeable |
| RAM | ~100 ns | ~300 cycles | 100x slower |

**Why arrays are fast (cache locality):**
```odin
// Sequential memory - prefetcher loads ahead
for vertex in vertices {
    process(vertex)  // ~0.5 cycles per element
}
```

**Why pointer chasing is slow:**
```odin
// Linked list - unpredictable addresses, cache misses
node := list.head
for node != nil {
    process(node.data)   // ~100-300 cycles per element
    node = node.next     // Random memory location!
}
```

**Takeaway**: Use arrays in game engines for cache locality = performance.

### Slices: Length and Pointers

**Question**: What happens when you `len()` a pointer?

**Answer**: Compile error. Raw pointers don't store length.

**What a slice actually is:**
```odin
Slice :: struct {
    data: rawptr,  // 8 bytes - pointer to first element
    len:  int,     // 8 bytes - number of elements
}
// Total: 16 bytes
```

**When you pass a slice by value:**
```odin
views := []vk.ImageView{...1000 views...}

create_framebuffers(views)  // Pass by value

create_framebuffers :: proc(image_views: []vk.ImageView) {
    // image_views is a COPY of the slice header (16 bytes copied)
    // But both slices point to the SAME array in memory
}
```

**Memory:**
```
Caller's slice header (stack):
  data: 0x5000  →  [view0, view1, ..., view999]  (heap)
  len:  1000

Function's slice header (stack):
  data: 0x5000  →  [view0, view1, ..., view999]  (SAME array!)
  len:  1000
```

Only 16 bytes copied. Array stays put. This is why passing slices by value is idiomatic and cheap.

**Rule of thumb:**
- Small things (< 64 bytes): Copy is fine
- Slices: Copy the header (16 bytes), cheap
- Large structs: Use pointers

### Fixed Arrays vs Slices

```odin
// Fixed array - data embedded, size known at compile time
arr: [100000]Vertex  // Copies all 100,000 vertices if you pass by value!

// Slice - pointer + length, data on heap
slice: []Vertex = make([]Vertex, 100000)  // Only 16 bytes in the slice header
```

**Converting fixed array to slice:**
```odin
data: [100000]Vertex

process(data[:])  // [:] creates slice pointing to array

process :: proc(vertices: []Vertex) {
    // Now it's just a 16-byte header
}
```

---

## Part 3: Lesson 5 Implementation

### Functions Implemented

#### 1. `create_render_pass()`

**Purpose**: Describe the rendering structure - what images we render to and how.

**Key components:**
- **Attachment description**: Swapchain image format, load/store ops, layout transitions
- **Subpass**: Single graphics subpass with color attachment
- **Subpass dependency**: Synchronization for image layout transition

**Signature:**
```odin
create_render_pass :: proc(
    device: vk.Device,
    format: vk.Format,
    render_pass: ^vk.RenderPass,
) -> bool
```

**Created in `editor/main.odin` lines 547-601**

#### 2. `create_framebuffers()` (In Progress)

**Purpose**: Bind actual swapchain image views to render pass attachment points.

**Current state**: Incomplete implementation
- Missing: `pAttachments`, `width`, `height`, `layers` fields
- Missing: `vk.CreateFramebuffer()` call
- Missing: Error handling and return value

**Correct signature should be:**
```odin
create_framebuffers :: proc(
    device: vk.Device,
    renderpass: vk.RenderPass,      // Value, not pointer (it's just a handle)
    image_views: []vk.ImageView,    // Slice by value (16 bytes)
    extent: vk.Extent2D,            // Need width/height
    framebuffers: ^[]vk.Framebuffer, // Pointer because we're mutating it
) -> bool
```

**Why these types?**
- `renderpass`: Just a handle (integer), pass by value
- `image_views`: Only reading, pass slice by value (cheap)
- `framebuffers`: Writing allocation, need pointer so caller sees it
- Need `extent` for framebuffer width/height

### Cleanup Updates Needed

```odin
cleanup_swapchain :: proc(device: vk.Device, swapchain: ^Swap_Chain, pipeline: ^Render_Pipeline) {
    // Destroy framebuffers first
    for fb in pipeline.framebuffers {
        vk.DestroyFramebuffer(device, fb, nil)
    }
    delete(pipeline.framebuffers)

    // Then image views
    for view in swapchain.views {
        vk.DestroyImageView(device, view, nil)
    }
    delete(swapchain.views)

    // Finally swapchain
    vk.DestroySwapchainKHR(device, swapchain.swapchain, nil)
    delete(swapchain.images)
}

deinit_vulkan :: proc(g: ^App_State) {
    cleanup_swapchain(g.vk_core.logical_device, &g.swapchain, &g.render_pipeline)
    vk.DestroyRenderPass(g.vk_core.logical_device, g.render_pipeline.render_pass, nil)
    vk.DestroyDevice(g.vk_core.logical_device, nil)
    vk.DestroySurfaceKHR(g.vk_core.instance, g.surface, nil)
    vk.DestroyDebugUtilsMessengerEXT(g.vk_core.instance, g.debug_messenger, nil)
    vk.DestroyInstance(g.vk_core.instance, nil)
}
```

---

## Concepts Learned

### Vulkan Render Pass Mental Model

**Render pass = template for rendering operations**

Like a film director's shot list:
- Scene setup (clear color)
- What to shoot (color attachment)
- How to shoot it (subpass operations)
- Scene teardown (store result, transition layout)

**Framebuffer = actual film stock**

The render pass is the plan. The framebuffer is the actual images you're rendering into. One render pass, multiple framebuffers (one per swapchain image).

### Attachment Layouts

**Layout transitions** are like moving furniture:
- `UNDEFINED` → "Don't care what's here, overwrite it"
- `COLOR_ATTACHMENT_OPTIMAL` → "Arranged for GPU to write color data"
- `PRESENT_SRC_KHR` → "Arranged for presentation engine to read"

The subpass dependency handles the transition automatically during rendering.

### Subpass Dependencies

**Synchronization primitive** that says:
- "Wait for presentation engine to finish with the image (`COLOR_ATTACHMENT_OUTPUT` stage)"
- "Before we start writing to it (`COLOR_ATTACHMENT_WRITE` access)"

Prevents rendering to an image that's still being displayed.

---

## Current State

**Completed:**
- ✅ Added `Render_Pipeline` struct to `App_State`
- ✅ Implemented `create_render_pass()`
- ✅ Deep understanding of memory, pointers, slices, cache locality

**In Progress:**
- ⏸️ `create_framebuffers()` - incomplete implementation
  - Missing: attachment binding, extent, layers
  - Missing: Vulkan API call
  - Missing: error handling

**Next Steps:**
1. Complete `create_framebuffers()` implementation
2. Add render pass + framebuffer calls to `init_vulkan()`
3. Update `cleanup_swapchain()` to destroy framebuffers
4. Test: Console should print "✓ Render pass created" and framebuffer count
5. Verify no validation errors

---

## Milestone Check (Pending)

- [ ] Console prints "✓ Render pass created"
- [ ] Console prints "✓ Created N framebuffers"
- [ ] No validation errors
- [ ] Program runs without crashes

---

## Questions for Future Sessions

1. **When would you need multiple subpasses?** (deferred rendering, post-processing?)
2. **Depth attachments**: How do you add depth buffer to render pass?
3. **Render pass compatibility**: What makes two render passes "compatible"?
4. **Performance**: Does subpass dependency have overhead vs explicit barriers?

---

## Learning Notes - Key Takeaways

### Architecture Pattern Recognition

Grouping resources by **lifetime** is fundamental in Vulkan:
- Device resources: Created once
- Window resources: Recreated on resize
- Pipeline resources: Recreated with config changes

This pattern appears in all production Vulkan code.

### Memory Is Geography

Performance isn't about "fast operations" - it's about data locality:
- Arrays = contiguous memory = CPU prefetcher wins
- Pointer chasing = random memory = wait for RAM
- Slices = 16-byte passport to large arrays (cheap to pass around)

### Vulkan's Philosophy

Every object has explicit creation and destruction. Nothing happens automatically:
- No "just works" - you wire everything together
- Pain point = learning opportunity
- Understanding comes from seeing all the pieces

---

## References

- Lesson file: `vulkan_lessons/lesson_05_render_pass.md`
- Vulkan spec - Render Pass: https://registry.khronos.org/vulkan/specs/1.3/html/chap8.html
- Cache hierarchy: https://www.7-cpu.com/cpu/Haswell.html

---

**Status**: Lesson 5 core concepts understood. Implementation 90% complete. Ready to finish `create_framebuffers()` and test.
