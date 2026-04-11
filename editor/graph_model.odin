package main

import "core:container/topological_sort"
import "core:fmt"

Graph :: struct {
	nodes:       map[u32]^Node,
	connections: [dynamic]Connection,
	next_id:     u32,
}

Node_Type :: enum {
	Float,
	Add,
	Preview,
	Surface,
}

Socket :: struct {
	name: string,
	type: Socket_Type,
}


Socket_Type :: enum {
	Float,
	Vector2,
	Vector3,
	Vector4,
	Texture,
}

Node :: struct {
	id:       u32,
	type:     Node_Type,
	position: [2]f32,
	inputs:   [dynamic]Socket,
	outputs:  [dynamic]Socket,
	data:     union {
		Constant_Data,
		Slider_Data,
		Gradient_Data,
	},
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


Connection :: struct {
	from_node:   u32,
	from_socket: int,
	to_node:     u32,
	to_socket:   int,
}

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
		append(&node.inputs, Socket{"Color", .Vector4})
	case .Surface:
		append(&node.inputs, Socket{"Color", .Vector4})
	}

	g.nodes[node.id] = node
	return node.id
}

connect :: proc(g: ^Graph, from_node: u32, from_socket: int, to_node: u32, to_socket: int) {
	conn := Connection {
		from_node   = from_node,
		from_socket = from_socket,
		to_node     = to_node,
		to_socket   = to_socket,
	}
	append(&g.connections, conn)
}

eval_order :: proc(g: ^Graph) -> (sorted: [dynamic]u32, cycled: [dynamic]u32) {
	sorter: topological_sort.Sorter(u32)
	topological_sort.init(&sorter)
	defer topological_sort.destroy(&sorter)

	// Register all nodes
	for id in g.nodes {
		topological_sort.add_key(&sorter, id)
	}

	// Add dependencies — "to_node depends on from_node"
	for conn in g.connections {
		topological_sort.add_dependency(&sorter, conn.to_node, conn.from_node)
	}

	sorted, cycled = topological_sort.sort(&sorter)
	return sorted, cycled
}

build_test_graph :: proc() -> Graph {
	graph := Graph{}
	graph.next_id = 0

	// Create nodes
	float_a := create_node(&graph, .Float)
	float_b := create_node(&graph, .Float)
	add := create_node(&graph, .Add)
	preview := create_node(&graph, .Preview)
	output := create_node(&graph, .Surface)
	fmt.println(graph.nodes[float_a])
	// Set float values
	data_a := graph.nodes[float_a].data.(Constant_Data)
	data_a.value = 0.5
	data_b := graph.nodes[float_b].data.(Constant_Data)
	data_b.value = {0.3, 0.1, 0.1, 0.1}
	graph.nodes[float_b].data = data_b
	fmt.println(graph.nodes[float_b])

	// Connect: Float A → Add.A
	connect(&graph, float_a, 0, add, 0)

	// Connect: Float B → Add.B
	connect(&graph, float_b, 0, add, 1)

	// Connect: Add → Preview
	connect(&graph, add, 0, preview, 0)

	// Connect: Add → Surface Output
	connect(&graph, add, 0, output, 0)
	sorted, cycled := eval_order(&graph)
	defer delete(sorted)
	defer delete(cycled)

	if len(cycled) > 0 {
		fmt.println("cycle detected!")
	}
	fmt.println(sorted)
	return graph
}

