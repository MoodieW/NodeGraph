[shader("vertex")]
float4 vertexMain(
  float2 position : ATTRIB0,
  float2 uv_in : ATTRIB1,
  out float2 uv: UV
) : SV_Position {

  uv = uv_in;
  return float4(position, 0.0, 1.0);
};


[shader("fragment")]
float4 fragmentMain(float2 uv: UV) : SV_Target {
  // UV visualization: R=u, G=v, B=0
  return float4(uv, 0.0, 1.0);
}
