package primitives

CUBE_VERTICES := [24]Vertex {
	//front face
	{position = {-0.5, -0.5, 0.5}, normal = {0.0, 0.0, 1.0}, color = {1.0, 0.0, 0.0}},
	{position = {0.5, -0.5, 0.5}, normal = {0.0, 0.0, 1.0}, color = {1.0, 0.0, 0.0}},
	{position = {0.5, 0.5, 0.5}, normal = {0.0, 0.0, 1.0}, color = {1.0, 0.0, 0.0}},
	{position = {-0.5, 0.5, 0.5}, normal = {0.0, 0.0, 1.0}, color = {1.0, 0.0, 0.0}},
	// back face
	{position = {0.5, -0.5, -0.5}, normal = {0.0, 0.0, -1.0}, color = {0.0, 1.0, 0.0}},
	{position = {-0.5, -0.5, -0.5}, normal = {0.0, 0.0, -1.0}, color = {0.0, 1.0, 0.0}},
	{position = {-0.5, 0.5, -0.5}, normal = {0.0, 0.0, -1.0}, color = {0.0, 1.0, 0.0}},
	{position = {0.5, 0.5, -0.5}, normal = {0.0, 0.0, -1.0}, color = {0.0, 1.0, 0.0}},
	// right face
	{position = {0.5, -0.5, 0.5}, normal = {1.0, 0.0, 0.0}, color = {0.0, 0.0, 1.0}},
	{position = {0.5, -0.5, -0.5}, normal = {1.0, 0.0, 0.0}, color = {0.0, 0.0, 1.0}},
	{position = {0.5, 0.5, -0.5}, normal = {1.0, 0.0, 0.0}, color = {0.0, 0.0, 1.0}},
	{position = {0.5, 0.5, 0.5}, normal = {1.0, 0.0, 0.0}, color = {0.0, 0.0, 1.0}},
	// left face	
	{position = {-0.5, -0.5, -0.5}, normal = {-1.0, 0.0, 0.0}, color = {1.0, 1.0, 0.0}},
	{position = {-0.5, -0.5, 0.5}, normal = {-1.0, 0.0, 0.0}, color = {1.0, 1.0, 0.0}},
	{position = {-0.5, 0.5, 0.5}, normal = {-1.0, 0.0, 0.0}, color = {1.0, 1.0, 0.0}},
	{position = {-0.5, 0.5, -0.5}, normal = {-1.0, 0.0, 0.0}, color = {1.0, 1.0, 0.0}},
	// top face
	{position = {-0.5, 0.5, 0.5}, normal = {0.0, 1.0, 0.0}, color = {1.0, 0.0, 1.0}},
	{position = {0.5, 0.5, 0.5}, normal = {0.0, 1.0, 0.0}, color = {1.0, 0.0, 1.0}},
	{position = {0.5, 0.5, -0.5}, normal = {0.0, 1.0, 0.0}, color = {1.0, 0.0, 1.0}},
	{position = {-0.5, 0.5, -0.5}, normal = {0.0, 1.0, 0.0}, color = {1.0, 0.0, 1.0}},
	// bottom face
	{position = {-0.5, -0.5, -0.5}, normal = {0.0, -1.0, 0.0}, color = {0.0, 1.0, 1.0}},
	{position = {0.5, -0.5, -0.5}, normal = {0.0, -1.0, 0.0}, color = {0.0, 1.0, 1.0}},
	{position = {0.5, -0.5, 0.5}, normal = {0.0, -1.0, 0.0}, color = {0.0, 1.0, 1.0}},
	{position = {-0.5, -0.5, 0.5}, normal = {0.0, -1.0, 0.0}, color = {0.0, 1.0, 1.0}},
}

CUBE_INDICIES := [36]u32 {
	//front face
	0,
	1,
	2,
	0,
	2,
	3,
	//back face
	4,
	5,
	6,
	4,
	6,
	7,
	//right face
	8,
	9,
	10,
	8,
	10,
	11,
	//left face
	12,
	13,
	14,
	12,
	14,
	15,
	//top face
	16,
	17,
	18,
	16,
	18,
	19,
	//bottom face
	20,
	21,
	22,
	20,
	22,
	23,
}
