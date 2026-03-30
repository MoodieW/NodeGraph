# Lesson 5: Render Pass + Framebuffers

**Milestone**: Render pass created, framebuffers created.

---

## What You're Building

1. Render pass (describes rendering structure)
2. Framebuffers (attachments for each swapchain image)

---

## Concepts

- **Render pass**: Template for rendering operations
- **Attachments**: Images to render to (color, depth, etc.)
- **Subpasses**: Stages of rendering within a pass
- **Framebuffer**: Actual images bound to attachment points

**Why it matters**: You can't render without a render pass. It tells Vulkan what images you're rendering to and how.

---

## Code

```odin
g_render_pass: vk.RenderPass
g_framebuffers: []vk.Framebuffer

create_render_pass :: proc() -> bool {
    // Color attachment (swapchain image)
    color_attachment := vk.AttachmentDescription{
        format = g_swapchain_format,
        samples = {._1},
        loadOp = vk.AttachmentLoadOp.CLEAR,  // Clear before rendering
        storeOp = vk.AttachmentStoreOp.STORE,  // Store result
        stencilLoadOp = vk.AttachmentLoadOp.DONT_CARE,
        stencilStoreOp = vk.AttachmentStoreOp.DONT_CARE,
        initialLayout = vk.ImageLayout.UNDEFINED,
        finalLayout = vk.ImageLayout.PRESENT_SRC_KHR,
    }

    // Attachment reference
    color_attachment_ref := vk.AttachmentReference{
        attachment = 0,
        layout = .COLOR_ATTACHMENT_OPTIMAL,
    }

    // Subpass
    subpass := vk.SubpassDescription{
        pipelineBindPoint = .GRAPHICS,
        colorAttachmentCount = 1,
        pColorAttachments = &color_attachment_ref,
    }

    // Subpass dependency (for image layout transitions)
    dependency := vk.SubpassDependency{
        srcSubpass = vk.SUBPASS_EXTERNAL,
        dstSubpass = 0,
        srcStageMask = {.COLOR_ATTACHMENT_OUTPUT},
        srcAccessMask = {},
        dstStageMask = {.COLOR_ATTACHMENT_OUTPUT},
        dstAccessMask = {.COLOR_ATTACHMENT_WRITE},
    }

    // Create render pass
    render_pass_info := vk.RenderPassCreateInfo{
        sType = vk.StructureType.RENDER_PASS_CREATE_INFO,
        attachmentCount = 1,
        pAttachments = &color_attachment,
        subpassCount = 1,
        pSubpasses = &subpass,
        dependencyCount = 1,
        pDependencies = &dependency,
    }

    result := vk.CreateRenderPass(g_device, &render_pass_info, nil, &g_render_pass)
    if result != vk.Result.SUCCESS {
        fmt.eprintfln("Failed to create render pass: %v", result)
        return false
    }

    fmt.println("✓ Render pass created")
    return true
}

create_framebuffers :: proc() -> bool {
    g_framebuffers = make([]vk.Framebuffer, len(g_swapchain_image_views))

    for view, i in g_swapchain_image_views {
        attachments := [1]vk.ImageView{view}

        framebuffer_info := vk.FramebufferCreateInfo{
            sType = vk.StructureType.FRAMEBUFFER_CREATE_INFO,
            renderPass = g_render_pass,
            attachmentCount = 1,
            pAttachments = &attachments[0],
            width = g_swapchain_extent.width,
            height = g_swapchain_extent.height,
            layers = 1,
        }

        result := vk.CreateFramebuffer(g_device, &framebuffer_info, nil, &g_framebuffers[i])
        if result != vk.Result.SUCCESS {
            fmt.eprintfln("Failed to create framebuffer %d: %v", i, result)
            return false
        }
    }

    fmt.printfln("✓ Created %d framebuffers", len(g_framebuffers))
    return true
}
```

---

## Update Cleanup

```odin
cleanup_swapchain :: proc() {
    for fb in g_framebuffers {
        vk.DestroyFramebuffer(g_device, fb, nil)
    }
    delete(g_framebuffers)

    for view in g_swapchain_image_views {
        vk.DestroyImageView(g_device, view, nil)
    }
    delete(g_swapchain_image_views)

    vk.DestroySwapchainKHR(g_device, g_swapchain, nil)
    delete(g_swapchain_images)
}

cleanup_vulkan :: proc() {
    cleanup_swapchain()
    vk.DestroyRenderPass(g_device, g_render_pass, nil)
    vk.DestroyDevice(g_device, nil)
    vk.DestroySurfaceKHR(g_instance, g_surface, nil)
    vk.DestroyDebugUtilsMessengerEXT(g_instance, g_debug_messenger, nil)
    vk.DestroyInstance(g_instance, nil)
}
```

---

## Update Init

```odin
init_vulkan :: proc() -> bool {
    if !create_instance() do return false
    if !create_debug_messenger() do return false
    if !create_surface() do return false
    if !pick_physical_device() do return false
    if !create_logical_device() do return false
    if !create_swapchain() do return false
    if !create_image_views() do return false
    if !create_render_pass() do return false
    if !create_framebuffers() do return false
    return true
}
```

---

## Milestone Check

- [ ] Console prints "✓ Render pass created"
- [ ] Console prints framebuffer count
- [ ] No validation errors

---

## What You Learned

- Render pass creation
- Attachment descriptions
- Subpasses and dependencies
- Framebuffer creation
