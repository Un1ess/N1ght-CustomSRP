#ifndef NIGHTRP_COMMON_INCLUDED
#define NIGHTRP_COMMON_INCLUDED

//汇入unity自带的参数库
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "NightRPInput.hlsl"

#define UNITY_MATRIX_M     unity_ObjectToWorld
#define UNITY_MATRIX_I_M   unity_WorldToObject
#define UNITY_MATRIX_V     unity_MatrixV
#define UNITY_MATRIX_I_V   unity_MatrixInvV
#define UNITY_MATRIX_P     glstate_matrix_projection
#define UNITY_MATRIX_I_P   ERROR_UNITY_MATRIX_I_P_IS_NOT_DEFINED
#define UNITY_MATRIX_VP    unity_MatrixVP
#define UNITY_MATRIX_I_VP  unity_MatrixInvVP
#define UNITY_MATRIX_MV    mul(UNITY_MATRIX_V, UNITY_MATRIX_M)
#define UNITY_MATRIX_T_MV  transpose(UNITY_MATRIX_MV)
#define UNITY_MATRIX_IT_MV transpose(mul(UNITY_MATRIX_I_M, UNITY_MATRIX_I_V))
#define UNITY_MATRIX_MVP   mul(UNITY_MATRIX_VP, UNITY_MATRIX_M)

//汇入矩阵到函数库中进行使用
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

#endif