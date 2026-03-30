# Session 2026-03-29: Lesson 8 - Clearing the Screen (Completion)

**Date**: 2026-03-29
**Phase**: Phase 1 - Vulkan Bootstrap
**Lesson**: Lesson 8 - Clearing the Screen
**Status**: Complete - Moving to Lesson 9

---

## What Was Accomplished

Successfully implemented the **render loop** - the foundational infrastructure that repeatedly submits work to the GPU with proper synchronization. This is the core of Vulkan's async execution model in practice.

### Implementation Details

**1. Main Render Loop Integration** (`main.odin:1068-1072`)
- Window loop calls `draw_frame()` each iteration
- Proper integration with GLFW event handling
- DeviceWaitIdle before cleanup ensures GPU finishes all work

**2. draw_frame Function** (`main.odin:932-995`)
- Acquires next swapchain image (waits on `image_available[current_frame]`)
- Records command buffer for current frame
- Submits to graphics queue with proper synchronization:
  - **Wait**: `image_available` semaphore (image ready)
  - **Signal**: `render_finished[image_index]` semaphore (rendering done)
  - **Signal**: `in_flight_fence[current_frame]` fence (GPU work done)
- Presents swapchain image (waits on `render_finished` semaphore)
- Advances frame counter with modulo to cycle through frame-in-flight indices

**3. record_command_buffer Function** (`main.odin:890-929`)
- Begins render pass with swapchain image
- Sets clear color to blue (0.0, 0.0, 1.0, 1.0)
- Ends render pass
- Completes command buffer

**4. Synchronization Pattern** - Frame-in-Flight
- Two semaphores per frame (image available, render finished)
- One fence per frame (CPU↔GPU sync)
- **Critical insight**: Semaphore indexing
  - Acquired by `current_frame` (which frame is recording)
  - Presented by `image_index` (which swapchain image)
  - Fence waited on by `current_frame` (only safe to overwrite fence after CPU waits)

---

## Key Milestones Achieved

- **Window clears to blue** - First visible GPU output
- **No flickering** - Frame-in-flight pattern prevents tearing
- **No deadlocks** - Synchronization properly chains CPU↔GPU↔GPU
- **Proper cleanup** - DeviceWaitIdle prevents resource destruction while GPU working
- **Async execution demonstrated** - Render loop submits frames faster than GPU executes

---

## Concepts Mastered

1. **Render pass semantics** - Begins with clear, ends with image ready for present
2. **Frame-in-flight indexing** - Two different indices (`current_frame` vs `image_index`)
3. **Semaphore signaling chain**:
   - Swapchain (driver) signals `image_available` when image is acquirable
   - GPU pipeline (render pass) signals `render_finished` after rendering
   - Swapchain waits on `render_finished` before presenting
4. **Fence synchronization** - CPU waits before reusing frame resources
5. **Implicit memory barriers in render pass** - Clear operation transitions layout

---

## Current Status

- Lesson 8: Complete
- All render loop infrastructure in place
- Window actively clearing to color each frame
- GPU synchronization pattern validated

### Next: Lesson 9 - Graphics Pipeline & Triangle Rendering

The graphics pipeline is already partially implemented (shader compilation phase detected). Lesson 9 will:
- Complete graphics pipeline creation (graphics pipeline object, not just compute)
- Bind pipeline in render pass
- Define vertex input (format, binding, attributes)
- Record draw command (vk.CmdDraw)
- Render triangle to screen

---

## Notes for Next Session

- Semaphore ordering is critical - trace through submission to understand signal/wait pairs
- Current frame cycles 0→1→0→1... independently of swapchain image cycling
- This frame-in-flight pattern prevents CPU from outrunning GPU without stalling on waits
