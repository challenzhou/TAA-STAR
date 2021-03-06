#version 460
#extension GL_GOOGLE_include_directive : enable
// -------------------------------------------------------

#include "shader_common_main.glsl"
#include "shader_cpu_common.h"

// TODO: fix tangents, bitangents


// ###### VERTEX SHADER/PIPELINE INPUT DATA ##############
// Several vertex attributes (These are the buffers passed
// to command_buffer_t::draw_indexed in the same order):
layout (location = 0) in vec3 aPosition;
layout (location = 1) in vec2 aTexCoords;
layout (location = 2) in vec3 aNormal;
layout (location = 3) in vec3 aTangent;
layout (location = 4) in vec3 aBitangent;
layout (location = 5) in vec4 aBoneWeights;
layout (location = 6) in uvec4 aBoneIndices;

// push constants
layout(push_constant) PUSHCONSTANTSDEF_DII;


// "mMatrices" uniform buffer containing camera matrices:
// It is updated every frame.
layout(set = 1, binding = 0) UNIFORMDEF_MatricesAndUserInput uboMatUsr;

layout(set = 3, binding = 0, std430) readonly buffer BoneMatricesBuffer     { mat4 mat[]; } boneMatrices;
layout(set = 3, binding = 1, std430) readonly buffer BoneMatricesPrevBuffer { mat4 mat[]; } boneMatricesPrev;

// -------------------------------------------------------

// ###### DATA PASSED ON ALONG THE PIPELINE ##############
// Data from vert -> tesc or frag:
layout (location = 0) out VertexData {
	vec4 positionWS;
	vec3 positionVS;
	vec2 texCoords;
	vec3 normalOS;
	vec3 tangentOS;
	vec3 bitangentOS;
	vec4 positionCS;		// TODO: don't really need this!
	vec4 positionCS_prev;	// position in previous frame

	flat uint materialIndex;
	flat mat4 modelMatrix;
	flat int movingObjectId;
} v_out;
// -------------------------------------------------------

// ###### VERTEX SHADER MAIN #############################
void main()
{
	// moving object
	v_out.materialIndex   = mMover_materialIndex;
	v_out.modelMatrix     = uboMatUsr.mMover_additionalModelMatrix * mMover_baseModelMatrix;
	mat4 prev_modelMatrix = uboMatUsr.mMover_additionalModelMatrix_prev * mMover_baseModelMatrix;
	v_out.movingObjectId  = -mDrawType;

	vec4 boneWeights = aBoneWeights;
	// boneWeights.w = 1.0 - boneWeights.x - boneWeights.y - boneWeights.z; // no longer necessary to "normalize", this is now done at model loading

	uint bonesBaseIndex = mMover_meshIndex * MAX_BONES;

	// weighted sum of the four bone matrices
	mat4 boneMat =      boneMatrices.mat    [bonesBaseIndex + aBoneIndices[0]] * boneWeights[0]
				      + boneMatrices.mat    [bonesBaseIndex + aBoneIndices[1]] * boneWeights[1]
				      + boneMatrices.mat    [bonesBaseIndex + aBoneIndices[2]] * boneWeights[2]
				      + boneMatrices.mat    [bonesBaseIndex + aBoneIndices[3]] * boneWeights[3];

	mat4 prev_boneMat = boneMatricesPrev.mat[bonesBaseIndex + aBoneIndices[0]] * boneWeights[0]
					  + boneMatricesPrev.mat[bonesBaseIndex + aBoneIndices[1]] * boneWeights[1]
					  + boneMatricesPrev.mat[bonesBaseIndex + aBoneIndices[2]] * boneWeights[2]
					  + boneMatricesPrev.mat[bonesBaseIndex + aBoneIndices[3]] * boneWeights[3];

	mat4 mMatrix = v_out.modelMatrix;
	mat4 vMatrix = uboMatUsr.mViewMatrix;
	mat4 pMatrix = uboMatUsr.mProjMatrix;
	mat4 vmMatrix = vMatrix * mMatrix;
	mat4 pvmMatrix = pMatrix * vmMatrix;

	vec4 positionOS  = boneMat * vec4(aPosition, 1.0);
	vec4 positionVS  = vmMatrix * positionOS;
	vec4 positionCS  = pMatrix * positionVS;

	mat3 normalMatrix = mat3(inverse(transpose(boneMat)));				// TODO: can we do inverse(transpose(mat3(M))) instead? could be faster
	vec3 normalOS     = normalize(normalMatrix * normalize(aNormal));	// TODO: (1) first normalize() necessary?   (2) aNormal should be normalized already... (really?)
	vec3 tangentOS    = normalize(normalMatrix * normalize(aTangent));
	vec3 bitangentOS  = normalize(normalMatrix * normalize(aBitangent));

	v_out.positionWS  = mMatrix * positionOS;
	v_out.positionVS  = positionVS.xyz;
	v_out.texCoords   = aTexCoords;
	v_out.normalOS    = normalOS;
	v_out.tangentOS   = tangentOS;
	v_out.bitangentOS = bitangentOS;
	v_out.positionCS  = positionCS;	// TODO: recheck - is it ok to interpolate clip space vars?
	v_out.positionCS_prev = uboMatUsr.mPrevFrameProjViewMatrix * prev_modelMatrix * prev_boneMat * vec4(aPosition, 1.0);

	gl_Position = positionCS;
}
// -------------------------------------------------------

