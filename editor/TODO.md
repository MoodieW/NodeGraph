# graph_model.odin - Outstanding Issues

## Bugs / Correctness

- `build_test_graph` hardcodes `stop_node_id = 2` — should walk connections to find
  the terminal node (Surface) dynamically instead of a magic number

- `strings.builder_destroy(&rs)` inside `eval_build` is a no-op since `context.allocator`
  is the arena at that point (arenas don't support `.Free`). Harmless but misleading —
  consider removing it or destroying after restoring the allocator

## Missing Features

- `get_node_codegen` has no cases for `.Preview` and `.Surface` — these need to emit
  float expansion code (e.g. `float4(val, val, val, 1.0)`) and a return statement

- Shader stage is hardcoded as `"fragment"` in the signature — needs to be a parameter
  to support vertex and other stages

- No `graph_destroy` proc — nodes (`^Node`), their internal dynamic arrays (`inputs`,
  `outputs`), and the graph's `connections` and `nodes` map all leak

## Code Quality

- `get_node_codegen` uses two bool flags (`is_return`, `is_signature`) which is fragile —
  consider replacing with an enum (`Normal`, `Signature`, `Return`)

- Debug prefix in function name (`%sFragmentMain` using var name) should be cleaned up
  once no longer needed
