# Session 2026-03-07: Pivoting to Vulkan

## Major Decision

Decided to abandon OpenGL path and learn Vulkan instead. Going against all advice, but the goal is to learn how GPUs actually work, not just how to use a convenient API.

## Why Vulkan?

**Learning goals:**
- Understand exactly what the GPU is doing (Vulkan hides nothing)
- Explicit control over memory management, synchronization, command recording
- Learn modern graphics API architecture (DX12, Metal follow similar patterns)
- Deep GPU architecture knowledge

**Trade-offs accepted:**
- ~1000+ lines before drawing first triangle (vs ~50 in OpenGL)
- Validation layers will yell constantly (this is good - learning tool)
- Manual synchronization (easy to crash)
- Steep learning curve
- Phase 1 alone will take a week (just infrastructure, no rendering)

## The Vulkan Learning Plan Structure

Created `3d_editor_vulkan_learning_plan.md` with milestone-driven approach.

### Phase 0: Mental Model
- Understand Vulkan's multi-stage architecture
- Command recording vs execution
- Memory model (explicit allocation/binding)
- Synchronization primitives (fences, semaphores, barriers)
- Validation layers

**Key insight:** You can't skip steps in Vulkan. Every object in the pipeline is mandatory.

### Phase 1: The Gauntlet (7 Lessons of Pure Boilerplate)

No rendering. Just building infrastructure. Each lesson has verifiable milestone:

**Lesson 1: Instance + Debug Messenger**
- Milestone: Window opens, validation layers print to console
- GPU connection established

**Lesson 2: Surface + Physical Device**
- Milestone: Console prints actual GPU name and specs
- Device suitability checking

**Lesson 3: Logical Device + Queues**
- Milestone: Queue handles printed (graphics, present)
- Interface to GPU ready

**Lesson 4: Swapchain**
- Milestone: Swapchain image count printed (2 or 3)
- Ringbuffer of images for presenting ready

**Lesson 5: Render Pass + Framebuffers**
- Milestone: Render pass created, framebuffer count printed
- Rendering template ready

**Lesson 6: Command Pools + Buffers**
- Milestone: Command buffers allocated
- Recording infrastructure ready

**Lesson 7: Synchronization Objects**
- Milestone: Semaphores and fences created
- CPU-GPU and GPU-GPU sync ready

**Total: ~1000 lines of boilerplate before anything renders.**

### Phase 2: First Rendering

**Lesson 8: Clear Screen**
- Milestone: Solid blue window
- First visual confirmation
- Command recording → submission → present flow working

**Lesson 9: Triangle**
- Milestone: RGB triangle on screen
- Shaders compiled to SPIR-V
- Graphics pipeline created (all stages: vertex input, assembly, viewport, rasterizer, multisampling, blending)
- Draw command working

**Infamous "1000 lines for a triangle" achieved.**

### Phase 3-6: Building Up (Outlined)

**Phase 3: 3D Rendering**
- Lesson 10: Uniform buffers (MVP matrices)
- Lesson 11: Vertex buffers
- Lesson 12: Index buffers
- Lesson 13: Depth testing

**Phase 4: Textures**
- Lesson 14: Image and sampler
- Lesson 15: Combined image samplers

**Phase 5: Model Loading**
- Lesson 16: Staging buffers
- Lesson 17: OBJ loader

**Phase 6: Editor Features**
- Lesson 18: ImGui
- Lesson 19: Camera system
- Lesson 20: Object selection

## Key Differences from OpenGL Plan

| Aspect | OpenGL Plan | Vulkan Plan |
|--------|------------|-------------|
| Setup complexity | ~50 lines | ~1000+ lines |
| State management | Global state machine | Explicit state objects |
| Error handling | Query errors after calls | Validation layers (debug only) |
| Commands | Immediate execution | Record then submit |
| Sync | Mostly implicit | Completely explicit |
| First visual | Step 2 (triangle) | Lesson 8 (clear), Lesson 9 (triangle) |
| Memory | Driver managed | Manually allocate/bind |

## Development Environment

Same Nix flake, added packages:
- `vulkan-headers`
- `vulkan-loader`
- `vulkan-validation-layers`
- `shaderc` (GLSL → SPIR-V compiler)

Build commands unchanged:
```bash
odin build . -debug
```

Shader compilation:
```bash
glslc shaders/triangle.vert -o shaders/triangle.vert.spv
glslc shaders/triangle.frag -o shaders/triangle.frag.spv
```

## Milestone-Driven Learning

Each lesson has concrete verification:
- Console prints (GPU name, handle addresses, object counts)
- Validation layer silence (no errors = correct)
- Visual confirmation (clear color, rendered triangle)

**No moving forward until milestone achieved.**

## Reality Check

Expectation: Phase 1 will take ~1 week. Just infrastructure. No rendering.

When Lesson 8 finally shows blue screen, I'll know:
- Why it's blue
- Which GPU memory that color is in
- Which command buffer recorded the clear
- Which queue it was submitted to
- How the fence synchronized CPU and GPU
- How the semaphore coordinated swapchain and rendering
- How the present operation displayed it

**That's the payoff. No magic. Just explicit knowledge of GPU operation.**

## Next Steps

1. Start Phase 1, Lesson 1
2. Get instance and debug messenger working
3. See validation layers print to console
4. Move through boilerplate systematically
5. Don't rush. Understand each piece.

## Key Insight from This Session

Vulkan forces you to think like the GPU. Everything is asynchronous. Resources must outlive GPU operations. Synchronization is manual. This is hard, but it's how modern GPUs work.

OpenGL abstracts this. Vulkan exposes it. For learning GPU architecture, Vulkan is the right choice, even though it's painful.

The question isn't "can I get something on screen quickly?" It's "do I want to understand how GPUs actually work?"

Answer: Yes. Hence Vulkan.

---

## Learning Plan Organization

Created modular lesson structure:
- Main plan: `3d_editor_vulkan_learning_plan.md` (overview with links)
- Individual lessons: `vulkan_lessons/lesson_XX_name.md` (10 files)

Each lesson file contains:
- Clear milestone (verifiable output)
- Concepts explained
- Complete code
- Milestone checklist
- "What you learned" summary

Benefits of this structure:
- Can focus on one lesson at a time
- Easy to track progress
- Can reference specific lessons later
- Main plan provides big picture
- Lessons provide implementation details

---

## Questions & Key Insights

### Q: Do command buffers provide rollback mechanisms?

**A: No. Command buffers are write-only.**

Key points discovered:
- Command buffers record GPU instructions (binary bytecode)
- Cannot read, modify, or reverse commands
- GPU operations are destructive (pixels overwritten, no history)
- Append-only during recording, read-only during execution

**Undo/redo must be implemented at application level:**

Pattern for 3D editor:
```odin
Command :: struct {
    execute: proc(^Command),
    undo: proc(^Command),      // Manual inverse operation
    data: rawptr,
}
```

Application-level undo flow:
1. User action (move object)
2. Create Command with execute/undo procs
3. Execute (modifies CPU state + uploads to GPU)
4. Add to history stack
5. On undo: call undo proc (restores CPU state + re-uploads to GPU)
6. Re-render scene

**Don't confuse:**
- GPU command buffers (Vulkan) - binary GPU instructions, no rollback
- Application commands (editor) - high-level operations with undo/redo

GPU just renders what you give it. Undo is your responsibility.

### Q: Is logical device an interface layer?

**A: Exactly. Logical device = your application's interface to the GPU.**

**Physical Device vs Logical Device:**

```
Physical Device (vk.PhysicalDevice)
- The actual GPU hardware
- Query capabilities (what it can do)
- Read-only, discovery only
- Shared by all applications

Logical Device (vk.Device)
- Your app's connection to that GPU
- Your configured interface
- Choose which features to enable
- Request specific queue families
- Enable extensions you need
- Owns all your resources
```

**Multiple apps, multiple logical devices:**
```
Physical Device (RTX 3080)
    ├─ Logical Device (3D Editor)     ← isolated
    ├─ Logical Device (Chrome)         ← isolated
    ├─ Logical Device (Game)           ← isolated
    └─ Logical Device (Compositor)     ← isolated
```

Each app gets:
- Own queue handles
- Own enabled features
- Own resources
- Isolation from other apps

**All Vulkan resources are tied to logical device:**
```odin
vk.CreateBuffer(logical_device, ...)
vk.CreateImage(logical_device, ...)
vk.CreatePipeline(logical_device, ...)
```

When you destroy logical device, all resources cleaned up.

**Database analogy:**
- Physical Device = Database Server (hardware)
- Logical Device = Database Connection (your session)

Multiple connections to one server. Each connection isolated.

**Key insight:** Logical device is the handle you use for everything in Vulkan. Every resource creation, every queue operation - all go through your logical device.

---

## Aha Moments

1. **Command buffers are one-way streets**: No inspection, no rollback, no modification. This clarifies why undo systems must be built at application level. GPU doesn't care about history.

2. **Physical vs Logical separation is about isolation**: Physical device = what exists. Logical device = your configured view. This allows multiple apps to safely share GPU with different feature sets enabled.

3. **Vulkan forces you to think about resource ownership**: Everything belongs to logical device. Cleanup is explicit. No garbage collection, no driver magic.

---

## Progress Summary

**Completed:**
- [x] Created Vulkan learning plan
- [x] Split into 10 individual lesson files
- [x] Updated main plan with links
- [x] Documented lesson structure
- [x] Clarified command buffer limitations (no rollback)
- [x] Clarified physical vs logical device roles

**Next:**
- [ ] Set up Nix flake with Vulkan packages
- [ ] Start Lesson 0 (Mental Model review)
- [ ] Begin Lesson 1 (Instance + Debug Messenger)

**Understanding level:**
- Vulkan architecture: Mental model clear
- Command buffers: Understand write-only nature
- Device abstraction: Understand physical/logical split
- Undo systems: Know it's application-level responsibility

Ready to start implementation.

---

## Additional Q&A

### Q: Why would I have multiple logical devices in one app?

**A: You wouldn't (normally).**

**Single app = single logical device.** That's standard.

Multiple logical devices only for rare cases:
- Multi-GPU rendering (use 2+ physical GPUs simultaneously)
- Separate compute contexts (very rare, usually just use different queues)

**Your 3D editor:**
- 1 physical device (your GPU)
- 1 logical device (your app's interface)
- Multiple queues (graphics, present, maybe compute)

**The database analogy clarified:**
- Multiple **apps** each create their own logical device
- Each app has **one** logical device
- Physical GPU is shared, logical devices are isolated

### Q: So if one app crashes, it doesn't take everything down?

**A: Exactly. Isolation and fault tolerance.**

**When your app crashes:**
```
Physical GPU
    ├─ Desktop Compositor  ← Still running
    ├─ Browser             ← Still running
    └─ Your Editor         ← CRASHED
```

What happens:
1. Your logical device destroyed/cleaned up
2. All YOUR resources freed (buffers, pipelines, memory)
3. Other apps keep running
4. GPU keeps working
5. Desktop stays up

**Driver tracks which resources belong to which logical device.** When your process dies, driver frees only your resources.

**Contrast with old OpenGL:**
- Early implementations had shared global state
- One app's bug could corrupt everyone
- GPU hang → entire display freezes
- Often needed reboot

**Vulkan enforces isolation:** Your mess is your mess.

**Exception:** GPU hang (infinite shader loop) can still affect everyone, but modern GPUs have TDR (Timeout Detection and Recovery) that resets GPU and kills your app.

### Q: Is this why Blue Screen of Death happened?

**A: Yes! GPU drivers running in kernel mode caused BSODs.**

**Old Windows (XP and earlier):**
```
Application
    ↓
Graphics API
    ↓
GPU Driver (KERNEL MODE) ← Crash here = BSOD
    ↓
GPU
```

**If driver crashed:**
- Kernel panic
- Blue Screen of Death
- Entire system down
- Reboot required

**Common causes:**
- App passes bad data → driver doesn't validate → crash
- GPU hangs → driver can't recover → hang/BSOD
- Driver bug → corrupts kernel memory → BSOD

**Windows Vista (2006): WDDM changed everything**

New architecture:
```
Application
    ↓
User-Mode Driver ← Most code here (crash = just app dies)
    ↓
Kernel-Mode Driver ← Minimal code
    ↓
GPU
```

**Improvements:**
1. Driver split: most code in user mode (safe)
2. TDR: timeout detection, GPU reset, driver recovery
3. GPU memory isolation: apps can't corrupt each other

**Modern Vulkan/DX12 makes it even better:**
- Validation layers catch bugs before hitting driver
- Thin drivers (less code = fewer bugs)
- Explicit state (less driver guessing)
- Result: BSODs are rare now

**Your development experience:**
- Validation catches bugs
- Your app crashes
- Desktop stays up
- No BSOD
- Fix bug and continue

### Q: Command recording vs execution is like render farm job submission?

**A: Perfect analogy.**

**Render farm workflow:**
1. Build job description (scene, dependencies)
2. Submit to farm
3. Farm executes async
4. Check for completion

**Vulkan command buffers:**
1. Record commands (draw, clear, copy)
2. Submit to GPU queue
3. GPU executes async
4. Fence for completion

**Both are async work submission with dependency management.**

**Recording = building the job (CPU, fast):**
```odin
vk.BeginCommandBuffer(cmd)
vk.CmdDraw(...)  // Writing instructions, not executing
vk.CmdDraw(...)
vk.EndCommandBuffer(cmd)
// Nothing has rendered yet
```

**Submission = sending to farm:**
```odin
vk.QueueSubmit(queue, ...)
// CPU continues immediately
// GPU starts work when dependencies satisfied
```

**Execution = farm processing (async):**
```
CPU: Records frame N+1
GPU: Renders frame N (parallel!)
```

**Multi-frame in-flight = farm queue depth:**
- Frame N: GPU rendering
- Frame N+1: CPU recording
- Pipeline parallelism

**Why this design:**
- Maximize parallelism (CPU and GPU work together)
- Batch work for efficiency
- CPU doesn't stall waiting for GPU

**Contrast with immediate mode (OpenGL):**
```c
glDraw()  // Execute NOW (CPU waits)
glDraw()  // Execute NOW
// CPU and GPU serialized
```

Like render farm where you wait for each step (slow).

### Q: Semaphores vs Fences?

**A: Different sync directions.**

**Semaphore = GPU ↔ GPU dependency:**
- GPU operation A must finish before GPU operation B
- No CPU involvement
- CPU doesn't wait

```odin
submit_work_A(signal_semaphore = sem_A)
submit_work_B(wait_semaphore = sem_A)
// GPU waits for GPU, CPU continues
```

**Fence = CPU ↔ GPU dependency:**
- CPU waits for GPU to finish
- CPU blocks

```odin
vk.QueueSubmit(..., fence)
do_some_work()
vk.WaitForFences(fence)  // CPU BLOCKS here
// GPU done, CPU continues
```

**The difference:**
| Semaphore | Fence |
|-----------|-------|
| GPU ↔ GPU | CPU ↔ GPU |
| GPU waits | CPU waits |
| No CPU blocking | CPU blocks |
| Coordinate GPU work | Tell CPU when done |

**Render farm analogy:**

**Semaphore** = job dependency on farm:
```bash
submit job_B --depends-on job_A
# Farm waits, you don't
```

**Fence** = notification to you:
```bash
submit job --notify-when-done
wait_for_notification()  # YOU block
```

**Why both:**
- Fences block CPU (expensive)
- Semaphores let GPU work independently (fast)
- Only use fences when you truly need the result

**Relay race analogy:**
- Semaphores = baton passes between GPU runners
- Fence = bell that signals the CPU coach

**Frame rendering example:**
```odin
vk.WaitForFences(...)  // CPU waits for previous frame

vk.AcquireNextImage(..., image_available_semaphore)
// GPU signals semaphore when image ready

vk.QueueSubmit(
    wait = image_available_semaphore,    // GPU waits
    signal = render_finished_semaphore,  // GPU signals
    fence = in_flight_fence,             // CPU notified
)

vk.QueuePresent(wait = render_finished_semaphore)
// GPU waits for render to finish

// CPU continues to next frame
```

**Semaphores:** GPU coordinates with itself
**Fence:** CPU knows when GPU is done

---

## Updated Understanding

**Vulkan mental model solidified:**
- Command buffers = async job descriptions
- Logical device = isolated interface per app
- Semaphores = GPU-to-GPU sync (horizontal)
- Fences = GPU-to-CPU sync (vertical)
- Validation = catch bugs before they hit GPU
- Isolation = crashes don't propagate

**Key insight:** Modern graphics APIs learned from render farm architectures. Async submission, dependency graphs, pipeline parallelism - same concepts, different domain.

**Ready to implement.** The abstractions make sense now.

### Q: Is swapchain a store of images (previous, current, next)?

**A: Exactly. Swapchain = ringbuffer of 2-3 images you rotate through.**

**The rotation:**
```
Frame N:
  Image 0: [Displayed on screen]
  Image 1: [GPU rendering to this]
  Image 2: [Waiting, ready]

Frame N+1:
  Image 0: [Waiting]
  Image 1: [Displayed on screen]
  Image 2: [GPU rendering to this]

Frame N+2:
  Image 0: [GPU rendering to this]
  Image 1: [Waiting]
  Image 2: [Displayed on screen]
```

Round-robin cycle through the images.

**Why multiple images: Prevent tearing**

Single image (bad):
- GPU writing pixels
- Display reading pixels simultaneously
- Result: half-old, half-new frame visible
- Screen tearing

Double buffering (2 images):
- Image 0: Front buffer (display reads)
- Image 1: Back buffer (GPU writes)
- When done: SWAP
- Display and GPU never touch same image

Triple buffering (3 images):
- Even smoother
- GPU never waits for display
- CPU can prepare next frame while GPU renders current

**Swapchain vs Present:**

**Swapchain** = the image pool:
```odin
vk.CreateSwapchainKHR(...)  // Creates pool of 2-3 images
vk.GetSwapchainImagesKHR(...)  // Get the images
// Swapchain OWNS the images
```

**Present** = show an image:
```odin
// 1. Borrow image from pool
vk.AcquireNextImageKHR(..., &image_index)

// 2. Render to it
render_to(image_index)

// 3. Return to pool + display
vk.QueuePresentKHR(..., image_index)
```

**The flow:**
- AcquireNextImage: "Borrow Image 1 from pool"
- Render: "Draw to Image 1"
- Present: "Return Image 1 to pool, show it on screen"
- Next frame: "Borrow Image 2..."

**Present modes:**
- **FIFO** (vsync): Wait for vertical blank, no tearing, locked to refresh rate
- **MAILBOX** (triple buffering): Replace old queued frame, smooth, no tearing
- **IMMEDIATE**: Show ASAP, can tear, lowest latency

**Film projector analogy:**
- Swapchain = film reel with multiple frames
- Cycle through frames
- Never show a frame being drawn

**Summary:**
- Swapchain = store/pool of images (managed rotation)
- Present = operation to display an image
- Why: Prevent tearing, parallel GPU/display work
- Cycle: previous → current → next → previous (exactly as intuited)

---

## Session Summary

**Major work:**
1. Created comprehensive Vulkan learning plan
2. Split into modular lesson files (10 lessons)
3. Established milestone-driven approach
4. Clarified core Vulkan concepts through Q&A

**Concepts mastered:**
- Command buffers (write-only, no rollback)
- Logical vs physical devices (isolation per app)
- Semaphores vs fences (GPU-GPU vs CPU-GPU sync)
- Command recording vs execution (render farm analogy)
- Swapchain architecture (image rotation for tear-free rendering)
- Why BSODs were GPU-related (kernel-mode drivers)
- Modern graphics API safety (validation, isolation, TDR)

**Mental models established:**
- Vulkan = render farm job submission (async, dependency-based)
- Logical device = database connection (isolated sessions)
- Swapchain = film projector reel (frame rotation)
- Semaphores = relay race batons (GPU-to-GPU handoff)
- Fences = notification bells (GPU-to-CPU signal)

**Learning approach validated:**
- Casey Muratori style (explain what's happening, no hand-holding)
- First principles understanding (hardware to abstraction)
- Milestone verification (console output, validation silence, visual confirmation)
- No moving forward until concepts are clear

**Next session:** Begin implementation with Lesson 1 (Instance + Debug Messenger).

---

## Quiz Results: Concept Validation

Took quiz to validate understanding of core Vulkan concepts.

**Results: 6/6 (Perfect)**

### Quiz Questions & Answers:

**Q1: Synchronization - Do sequential QueueSubmits to different queues wait for each other?**
- Answer: B - No, they run in parallel on different GPU queues
- Rationale: Different queues execute simultaneously unless explicit semaphore dependency

**Q2: Command Buffers - Has anything been drawn after EndCommandBuffer?**
- Answer: B - Commands are recorded but nothing has been drawn
- Rationale: Recording ≠ execution. Nothing happens until QueueSubmit

**Q3: Logical Devices - How many logical devices for 3 apps on 1 GPU?**
- Answer: B - 3 (one per application)
- Rationale: Each app creates isolated logical device, 1:1 relationship

**Q4: Swapchain - Which image returned on second AcquireNextImage?**
- Answer: C - Image 2 (next in rotation)
- Rationale: Round-robin cycle through swapchain images (0→1→2→0...)

**Q5: Queue Families - Can graphics command buffer submit to compute queue?**
- Answer: C - No, command buffers must match queue family
- Rationale: Command pool tied to queue family, buffers can only submit to matching family

**Q6: Fences vs Semaphores - Who waits on semaphore vs fence?**
- Answer: B - GPU waits on semaphore, CPU gets notified by fence
- Rationale: Semaphores = GPU↔GPU, Fences = GPU→CPU

**Understanding validated:**
- ✓ Async parallel execution
- ✓ Command recording vs execution separation
- ✓ Logical device isolation
- ✓ Swapchain image rotation
- ✓ Queue family constraints
- ✓ Synchronization primitive distinctions

**Concepts are solid. Ready for implementation.**

---

## Environment Setup

**Nix flake updated with Vulkan packages:**
- vulkan-headers
- vulkan-loader
- vulkan-validation-layers
- shaderc (GLSL → SPIR-V compiler)

**Development environment ready.**

---

## Session End Summary

**Time spent:** Extended session (conceptual foundation building)

**Accomplishments:**
- Created complete Vulkan learning plan (main + 10 lesson files)
- Established milestone-driven learning approach
- Clarified all major Vulkan concepts through Q&A
- Validated understanding with quiz (perfect score)
- Updated development environment

**Mental models internalized:**
- Vulkan pipeline architecture (11-stage mandatory flow)
- Async command submission (render farm analogy)
- Synchronization primitives (semaphores, fences, barriers)
- Resource isolation (logical devices)
- Image management (swapchain rotation)
- Queue system (families, queues, command buffers)

**Mindset shift achieved:**
- From "get it working" to "understand what's happening"
- From abstraction-first to hardware-first thinking
- From immediate mode to async pipeline thinking
- From trust-the-driver to explicit-validation thinking

**Ready for implementation:**
- Plan created ✓
- Concepts understood ✓
- Environment configured ✓
- Mental models solid ✓

**Next session:** Begin Lesson 1 implementation (Instance + Debug Messenger).

**Status:** Foundation complete. Moving to hands-on implementation.
