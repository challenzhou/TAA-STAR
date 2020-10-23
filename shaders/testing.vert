#version 460
#extension GL_GOOGLE_include_directive : enable
// -------------------------------------------------------

#include "shader_common_main.glsl"
#include "shader_cpu_common.h"

// specialization constant to differentiate between static and dynamic objects
//layout(constant_id = SPECCONST_ID_MOVINGOBJECT) const uint movingObject = SPECCONST_VAL_STATIC;

// ###### VERTEX SHADER/PIPELINE INPUT DATA ##############
// Several vertex attributes (These are the buffers passed
// to command_buffer_t::draw_indexed in the same order):
layout (location = 0) in vec3 aPosition;
layout (location = 1) in vec2 aTexCoords;
layout (location = 2) in vec3 aNormal;
layout (location = 3) in vec3 aTangent;
layout (location = 4) in vec3 aBitangent;

struct PerInstanceAttribute { mat4 modelMatrix; };
layout (std430, set = 0, binding = 2) readonly buffer MaterialIndexBuffer   { uint materialIndex[]; };			// per meshgroup
layout (std430, set = 0, binding = 3) readonly buffer AttribBaseIndexBuffer { uint attrib_base[]; };			// per meshgroup
layout (std430, set = 0, binding = 4) readonly buffer mAttributesBuffer     { PerInstanceAttribute attrib[]; };	// per mesh

layout(push_constant) uniform PushConstantsDII { int mDrawIdOffset; };	// negative: moving object


// "mMatrices" uniform buffer containing camera matrices:
// It is updated every frame.
layout(set = 1, binding = 0) UNIFORMDEF_MatricesAndUserInput uboMatUsr;

// -------------------------------------------------------

// ###### DATA PASSED ON ALONG THE PIPELINE ##############
// Data from vert -> tesc or frag:
layout (location = 0) out VertexData {
	vec3 positionOS;
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
	if (mDrawIdOffset >= 0) {
		// static scenery
		uint meshgroup = gl_DrawID + mDrawIdOffset;
		uint attribIndex = attrib_base[meshgroup] + gl_InstanceIndex;
		v_out.materialIndex  = materialIndex[meshgroup];
		v_out.modelMatrix    = attrib[attribIndex].modelMatrix;
		v_out.movingObjectId = 0;
	} else {
		// moving object
		v_out.materialIndex = uboMatUsr.mActiveMovingObjectMaterialIdx;
		v_out.modelMatrix   = uboMatUsr.mMovingObjectModelMatrix;
		v_out.movingObjectId = -mDrawIdOffset;
	}


	mat4 mMatrix = v_out.modelMatrix;
	mat4 vMatrix = uboMatUsr.mViewMatrix;
	mat4 pMatrix = uboMatUsr.mProjMatrix;
	mat4 vmMatrix = vMatrix * mMatrix;
	mat4 pvmMatrix = pMatrix * vmMatrix;

	vec4 positionOS  = vec4(aPosition, 1.0);
	vec4 positionVS  = vmMatrix * positionOS;
	vec4 positionCS  = pMatrix * positionVS;
	vec3 normalOS    = normalize(aNormal);
	vec3 tangentOS   = normalize(aTangent);
	vec3 bitangentOS = normalize(aBitangent);

	mat4 prev_modelMatrix = (mDrawIdOffset >= 0) ? v_out.modelMatrix : uboMatUsr.mPrevFrameMovingObjectModelMatrix;

	v_out.positionOS  = positionOS.xyz;
	v_out.positionVS  = positionVS.xyz;
	v_out.texCoords   = aTexCoords;
	v_out.normalOS    = normalOS;
	v_out.tangentOS   = tangentOS;
	v_out.bitangentOS = bitangentOS;
	v_out.positionCS  = positionCS;	// TODO: recheck - is it ok to interpolate clip space vars?
	v_out.positionCS_prev = uboMatUsr.mPrevFrameProjViewMatrix * prev_modelMatrix * positionOS;

	gl_Position = positionCS;
}
// -------------------------------------------------------
