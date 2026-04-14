package main

import "core:container/topological_sort"
import "core:fmt"
import "core:mem"
import "core:strings"

// =============================================================================
// Data Types
// =============================================================================

Graph :: struct {
	nodes:       map[u32]^Node,
	connections: [dynamic]Connection,
	next_id:     u32,
}

Node :: struct {
	id:          u32,
	category:    Node_Category,
	type:        Node_Type,
	position:    [2]f32,
	inputs:      [dynamic]Socket,
	outputs:     [dynamic]Socket,
	data:        Node_Data,
	return_type: Data_Type,
}

Node_Category :: enum {
	Input, // Leaf nodes (constants, inputs)
	Operation, // Computation (add, multiply, etc.)
	Output, // Final shader outputs
}

Node_Type :: enum {
	Float,
	Add,
	Preview,
	Surface,
}

Node_Data :: union {
	Constant_Data,
	Slider_Data,
	Gradient_Data,
}

Constant_Data :: struct {
	value: [4]f32,
	len:   int,
}

Slider_Data :: struct {
	value: f32,
	min:   f32,
	max:   f32,
}

Gradient_Data :: struct {
	points: [dynamic]Gradient_Stop,
}

Gradient_Stop :: struct {
	pos:   f32,
	color: [4]f32,
}

Socket :: struct {
	name: string,
	type: Data_Type,
}

Data_Type :: enum {
	Float,
	Float2,
	Float3,
	Float4,
	Texture2D,
	SamplerState,
	Float2x2,
	Float3x3,
	Float4x4,
}

Connection :: struct {
	from_node:   u32,
	from_socket: int,
	to_node:     u32,
	to_socket:   int,
}

// =============================================================================
// Graph Construction
// =============================================================================

create_node :: proc(g: ^Graph, type: Node_Type) -> u32 {
	node := new(Node)

	node.id = g.next_id
	g.next_id += 1
	node.type = type
	switch type {
	case .Float:
		setup_float_node(node)
	case .Add:
		setup_add_node(node)
	case .Preview:
		setup_preview_node(node)
	case .Surface:
		setup_surface_node(node)
	}
	g.nodes[node.id] = node
	return node.id
}

connect :: proc(g: ^Graph, from_node: u32, from_socket: int, to_node: u32, to_socket: int) {
	append(&g.connections, Connection{from_node, from_socket, to_node, to_socket})
}

remove_graph :: proc(g: ^Graph) {
	for id in g.nodes {
		node := g.nodes[id]
		delete(node.inputs)
		delete(node.outputs)
		// Handle node.data if it has dynamics (Gradient_Data.points)
		free(node)
	}
	delete(g.nodes)
	delete(g.connections)
}

// =============================================================================
// Node Builders
// =============================================================================

setup_float_node :: proc(node: ^Node) {
	node.category = .Input
	node.return_type = .Float
	append(&node.outputs, Socket{"Value", .Float})
	node.data = Constant_Data {
		value = {0.5, 0, 0, 0},
		len   = 1,
	}
}

setup_add_node :: proc(node: ^Node) {
	node.category = .Operation
	node.return_type = .Float
	append(&node.inputs, Socket{"A", .Float})
	append(&node.inputs, Socket{"B", .Float})
	append(&node.outputs, Socket{"Value", .Float})
}

setup_surface_node :: proc(node: ^Node) {
	node.category = .Output
	node.return_type = .Float4
	append(&node.inputs, Socket{"Color", .Float4})
}

setup_preview_node :: proc(node: ^Node) {
	node.category = .Output
	node.return_type = .Float4
	append(&node.inputs, Socket{"Color", .Float4})
}


// =============================================================================
// Helpers
// =============================================================================

// Returns the Slang type name for a socket type e.g. .Float4 -> "float4"
_data_type_to_lower :: proc(st: Data_Type) -> string {
	return strings.to_lower(fmt.tprintf("%v", st))
}

// Returns the generated output variable name for a node e.g. node_2_output
_node_name_out :: proc(id: u32) -> string {
	return fmt.tprintf("node_%d_output", id)
}

// Extracts the active components from a Constant_Data value based on its len
_get_constant_value :: proc(v: Constant_Data) -> union {
		f32,
		[2]f32,
		[3]f32,
		[4]f32,
	} {
	switch v.len {
	case 1:
		return v.value.r
	case 2:
		return v.value.rg
	case 3:
		return v.value.rgb
	case:
		return v.value.rgba
	}
}

// =============================================================================
// Code Generation
// =============================================================================


// Returns the output variable names of all nodes connected to node_id's inputs,
// ordered by socket index. Caller owns the returned slice.
get_inputs :: proc(g: ^Graph, node_id: u32) -> []string {
	input_count := len(g.nodes[node_id].inputs)
	results := make([]string, input_count)
	input_order_map := make(map[int]Connection)
	defer delete(input_order_map)
	for conn in g.connections {
		if conn.to_node != node_id {
			continue
		}
		input_order_map[conn.to_socket] = conn
	}
	for i in 0 ..< input_count {
		results[i] = _node_name_out(g.nodes[input_order_map[i].from_node].id)
	}
	return results
}


eval_build :: proc(g: ^Graph, sorted: ^[dynamic]u32) -> string {
	orginal_allacator := context.allocator
	arena: mem.Arena
	arena_mem := make([]byte, 1 * mem.Megabyte)
	defer delete(arena_mem)
	mem.arena_init(&arena, arena_mem)
	arena_alloc := mem.arena_allocator(&arena)
	context.allocator = arena_alloc

	target_node_id := sorted[len(sorted) - 1]
	target_node := g.nodes[target_node_id]

	push_constant_code := strings.builder_make()
	defer strings.builder_destroy(&push_constant_code)
	strings.write_string(&push_constant_code, "struct PushConstants {")

	main_func_code := strings.builder_make()
	defer strings.builder_destroy(&main_func_code)
	strings.write_string(&main_func_code, "[shader(\"fragment\")]\n")
	strings.write_string(
		&main_func_code,
		fmt.tprintf(
			"%s %sFragmentMain(){{",
			_data_type_to_lower(target_node.return_type),
			_node_name_out(target_node_id),
		),
	)

	for nid in sorted {
		node := g.nodes[nid]

		switch node.category {
		case .Input:
			push_c, main_c := eval_input_node(node)
			strings.write_string(&push_constant_code, push_c)
			strings.write_string(&main_func_code, main_c)
		case .Operation:
			main_c := eval_operation_node(g, node)
			strings.write_string(&main_func_code, main_c)
		case .Output:
			main_c := eval_output_node(g, node)
			strings.write_string(&main_func_code, main_c)
		}
	}

	close_push_const := fmt.tprintf(
		"\n}};\n\n[[vk::push_constant]]\ncbuffer pc : PushConstants;\n",
	)
	strings.write_string(&push_constant_code, close_push_const)
	main_close := fmt.tprintf("\n\treturn %s;\n}", _node_name_out(target_node_id))
	strings.write_string(&main_func_code, main_close)

	context.allocator = orginal_allacator
	return strings.concatenate(
		{strings.to_string(push_constant_code), "\n", strings.to_string(main_func_code)},
		allocator = context.allocator,
	)
}

eval_input_node :: proc(node: ^Node) -> (push_constant_code: string, main_func_code: string) {
	output_var := _node_name_out(node.id)
	dt := _data_type_to_lower(node.return_type)
	push_constant_code = fmt.tprintf("\n\t%s %s;", dt, output_var)

	// Read from push constant in main
	main_func_code = fmt.tprintf("\n\t%s %s = pc.%s;", dt, output_var, output_var)
	return push_constant_code, main_func_code
}

eval_operation_node :: proc(g: ^Graph, node: ^Node) -> (main_func_code: string) {
	inputs := get_inputs(g, node.id)
	node_type := node.type
	dt := _data_type_to_lower(node.return_type)
	#partial switch node_type {
	case .Add:
		input_a := inputs[0]
		input_b := inputs[1]
		output := _node_name_out(node.id)
		return fmt.tprintf("\n\t%s %s = add(%s, %s);", dt, output, input_a, input_b)

	}
	return ""
}

eval_output_node :: proc(g: ^Graph, node: ^Node) -> (main_func_code: string) {
	return ""
}


collect_deps :: proc(g: ^Graph, node_id: u32, node_map: ^map[u32]bool) {
	// Already visited, avoid infinite recursion
	if node_map[node_id] do return

	// Mark this node as needed
	node_map[node_id] = true

	// Find connections coming INTO this node
	for conn in g.connections {
		if conn.to_node == node_id {
			collect_deps(g, conn.from_node, node_map)
		}
	}
}
// Topologically sorts the graph. Returns sorted node IDs and any cycled nodes.
// Caller owns both returned dynamic arrays.
eval_order :: proc(g: ^Graph, eval_node: u32) -> (sorted: [dynamic]u32, cycled: [dynamic]u32) {
	// Collect nodes that feed into stop_node_id
	needed_nodes := make(map[u32]bool)
	defer delete(needed_nodes)

	collect_deps(g, eval_node, &needed_nodes)
	sorter: topological_sort.Sorter(u32)
	topological_sort.init(&sorter)
	defer topological_sort.destroy(&sorter)

	for id in needed_nodes {
		topological_sort.add_key(&sorter, id)
	}
	for conn in g.connections {
		if needed_nodes[conn.from_node] && needed_nodes[conn.to_node] {
			topological_sort.add_dependency(&sorter, conn.to_node, conn.from_node)}
	}

	sorted, cycled = topological_sort.sort(&sorter)
	return sorted, cycled
}

// =============================================================================
// Test
// =============================================================================

build_test_graph :: proc() {
	default_all := context.allocator
	track_alloc: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track_alloc, default_all)
	context.allocator = mem.tracking_allocator(&track_alloc)
	restet_t_alloc :: proc(a: ^mem.Tracking_Allocator) -> bool {
		err := false
		for _, value in a.allocation_map {
			fmt.printf("%v: Leaked %v bytes\n", value.location, value.size)
			err = true
		}
		mem.tracking_allocator_clear(a)
		return err
	}
	defer restet_t_alloc(&track_alloc)
	graph := Graph{}
	defer remove_graph(&graph)

	float_a := create_node(&graph, .Float)
	float_b := create_node(&graph, .Float)
	add := create_node(&graph, .Add)
	preview := create_node(&graph, .Preview)
	output := create_node(&graph, .Surface)

	data_b := graph.nodes[float_b].data.(Constant_Data)
	data_b.value = {0.3, 0.1, 0.1, 0.1}
	graph.nodes[float_b].data = data_b

	connect(&graph, float_a, 0, add, 0)
	connect(&graph, float_b, 0, add, 1)
	connect(&graph, add, 0, preview, 0)
	connect(&graph, add, 0, output, 0)

	sorted, cycled := eval_order(&graph, 2)
	defer delete(sorted)
	defer delete(cycled)

	if len(cycled) > 0 {
		fmt.println("cycle detected!")
	}
	val := eval_build(&graph, &sorted)

	fmt.println(val)
	delete(val)
}

main :: proc() {
	build_test_graph()
}

