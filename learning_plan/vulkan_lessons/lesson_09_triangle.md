# Lesson 9: Graphics Pipeline + Triangle

**Milestone**: RGB triangle rendered on screen.

---

## What You're Building

1. Shader modules (SPIR-V)
2. Graphics pipeline
3. Triangle vertex data
4. Draw command

**This is the big one. The pipeline is complex.**

---

## Step 1: Create Shaders

Create directory:
```bash
mkdir -p shaders
```

Create `shaders/triangle.slang`:
```slang
// Vertex shader entry point
[shader("vertex")]
float4 vertexMain(uint vertexID : SV_VertexID, out float3 fragColor : COLOR) : SV_Position
{
    static const float2 positions[3] = {
        float2(0.0, -0.5),
        float2(0.5, 0.5),
        float2(-0.5, 0.5)
    };

    static const float3 colors[3] = {
        float3(1.0, 0.0, 0.0),
        float3(0.0, 1.0, 0.0),
        float3(0.0, 0.0, 1.0)
    };

    fragColor = colors[vertexID];
    return float4(positions[vertexID], 0.0, 1.0);
}

// Fragment shader entry point
[shader("fragment")]
float4 fragmentMain(float3 fragColor : COLOR) : SV_Target
{
    return float4(fragColor, 1.0);
}
```

**Compile shaders**:
```bash
slangc shaders/triangle.slang -target spirv -entry vertexMain -stage vertex -o shaders/triangle.vert.spv
slangc shaders/triangle.slang -target spirv -entry fragmentMain -stage fragment -o shaders/triangle.frag.spv
```

---

## Step 2: Load and Create Shader Modules

```odin
import "core:os"

read_file :: proc(filepath: string) -> ([]byte, bool) {
    data, ok := os.read_entire_file(filepath)
    if !ok {
        fmt.eprintfln("Failed to read file: %s", filepath)
        return nil, false
    }
    return data, true
}

create_shader_module :: proc(code: []byte) -> (vk.ShaderModule, bool) {
    create_info := vk.ShaderModuleCreateInfo{
        sType = vk.StructureType.SHADER_MODULE_CREATE_INFO,
        codeSize = len(code),
        pCode = cast(^u32)raw_data(code),
    }

    shader_module: vk.ShaderModule
    result := vk.CreateShaderModule(g_device, &create_info, nil, &shader_module)
    if result != vk.Result.SUCCESS {
        fmt.eprintfln("Failed to create shader module: %v", result)
        return 0, false
    }

    return shader_module, true
}
```

---

## Step 3: Create Graphics Pipeline

```odin
g_pipeline_layout: vk.PipelineLayout
g_graphics_pipeline: vk.Pipeline

create_graphics_pipeline :: proc() -> bool {
    // Load shader code
    vert_code, vert_ok := read_file("shaders/triangle.vert.spv")
    if !vert_ok do return false
    defer delete(vert_code)

    frag_code, frag_ok := read_file("shaders/triangle.frag.spv")
    if !frag_ok do return false
    defer delete(frag_code)

    // Create shader modules
    vert_module, vert_module_ok := create_shader_module(vert_code)
    if !vert_module_ok do return false
    defer vk.DestroyShaderModule(g_device, vert_module, nil)

    frag_module, frag_module_ok := create_shader_module(frag_code)
    if !frag_module_ok do return false
    defer vk.DestroyShaderModule(g_device, frag_module, nil)

    // Shader stages
    vert_stage := vk.PipelineShaderStageCreateInfo{
        sType = vk.StructureType.PIPELINE_SHADER_STAGE_CREATE_INFO,
        stage = {.VERTEX},
        module = vert_module,
        pName = "main",
    }

    frag_stage := vk.PipelineShaderStageCreateInfo{
        sType = vk.StructureType.PIPELINE_SHADER_STAGE_CREATE_INFO,
        stage = {.FRAGMENT},
        module = frag_module,
        pName = "main",
    }

    shader_stages := [2]vk.PipelineShaderStageCreateInfo{vert_stage, frag_stage}

    // Vertex input (none - hardcoded in shader)
    vertex_input_info := vk.PipelineVertexInputStateCreateInfo{
        sType = vk.StructureType.PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        vertexBindingDescriptionCount = 0,
        vertexAttributeDescriptionCount = 0,
    }

    // Input assembly
    input_assembly := vk.PipelineInputAssemblyStateCreateInfo{
        sType = vk.StructureType.PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        topology = .TRIANGLE_LIST,
        primitiveRestartEnable = false,
    }

    // Viewport and scissor
    viewport := vk.Viewport{
        x = 0.0,
        y = 0.0,
        width = f32(g_swapchain_extent.width),
        height = f32(g_swapchain_extent.height),
        minDepth = 0.0,
        maxDepth = 1.0,
    }

    scissor := vk.Rect2D{
        offset = {0, 0},
        extent = g_swapchain_extent,
    }

    viewport_state := vk.PipelineViewportStateCreateInfo{
        sType = vk.StructureType.PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        viewportCount = 1,
        pViewports = &viewport,
        scissorCount = 1,
        pScissors = &scissor,
    }

    // Rasterizer
    rasterizer := vk.PipelineRasterizationStateCreateInfo{
        sType = vk.StructureType.PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        depthClampEnable = false,
        rasterizerDiscardEnable = false,
        polygonMode = .FILL,
        lineWidth = 1.0,
        cullMode = {.BACK},
        frontFace = .CLOCKWISE,
        depthBiasEnable = false,
    }

    // Multisampling (disabled)
    multisampling := vk.PipelineMultisampleStateCreateInfo{
        sType = vk.StructureType.PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        sampleShadingEnable = false,
        rasterizationSamples = {._1},
    }

    // Color blending
    color_blend_attachment := vk.PipelineColorBlendAttachmentState{
        colorWriteMask = {.R, .G, .B, .A},
        blendEnable = false,
    }

    color_blending := vk.PipelineColorBlendStateCreateInfo{
        sType = vk.StructureType.PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        logicOpEnable = false,
        logicOp = .COPY,
        attachmentCount = 1,
        pAttachments = &color_blend_attachment,
    }

    // Pipeline layout
    layout_info := vk.PipelineLayoutCreateInfo{
        sType = vk.StructureType.PIPELINE_LAYOUT_CREATE_INFO,
    }

    if vk.CreatePipelineLayout(g_device, &layout_info, nil, &g_pipeline_layout) != .SUCCESS {
        fmt.eprintln("Failed to create pipeline layout")
        return false
    }

    // Create graphics pipeline
    pipeline_info := vk.GraphicsPipelineCreateInfo{
        sType = vk.StructureType.GRAPHICS_PIPELINE_CREATE_INFO,
        stageCount = 2,
        pStages = &shader_stages[0],
        pVertexInputState = &vertex_input_info,
        pInputAssemblyState = &input_assembly,
        pViewportState = &viewport_state,
        pRasterizationState = &rasterizer,
        pMultisampleState = &multisampling,
        pColorBlendState = &color_blending,
        layout = g_pipeline_layout,
        renderPass = g_render_pass,
        subpass = 0,
    }

    result := vk.CreateGraphicsPipelines(g_device, 0, 1, &pipeline_info, nil, &g_graphics_pipeline)
    if result != vk.Result.SUCCESS {
        fmt.eprintfln("Failed to create graphics pipeline: %v", result)
        return false
    }

    fmt.println("✓ Graphics pipeline created")
    return true
}
```

---

## Step 4: Update Command Recording

```odin
record_command_buffer :: proc(command_buffer: vk.CommandBuffer, image_index: u32) {
    begin_info := vk.CommandBufferBeginInfo{
        sType = vk.StructureType.COMMAND_BUFFER_BEGIN_INFO,
    }

    if vk.BeginCommandBuffer(command_buffer, &begin_info) != .SUCCESS {
        fmt.eprintln("Failed to begin command buffer")
        return
    }

    clear_color := vk.ClearValue{
        color = {float32 = {0.0, 0.0, 0.5, 1.0}},
    }

    render_pass_info := vk.RenderPassBeginInfo{
        sType = vk.StructureType.RENDER_PASS_BEGIN_INFO,
        renderPass = g_render_pass,
        framebuffer = g_framebuffers[image_index],
        renderArea = {
            offset = {0, 0},
            extent = g_swapchain_extent,
        },
        clearValueCount = 1,
        pClearValues = &clear_color,
    }

    vk.CmdBeginRenderPass(command_buffer, &render_pass_info, .INLINE)

    // Bind pipeline
    vk.CmdBindPipeline(command_buffer, .GRAPHICS, g_graphics_pipeline)

    // Draw triangle
    vk.CmdDraw(command_buffer, 3, 1, 0, 0)

    vk.CmdEndRenderPass(command_buffer)

    if vk.EndCommandBuffer(command_buffer) != .SUCCESS {
        fmt.eprintln("Failed to end command buffer")
    }
}
```

---

## Step 5: Update Init/Cleanup

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
    if !create_graphics_pipeline() do return false  // NEW
    if !create_framebuffers() do return false
    if !create_command_pool() do return false
    if !create_command_buffers() do return false
    if !create_sync_objects() do return false
    return true
}

cleanup_vulkan :: proc() {
    for i in 0..<MAX_FRAMES_IN_FLIGHT {
        vk.DestroySemaphore(g_device, g_image_available_semaphores[i], nil)
        vk.DestroySemaphore(g_device, g_render_finished_semaphores[i], nil)
        vk.DestroyFence(g_device, g_in_flight_fences[i], nil)
    }

    vk.DestroyCommandPool(g_device, g_command_pool, nil)
    delete(g_command_buffers)

    vk.DestroyPipeline(g_device, g_graphics_pipeline, nil)  // NEW
    vk.DestroyPipelineLayout(g_device, g_pipeline_layout, nil)  // NEW

    cleanup_swapchain()
    vk.DestroyRenderPass(g_device, g_render_pass, nil)
    vk.DestroyDevice(g_device, nil)
    vk.DestroySurfaceKHR(g_instance, g_surface, nil)
    vk.DestroyDebugUtilsMessengerEXT(g_instance, g_debug_messenger, nil)
    vk.DestroyInstance(g_instance, nil)
}
```

---

## Milestone Check

- [ ] RGB-colored triangle renders on blue background
- [ ] Triangle is visible and correctly colored
- [ ] No validation errors
- [ ] Shaders compiled successfully

---

## What You Learned

- Slang shader language basics
- Shader compilation to SPIR-V (Slang → SPIR-V)
- Shader module creation
- Graphics pipeline creation (all the stages!)
- Pipeline state configuration
- Draw commands

---

## The Infamous Triangle

You did it. Over 1000 lines of code to draw a triangle.

But now you understand:
- Instance creation
- Device selection
- Swapchain setup
- Render passes
- Command buffers
- Synchronization
- Pipeline state
- Shader modules
- Command recording
- Queue submission
- Presentation

**You understand how Vulkan works.**

Everything from here builds on this foundation.
