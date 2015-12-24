﻿precision highp float;
// Attributes
attribute vec3 position;
attribute vec3 normal;
#ifdef UV1
attribute vec2 uv;
#endif
#ifdef UV2
attribute vec2 uv2;
#endif
#ifdef VERTEXCOLOR
attribute vec4 color;
#endif
#if NUM_BONE_INFLUENCERS > 0
	uniform mat4 mBones[BonesPerMesh];

	attribute vec4 matricesIndices;
	attribute vec4 matricesWeights;
	#if NUM_BONE_INFLUENCERS > 4
		attribute vec4 matricesIndicesExtra;
		attribute vec4 matricesWeightsExtra;
	#endif
#endif
// Uniforms
uniform float furLength;
uniform float furAngle;
#ifdef HEIGHTMAP
uniform sampler2D heightTexture;
#endif
#ifdef INSTANCES
attribute vec4 world0;
attribute vec4 world1;
attribute vec4 world2;
attribute vec4 world3;
#else
uniform mat4 world;
#endif
uniform mat4 view;
uniform mat4 viewProjection;
#ifdef DIFFUSE
varying vec2 vDiffuseUV;
uniform mat4 diffuseMatrix;
uniform vec2 vDiffuseInfos;
#endif

#ifdef POINTSIZE
uniform float pointSize;
#endif
// Output
varying vec3 vPositionW;
#ifdef NORMAL
varying vec3 vNormalW;
#endif
varying float vfur_length;
#ifdef VERTEXCOLOR
varying vec4 vColor;
#endif
#ifdef CLIPPLANE
uniform vec4 vClipPlane;
varying float fClipDistance;
#endif
#ifdef FOG
varying float fFogDistance;
#endif
#ifdef SHADOWS
#if defined(SPOTLIGHT0) || defined(DIRLIGHT0)
uniform mat4 lightMatrix0;
varying vec4 vPositionFromLight0;
#endif
#if defined(SPOTLIGHT1) || defined(DIRLIGHT1)
uniform mat4 lightMatrix1;
varying vec4 vPositionFromLight1;
#endif
#if defined(SPOTLIGHT2) || defined(DIRLIGHT2)
uniform mat4 lightMatrix2;
varying vec4 vPositionFromLight2;
#endif
#if defined(SPOTLIGHT3) || defined(DIRLIGHT3)
uniform mat4 lightMatrix3;
varying vec4 vPositionFromLight3;
#endif
#endif
float Rand(vec3 rv) {
	float x = dot(rv, vec3(12.9898,78.233, 24.65487));
	return fract(sin(x) * 43758.5453);
}
void main(void) {
	mat4 finalWorld;
#ifdef INSTANCES
	finalWorld = mat4(world0, world1, world2, world3);
#else
	finalWorld = world;
#endif
#if NUM_BONE_INFLUENCERS > 0
	mat4 influence;
	influence = mBones[int(matricesIndices[0])] * matricesWeights[0];

	#if NUM_BONE_INFLUENCERS > 1
		influence += mBones[int(matricesIndices[1])] * matricesWeights[1];
	#endif 
	#if NUM_BONE_INFLUENCERS > 2
		influence += mBones[int(matricesIndices[2])] * matricesWeights[2];
	#endif	
	#if NUM_BONE_INFLUENCERS > 3
		influence += mBones[int(matricesIndices[3])] * matricesWeights[3];
	#endif	

	#if NUM_BONE_INFLUENCERS > 4
		influence += mBones[int(matricesIndicesExtra[0])] * matricesWeightsExtra[0];
	#endif
	#if NUM_BONE_INFLUENCERS > 5
		influence += mBones[int(matricesIndicesExtra[1])] * matricesWeightsExtra[1];
	#endif	
	#if NUM_BONE_INFLUENCERS > 6
		influence += mBones[int(matricesIndicesExtra[2])] * matricesWeightsExtra[2];
	#endif	
	#if NUM_BONE_INFLUENCERS > 7
		influence += mBones[int(matricesIndicesExtra[3])] * matricesWeightsExtra[3];
	#endif	

	finalWorld = finalWorld * influence;
#endif
//FUR
float r = Rand(position);
#ifdef HEIGHTMAP	
	vfur_length = furLength * texture2D(heightTexture, uv).rgb.x;
#else	
	vfur_length = (furLength * r);
#endif
	vec3 tangent1 = vec3(normal.y, -normal.x, 0);
	vec3 tangent2 = vec3(-normal.z, 0, normal.x);
	r = Rand(tangent1*r);
	float J = (2.0 + 4.0* r);
	r = Rand(tangent2*r);
	float K = (2.0 + 2.0* r);
	tangent1 = tangent1*J + tangent2*K;
	tangent1 = normalize(tangent1);
    vec3 newPosition = position + normal * vfur_length*cos(furAngle) + tangent1*vfur_length*sin(furAngle);
	
//END FUR
	gl_Position = viewProjection * finalWorld * vec4(newPosition, 1.0);
	vec4 worldPos = finalWorld * vec4(newPosition, 1.0);
	vPositionW = vec3(worldPos);
#ifdef NORMAL
	vNormalW = normalize(vec3(finalWorld * vec4(normal, 0.0)));
#endif
	// Texture coordinates
#ifndef UV1
	vec2 uv = vec2(0., 0.);
#endif
#ifndef UV2
	vec2 uv2 = vec2(0., 0.);
#endif
#ifdef DIFFUSE
	if (vDiffuseInfos.x == 0.)
	{
		vDiffuseUV = vec2(diffuseMatrix * vec4(uv, 1.0, 0.0));
	}
	else
	{
		vDiffuseUV = vec2(diffuseMatrix * vec4(uv2, 1.0, 0.0));
	}
#endif
	// Clip plane
#ifdef CLIPPLANE
	fClipDistance = dot(worldPos, vClipPlane);
#endif
	// Fog
#ifdef FOG
	fFogDistance = (view * worldPos).z;
#endif
	// Shadows
#ifdef SHADOWS
#if defined(SPOTLIGHT0) || defined(DIRLIGHT0)
	vPositionFromLight0 = lightMatrix0 * worldPos;
#endif
#if defined(SPOTLIGHT1) || defined(DIRLIGHT1)
	vPositionFromLight1 = lightMatrix1 * worldPos;
#endif
#if defined(SPOTLIGHT2) || defined(DIRLIGHT2)
	vPositionFromLight2 = lightMatrix2 * worldPos;
#endif
#if defined(SPOTLIGHT3) || defined(DIRLIGHT3)
	vPositionFromLight3 = lightMatrix3 * worldPos;
#endif
#endif
	// Vertex color
#ifdef VERTEXCOLOR
	vColor = color;
#endif
	// Point size
#ifdef POINTSIZE
	gl_PointSize = pointSize;
#endif
}