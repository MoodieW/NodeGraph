# Lesson 0: Vulkan Mental Model

**Goal**: Understand Vulkan's architecture before writing code.

---

## 0.1: The Vulkan Pipeline Overview

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

---

## 0.2: Memory Model

Vulkan has multiple memory heaps and types. You must:

1. **Query available memory types** (VRAM, RAM, cached, etc.)
2. **Allocate memory** from appropriate heap
3. **Bind memory** to resources (buffers, images)
4. **Map/unmap** for CPU access if needed
5. **Free memory** when done

**No automatic memory management.** You allocate, you free.

---

## 0.3: Command Recording vs Execution

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

---

## 0.4: Synchronization Primitives

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

---

## 0.5: Validation Layers

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

---

## Checklist for Lesson 0:
- [x] Understand Vulkan's multi-stage setup
- [x] Know difference between physical/logical device
- [x] Understand command recording vs execution
- [x] Know when to use fences vs semaphores
- [x] Understand validation layers purpose

**Lesson 0 Complete! ✓**
