#ifndef NIGHTRP_INPUT_INCLUDED
#define NIGHTRP_INPUT_INCLUDED

CBUFFER_START(UnityPerDraw)
float4x4 unity_ObjectToWorld;//矩阵汇入
float4x4 unity_WorldToObject;//矩阵汇入
float4 unity_LODFade;
float4 unity_WorldTransformParams;//unity的世界空间参数/**/
CBUFFER_END

float4x4 unity_MatrixVP;//每个相机是独立的 所以不要放在这里

float4x4 unity_MatrixV;

float4x4 glstate_matrix_projection;//矩阵汇入


#endif