#version 460
#extension GL_EXT_nonuniform_qualifier : require
#extension GL_GOOGLE_include_directive : enable
// -------------------------------------------------------

#include "shader_common_main.glsl"
#include "shader_cpu_common.h"

layout(set = 1, binding = 0) UNIFORMDEF_MatricesAndUserInput uboMatUsr;
layout(set = SHADOWMAP_BINDING_SET, binding = SHADOWMAP_BINDING_SLOT) uniform texture2D texShadowMap[];
layout(set = 5, binding = 0) uniform sampler uSampler;

layout (location = 0) out vec4 oFragColor;

layout (location = 0) in VertexData {
	vec2 texCoords;
} f_in;

void main() {
	//oFragColor = vec4(vec3(texture(sampler2D(texShadowMap[0], uSampler), f_in.texCoords).r), 1.0);
	vec2 uv;
	int cascade;
	if (f_in.texCoords.x < 0.5 && f_in.texCoords.y < 0.5) {
		cascade = 0;
		uv = f_in.texCoords * 2.0;
	} else if (f_in.texCoords.x >= 0.5 && f_in.texCoords.y < 0.5) {
		cascade = 1;
		uv = (f_in.texCoords - vec2(0.5, 0.0)) * 2.0;
	} else if (f_in.texCoords.x < 0.5 && f_in.texCoords.y >= 0.5) {
		cascade = 2;
		uv = (f_in.texCoords - vec2(0.0, 0.5)) * 2.0;
	} else {
		cascade = 3;
		uv = (f_in.texCoords - vec2(0.5, 0.5)) * 2.0;
	}
	if (cascade < uboMatUsr.mShadowNumCascades) {
		oFragColor = vec4(vec3(texture(sampler2D(texShadowMap[cascade], uSampler), vec2(uv.x, 1-uv.y)).r), 1.0); // flip y (if shadow cam is oriented upside down)
		//oFragColor = vec4(vec3(texture(sampler2D(texShadowMap[cascade], uSampler), uv).r), 1.0);
	} else {
		oFragColor = vec4(0,0,0,1);
	}
}
