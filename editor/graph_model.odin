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
	id:       u32,
	type:     Node_Type,
	position: [2]f32,
	inputs:   [dynamic]Socket,
	outputs:  [dynamic]Socket,
	data:     Node_Data,
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
	type: Socket_Type,
}

Socket_Type :: enum {
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

create_node :: proc(g: ^Graph, type: Node_Type, allocator := context.allocator) -> u32 {
	node := new(Node, allocator)

	node.id = g.next_id
	g.next_id += 1
	node.type = type
	switch type {
	case .Float:
		append(&node.outputs, Socket{"Value", .Float})
		node.data = Constant_Data {
			value = {0.5, 0, 0, 0},
			len   = 1,
		}
	case .Add:
		append(&node.inputs, Socket{"A", .Float})
		append(&node.inputs, Socket{"B", .Float})
		append(&node.outputs, Socket{"Value", .Float})
	case .Preview:
		append(&node.inputs, Socket{"Color", .Float4})
	case .Surface:
		append(&node.inputs, Socket{"Color", .Float4})
	}

	g.nodes[node.id] = node
	return node.id
}

connect :: proc(g: ^Graph, from_node: u32, from_socket: int, to_node: u32, to_socket: int) {
	append(&g.connections, Connection{from_node, from_socket, to_node, to_socket})
}

// =============================================================================
// Helpers
// =============================================================================

// Returns the Slang type name for a socket type e.g. .Float4 -> "float4"
_socket_type_to_lower :: proc(st: Socket_Type) -> string {
	return strings.to_lower(fmt.tprintf("%v", st))
}

// Returns the generated output variable name for a node e.g. node_2_output
_slang_var_name_out :: proc(id: u32) -> string {
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
		results[i] = _slang_var_name_out(g.nodes[input_order_map[i].from_node].id)
	}
	return results
}

// Returns the Slang code line for a single node.
// is_signature: emits the function header
// is_return:    emits the return statement and closing brace
get_node_codegen :: proc(
	g: ^Graph,
	node_id: u32,
	is_return := false,
	is_signature := false,
) -> string {
	current_node := g.nodes[node_id]
	out_st := current_node.outputs
	if is_signature {
		out := _socket_type_to_lower(out_st[0].type)
		return fmt.tprintf(
			"[shader(\"fragment\")]\n%s %sFragmentMain() {{\n",
			out,
			_slang_var_name_out(current_node.id),
		)
	}
	if is_return {
		return fmt.tprintf("return %s;\n}}", _slang_var_name_out(current_node.id))
	}
	inputs := get_inputs(g, node_id)
	defer delete(inputs)
	#partial switch current_node.type {
	case .Float:
		out := _socket_type_to_lower(out_st[0].type)
		value := _get_constant_value(current_node.data.(Constant_Data))
		return fmt.tprintf("%s %s = %v; ", out, _slang_var_name_out(current_node.id), value)
	case .Add:
		out := _socket_type_to_lower(out_st[0].type)
		output_name := _slang_var_name_out(current_node.id)
		return fmt.tprintf("%s %s = add(%s, %s);", out, output_name, inputs[0], inputs[1])
	}
	return ""
}

// Walks the sorted node list up to stop_node_id and emits a complete Slang
// fragment shader function. Returned string is owned by the caller.
eval_build :: proc(g: ^Graph, sorted: ^[dynamic]u32, stop_node_id: u32) -> string {
	orginal_alloc := context.allocator
	arena: mem.Arena
	backing := make([]byte, 1024 * 4)
	mem.arena_init(&arena, backing)
	defer delete(backing)
	context.allocator = mem.arena_allocator(&arena)

	rs := strings.builder_make()
	defer strings.builder_destroy(&rs)
	strings.write_string(&rs, get_node_codegen(g, stop_node_id, is_signature = true))
	for node_id in sorted^ {
		strings.write_string(&rs, fmt.tprintfln("\t%s", get_node_codegen(g, node_id)))
		if stop_node_id == node_id {
			break
		}
	}
	strings.write_string(&rs, fmt.tprintf("\t%s\n", get_node_codegen(g, stop_node_id, true)))
	return strings.clone(strings.to_string(rs), allocator = orginal_alloc)
}

// Topologically sorts the graph. Returns sorted node IDs and any cycled nodes.
// Caller owns both returned dynamic arrays.
eval_order :: proc(g: ^Graph) -> (sorted: [dynamic]u32, cycled: [dynamic]u32) {
	sorter: topological_sort.Sorter(u32)
	topological_sort.init(&sorter)
	defer topological_sort.destroy(&sorter)

	for id in g.nodes {
		topological_sort.add_key(&sorter, id)
	}
	for conn in g.connections {
		topological_sort.add_dependency(&sorter, conn.to_node, conn.from_node)
	}

	sorted, cycled = topological_sort.sort(&sorter)
	return sorted, cycled
}

// =============================================================================
// Test
// =============================================================================

build_test_graph :: proc() -> Graph {
	graph := Graph{}

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

	sorted, cycled := eval_order(&graph)
	defer delete(sorted)
	defer delete(cycled)

	if len(cycled) > 0 {
		fmt.println("cycle detected!")
	}
	val := eval_build(&graph, &sorted, 2)
	fmt.println(val)
	return graph
}

main :: proc() {
	build_test_graph()
}

