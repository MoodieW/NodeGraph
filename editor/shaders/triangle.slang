[shader("vertex")]
float4 vertexMain(uint vertexID: SV_VertexID, out float3 fragColor: COLOR) : SV_Position {
// testtet
  static const float2 positions[3] = {
    float2(0.0, -0.5),
    float2(0.5, 0.5),
    float2(-0.5, 0.5),
  };
    
  static const float3 colors[3] = {
    float3(1.0, 0.0, 0.0),
    float3(0.0, 1.0, 0.0),
    float3(0.0, 0.0, 1.0),
  };

  fragColor = colors[vertexID];
  return float4(positions[vertexID], 0.0, 1.0);
};


[shader("fragment")]
float4 fragmentMain(float3 fragColor: COLOR) : SV_Target {
  return float4(fragColor, 1.0);
}
//
//
