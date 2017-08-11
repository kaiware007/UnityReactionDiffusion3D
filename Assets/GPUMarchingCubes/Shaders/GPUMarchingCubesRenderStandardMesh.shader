Shader "Custom/GPUMarchingCubesRenderStandardMesh"
{
	Properties
	{
		_MainTex ("Texture", 3D) = "" {}
		_Width("Width", int) = 32
		_Height("Height", int) = 32
		_Depth("Depth", int) = 32

		_Scale("Scale", float) = 1
		_SampleScale("Sample Scale", float) = 0.1
		_Threashold("Threashold", float) = 0.5

		_DiffuseColor("Diffuse", Color) = (0,0,0,1)
		//_SpecularColor("Specular", Color) = ( 1,1,1,1 )
		_SpecularPower("Specular Power", Range(0,100)) = 32

		_EmissionIntensity("Emission Intensity", Range(0,1)) = 1
		_EmissionColor("Emission", Color) = (0,0,0,1)

		_Glossiness("Smoothness", Range(0,1)) = 0.5
		_Metallic("Metallic", Range(0,1)) = 0.0
	}

	SubShader
	{
		Tags{ "RenderType" = "Opaque" }

		CGINCLUDE
#define UNITY_PASS_DEFERRED
#include "HLSLSupport.cginc"
#include "UnityShaderVariables.cginc"
#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "UnityPBSLighting.cginc"

#include "Libs/SimplexNoise3D.cginc"
#include "Libs/MarchingCubesTables.cginc"

			struct appdata
		{
			float4 vertex	: POSITION;
			float2 uv		: TEXCOORD0;
		};

		struct v2g
		{
			float4 pos : SV_POSITION;
			float4 tangent : TANGENT;
			float3 normal : NORMAL;
			fixed4 color : COLOR;
		};

		struct g2f_light
		{
			//float2 uv : TEXCOORD0;
			float4 pos		: SV_POSITION;
			float3 normal		: NORMAL;
			float4 worldPos		: TEXCOORD0;
			float3 lightDir : TEXCOORD1;
			float3 viewDir  : TEXCOORD2;
			//LIGHTING_COORDS(3, 4)
			half3 sh : TEXCOORD3; // SH
		};
		
		struct g2f_shadow
		{
			//float2 uv : TEXCOORD0;
			float4 pos		: SV_POSITION;
			float4 hpos			: TEXCOORD1;
		};

		int _Width;
		int _Height;
		int _Depth;

		float _Scale;
		float _SampleScale;
		float _Threashold;

		float3 _LightPos;
		float4 _DiffuseColor;
		//float4 _SpecularColor;
		float _SpecularPower;
		float3 _HalfSize;
		float4x4 _Matrix;

		float _EmissionIntensity;
		half3 _EmissionColor;

		half _Glossiness;
		half _Metallic;

		sampler3D _MainTex;

		// simplex noise test
		//float Sample(float x, float y, float z) {
		//	return snoise(float3(x + _Time.y, y, z) * _SampleScale);	// test
		//}

		float Sample(float x, float y, float z) {

			if ((x <= 1) || (y <= 1) || (z <= 1) || (x >= (_Width - 1)) || (y >= (_Height - 1)) || (z >= (_Depth - 1)))
				return 0;

			float4 uv = float4(x / _Width, y / _Height, z / _Depth, 0) * _SampleScale;
			//if (distance(uv.xyz, float3(0.5, 0.5, 0.5)) < 0.25) return 0;	// 中心部だけくり抜き

			float4 c = tex3Dlod(_MainTex, uv);
			return c.r;
		}

		float getOffset(float val1, float val2, float desired) {
			float delta = val2 - val1;
			if (delta == 0.0) {
				return 0.5;
			}
			return (desired - val1) / delta;
		}

		float3 getNormal(float fX, float fY, float fZ)
		{
			float3 normal;
			float offset = 1.0;	// 0.5

			normal.x = Sample(fX - offset, fY, fZ) - Sample(fX + offset, fY, fZ);
			normal.y = Sample(fX, fY - offset, fZ) - Sample(fX, fY + offset, fZ);
			normal.z = Sample(fX, fY, fZ - offset) - Sample(fX, fY, fZ + offset);

			return normal;
		}

		//v2g vert(uint id : SV_VertexID)
		v2g vert(appdata v)
		{
			v2g o = (v2g)0;
			o.pos = v.vertex;
			return o;
		}

		// ジオメトリシェーダ(light用)
		[maxvertexcount(18)]
		void geom_light(point v2g input[1], inout TriangleStream<g2f_light> outStream)
		{
			g2f_light o = (g2f_light)0;

			int i, j;
			float cubeValue[8];
			float3 edgeVertices[12] = {
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0) };
			float3 edgeNormals[12] = {
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0) };

			float3 pos = input[0].pos.xyz;
			float3 defpos = pos;

			for (i = 0; i < 8; i++) {
				cubeValue[i] = Sample(
					pos.x + vertexOffsetX[i],
					pos.y + vertexOffsetY[i],
					pos.z + vertexOffsetZ[i]);
			}

			pos *= _Scale;
			pos -= _HalfSize;
			//pos = mul(_Matrix, pos);

			int flagIndex = 0;

			for (i = 0; i < 8; i++) {
				if (cubeValue[i] <= _Threashold) {
					flagIndex |= (1 << i);
				}
			}

			int edgeFlags = cubeEdgeFlags[flagIndex];

			if ((edgeFlags == 0) || (edgeFlags == 255)) {
				return;
			}

			float offset = 0.5;
			float3 vertex;
			for (i = 0; i < 12; i++) {
				if ((edgeFlags & (1 << i)) != 0) {
					offset = getOffset(cubeValue[edgeConnectionX[i]], cubeValue[edgeConnectionY[i]], _Threashold);

					vertex.x = (vertexOffsetX[edgeConnectionX[i]] + offset * edgeDirectionX[i]);
					vertex.y = (vertexOffsetY[edgeConnectionX[i]] + offset * edgeDirectionY[i]);
					vertex.z = (vertexOffsetZ[edgeConnectionX[i]] + offset * edgeDirectionZ[i]);

					edgeVertices[i].x = pos.x + vertex.x * _Scale;
					edgeVertices[i].y = pos.y + vertex.y * _Scale;
					edgeVertices[i].z = pos.z + vertex.z * _Scale;

					edgeNormals[i] = getNormal(defpos.x + vertex.x, defpos.y + vertex.y, defpos.z + vertex.z);
				}
			}

			int vindex = 0;
			int findex = 0;
			for (i = 0; i < 5; i++) {
				findex = flagIndex * 16 + 3 * i;
				if (triangleConnectionTable[findex] < 0)
					break;

				// Normal
				float3 v0 = edgeVertices[triangleConnectionTable[findex + 1]] - edgeVertices[triangleConnectionTable[findex]];
				float3 v1 = edgeVertices[triangleConnectionTable[findex + 2]] - edgeVertices[triangleConnectionTable[findex]];
				//float3 norm = UnityObjectToWorldNormal(normalize(cross(v0, v1)));
				//float3 defnorm = UnityObjectToWorldNormal(normalize(cross(v0, v1)));

				for (j = 0; j < 3; j++) {
					vindex = triangleConnectionTable[findex + j];

					float4 ppos = mul(_Matrix, float4(edgeVertices[vindex], 1));
					o.pos = UnityObjectToClipPos(ppos);
					float3 norm;
					norm = UnityObjectToWorldNormal(normalize(edgeNormals[vindex]));
					//if ((abs(edgeNormals[vindex].x) <= 0.001) &&
					//	(abs(edgeNormals[vindex].y) <= 0.001) &&
					//	(abs(edgeNormals[vindex].z) <= 0.001))
					//{
					//	norm = defnorm;
					//}
					//else {
					//	norm = UnityObjectToWorldNormal(normalize(edgeNormals[vindex]));
					//}
					o.normal = normalize(mul(_Matrix, float4(norm,0)));

					o.lightDir = normalize(WorldSpaceLightDir(ppos));
					o.viewDir = normalize(WorldSpaceViewDir(ppos));
					//TRANSFER_VERTEX_TO_FRAGMENT(o);


					outStream.Append(o);
				}
				outStream.RestartStrip();
			}
		}

		void frag_light(g2f_light IN,
			out half4 outDiffuse : SV_Target0,
			out half4 outSpecSmoothness : SV_Target1,
			out half4 outNormal : SV_Target2,
			out half4 outEmission : SV_Target3)
		{
			fixed3 normal = IN.normal;

			float3 worldPos = IN.worldPos;

			fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));

#ifdef UNITY_COMPILER_HLSL
			SurfaceOutputStandard o = (SurfaceOutputStandard)0;
#else
			SurfaceOutputStandard o;
#endif
			o.Albedo = _DiffuseColor.rgb;
			o.Emission = _EmissionColor * _EmissionIntensity;
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			o.Alpha = 1.0;
			o.Occlusion = 1.0;
			o.Normal = normal;

			// Setup lighting environment
			UnityGI gi;
			UNITY_INITIALIZE_OUTPUT(UnityGI, gi);
			gi.indirect.diffuse = 0;
			gi.indirect.specular = 0;
			gi.light.color = 0;
			gi.light.dir = half3(0, 1, 0);
			gi.light.ndotl = LambertTerm(o.Normal, gi.light.dir);
			// Call GI (lightmaps/SH/reflections) lighting function
			UnityGIInput giInput;
			UNITY_INITIALIZE_OUTPUT(UnityGIInput, giInput);
			giInput.light = gi.light;
			giInput.worldPos = worldPos;
			giInput.worldViewDir = worldViewDir;
			giInput.atten = 1.0;

			giInput.ambient = IN.sh;

			giInput.probeHDR[0] = unity_SpecCube0_HDR;
			giInput.probeHDR[1] = unity_SpecCube1_HDR;

#if UNITY_SPECCUBE_BLENDING || UNITY_SPECCUBE_BOX_PROJECTION
			giInput.boxMin[0] = unity_SpecCube0_BoxMin; // .w holds lerp value for blending
#endif

#if UNITY_SPECCUBE_BOX_PROJECTION
			giInput.boxMax[0] = unity_SpecCube0_BoxMax;
			giInput.probePosition[0] = unity_SpecCube0_ProbePosition;
			giInput.boxMax[1] = unity_SpecCube1_BoxMax;
			giInput.boxMin[1] = unity_SpecCube1_BoxMin;
			giInput.probePosition[1] = unity_SpecCube1_ProbePosition;
#endif

			LightingStandard_GI(o, giInput, gi);

			// call lighting function to output g-buffer
			outEmission = LightingStandard_Deferred(o, worldViewDir, gi, outDiffuse, outSpecSmoothness, outNormal);
			outDiffuse.a = 1.0;

#ifndef UNITY_HDR_ON
			outEmission.rgb = exp2(-outEmission.rgb);
#endif
		}

		// ジオメトリシェーダ(shadow用)
		[maxvertexcount(18)]
		void geom_shadow(point v2g input[1], inout TriangleStream<g2f_shadow> outStream)
		{
			g2f_shadow o = (g2f_shadow)0;

			int i, j;
			float cubeValue[8];
			float3 edgeVertices[12] = {
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0) };
			float3 edgeNormals[12] = {
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0),
				float3(0, 0, 0) };

			float3 pos = input[0].pos.xyz;
			float3 defpos = pos;

			for (i = 0; i < 8; i++) {
				cubeValue[i] = Sample(
					pos.x + vertexOffsetX[i],
					pos.y + vertexOffsetY[i],
					pos.z + vertexOffsetZ[i]);
			}

			pos *= _Scale;
			pos -= _HalfSize;

			int flagIndex = 0;

			for (i = 0; i < 8; i++) {
				if (cubeValue[i] <= _Threashold) {
					flagIndex |= (1 << i);
				}
			}

			int edgeFlags = cubeEdgeFlags[flagIndex];

			if ((edgeFlags == 0) || (edgeFlags == 255)) {
				return;
			}

			float offset = 0.5;
			float3 vertex;
			for (i = 0; i < 12; i++) {
				if ((edgeFlags & (1 << i)) != 0) {
					offset = getOffset(cubeValue[edgeConnectionX[i]], cubeValue[edgeConnectionY[i]], _Threashold);

					vertex.x = (vertexOffsetX[edgeConnectionX[i]] + offset * edgeDirectionX[i]);
					vertex.y = (vertexOffsetY[edgeConnectionX[i]] + offset * edgeDirectionY[i]);
					vertex.z = (vertexOffsetZ[edgeConnectionX[i]] + offset * edgeDirectionZ[i]);

					edgeVertices[i].x = pos.x + vertex.x * _Scale;
					edgeVertices[i].y = pos.y + vertex.y * _Scale;
					edgeVertices[i].z = pos.z + vertex.z * _Scale;

					edgeNormals[i] = getNormal(defpos.x + vertex.x, defpos.y + vertex.y, defpos.z + vertex.z);
				}
			}

			int vindex = 0;
			int findex = 0;
			for (i = 0; i < 5; i++) {
				findex = flagIndex * 16 + 3 * i;
				if (triangleConnectionTable[findex] < 0)
					break;

				// Normal
				float3 v0 = edgeVertices[triangleConnectionTable[findex + 1]] - edgeVertices[triangleConnectionTable[findex]];
				float3 v1 = edgeVertices[triangleConnectionTable[findex + 2]] - edgeVertices[triangleConnectionTable[findex]];
				//float3 norm = normalize(cross(v0, v1));
				//float3 defnorm = UnityObjectToWorldNormal(normalize(cross(v0, v1)));

				for (j = 0; j < 3; j++) {
					vindex = triangleConnectionTable[findex + j];

					float4 ppos = mul(_Matrix, float4(edgeVertices[vindex], 1));

					float3 norm;
					norm = UnityObjectToWorldNormal(normalize(edgeNormals[vindex]));

					float4 lpos1 = mul(unity_WorldToObject, ppos);
					o.pos = UnityClipSpaceShadowCasterPos(lpos1, normalize(mul(_Matrix, float4(norm, 0))));
					o.pos = UnityApplyLinearShadowBias(o.pos);
					o.hpos = o.pos;

					outStream.Append(o);
				}
				outStream.RestartStrip();
			}
		}

		fixed4 frag_shadow(g2f_shadow i) : SV_Target
		{
			return i.hpos.zw.x / i.hpos.zw.y;
		}
		ENDCG

		Pass{
			Tags{ "LightMode" = "Deferred" }

			
			CGPROGRAM
			#pragma target 5.0
			#pragma vertex vert
			#pragma geometry geom_light
			#pragma fragment frag_light
			#pragma exclude_renderers nomrt
			#pragma multi_compile_prepassfinal noshadow
//
//			#define UNITY_PASS_DEFERRED
//			#include "HLSLSupport.cginc"
//			#include "UnityShaderVariables.cginc"
//			#include "UnityCG.cginc"
//			#include "Lighting.cginc"
//			#include "UnityPBSLighting.cginc"
//
//			#include "Libs/SimplexNoise3D.cginc"
//			#include "Libs/MarchingCubesTables.cginc"
//
//			struct appdata
//			{
//				float4 vertex	: POSITION;
//				float2 uv		: TEXCOORD0;
//			};
//
//			struct v2g
//			{
//				float4 pos : SV_POSITION;
//				float4 tangent : TANGENT;
//				float3 normal : NORMAL;
//				float4 texcoord : TEXCOORD0;
//				float4 texcoord1 : TEXCOORD1;
//				float4 texcoord2 : TEXCOORD2;
//				float4 texcoord3 : TEXCOORD3;
//				fixed4 color : COLOR;
//			};
//
//			struct g2f_light
//			{
//				//float2 uv : TEXCOORD0;
//				float4 pos		: SV_POSITION;
//				float3 normal		: NORMAL;
//				float4 worldPos		: TEXCOORD0;
//				float3 lightDir : TEXCOORD1;
//				float3 viewDir  : TEXCOORD2;
//				//LIGHTING_COORDS(3, 4)
//				half3 sh : TEXCOORD3; // SH
//			};
//
//			struct g2f_shadow
//			{
//				//float2 uv : TEXCOORD0;
//				float4 pos		: SV_POSITION;
//				float4 hpos			: TEXCOORD1;
//			};
//
//			int _Width;
//			int _Height;
//			int _Depth;
//
//			float _Scale;
//			float _SampleScale;
//			float _Threashold;
//
//			float3 _LightPos;
//			float4 _DiffuseColor;
//			float4 _SpecularColor;
//			float _SpecularPower;
//			float3 _HalfSize;
//			float4x4 _Matrix;
//
//			float _EmissionIntensity;
//			half3 _EmissionColor;
//
//			half _Glossiness;
//			half _Metallic;
//
//			sampler3D _MainTex;
//
//			// simplex noise test
//			//float Sample(float x, float y, float z) {
//			//	return snoise(float3(x + _Time.y, y, z) * _SampleScale);	// test
//			//}
//
//			float Sample(float x, float y, float z) {
//
//				if ((x <= 1) || (y <= 1) || (z <= 1) || (x >= (_Width - 1)) || (y >= (_Height - 1)) || (z >= (_Depth - 1)))
//					return 0;
//
//				float4 uv = float4(x / _Width, y / _Height, z / _Depth, 0) * _SampleScale;
//				//if (distance(uv.xyz, float3(0.5, 0.5, 0.5)) < 0.25) return 0;	// 中心部だけくり抜き
//
//				float4 c = tex3Dlod(_MainTex, uv);
//				return c.r;
//			}
//
//			float getOffset(float val1, float val2, float desired) {
//				float delta = val2 - val1;
//				if (delta == 0.0) {
//					return 0.5;
//				}
//				return (desired - val1) / delta;
//			}
//
//			float3 getNormal(float fX, float fY, float fZ)
//			{
//				float3 normal;
//				float offset = 1.0;	// 0.5
//
//				normal.x = Sample(fX - offset, fY, fZ) - Sample(fX + offset, fY, fZ);
//				normal.y = Sample(fX, fY - offset, fZ) - Sample(fX, fY + offset, fZ);
//				normal.z = Sample(fX, fY, fZ - offset) - Sample(fX, fY, fZ + offset);
//
//				return normal;
//			}
//
//			//v2g vert(uint id : SV_VertexID)
//			v2g vert(appdata v)
//			{
//				v2g o = (v2g)0;
//				o.pos = v.vertex;
//				return o;
//			}
//
//			// ジオメトリシェーダ(light用)
//			[maxvertexcount(18)]
//			void geom_light(point v2g input[1], inout TriangleStream<g2f_light> outStream)
//			{
//				g2f_light o = (g2f_light)0;
//
//				int i, j;
//				float cubeValue[8];
//				float3 edgeVertices[12] = {
//					float3(0, 0, 0),
//					float3(0, 0, 0),
//					float3(0, 0, 0),
//					float3(0, 0, 0),
//					float3(0, 0, 0),
//					float3(0, 0, 0),
//					float3(0, 0, 0),
//					float3(0, 0, 0),
//					float3(0, 0, 0),
//					float3(0, 0, 0),
//					float3(0, 0, 0),
//					float3(0, 0, 0) };
//				float3 edgeNormals[12] = {
//					float3(0, 0, 0),
//					float3(0, 0, 0),
//					float3(0, 0, 0),
//					float3(0, 0, 0),
//					float3(0, 0, 0),
//					float3(0, 0, 0),
//					float3(0, 0, 0),
//					float3(0, 0, 0),
//					float3(0, 0, 0),
//					float3(0, 0, 0),
//					float3(0, 0, 0),
//					float3(0, 0, 0) };
//
//				float3 pos = input[0].pos.xyz;
//				float3 defpos = pos;
//
//				for (i = 0; i < 8; i++) {
//					cubeValue[i] = Sample(
//						pos.x + vertexOffsetX[i],
//						pos.y + vertexOffsetY[i],
//						pos.z + vertexOffsetZ[i]);
//				}
//
//				pos *= _Scale;
//				pos -= _HalfSize;
//				//pos = mul(_Matrix, pos);
//
//				int flagIndex = 0;
//
//				for (i = 0; i < 8; i++) {
//					if (cubeValue[i] <= _Threashold) {
//						flagIndex |= (1 << i);
//					}
//				}
//
//				int edgeFlags = cubeEdgeFlags[flagIndex];
//
//				if ((edgeFlags == 0) || (edgeFlags == 255)) {
//					return;
//				}
//
//				float offset = 0.5;
//				float3 vertex;
//				for (i = 0; i < 12; i++) {
//					if ((edgeFlags & (1 << i)) != 0) {
//						offset = getOffset(cubeValue[edgeConnectionX[i]], cubeValue[edgeConnectionY[i]], _Threashold);
//
//						vertex.x = (vertexOffsetX[edgeConnectionX[i]] + offset * edgeDirectionX[i]);
//						vertex.y = (vertexOffsetY[edgeConnectionX[i]] + offset * edgeDirectionY[i]);
//						vertex.z = (vertexOffsetZ[edgeConnectionX[i]] + offset * edgeDirectionZ[i]);
//
//						edgeVertices[i].x = pos.x + vertex.x * _Scale;
//						edgeVertices[i].y = pos.y + vertex.y * _Scale;
//						edgeVertices[i].z = pos.z + vertex.z * _Scale;
//
//						edgeNormals[i] = getNormal(defpos.x + vertex.x, defpos.y + vertex.y, defpos.z + vertex.z);
//					}
//				}
//
//				int vindex = 0;
//				int findex = 0;
//				for (i = 0; i < 5; i++) {
//					findex = flagIndex * 16 + 3 * i;
//					if (triangleConnectionTable[findex] < 0)
//						break;
//
//					// Normal
//					float3 v0 = edgeVertices[triangleConnectionTable[findex + 1]] - edgeVertices[triangleConnectionTable[findex]];
//					float3 v1 = edgeVertices[triangleConnectionTable[findex + 2]] - edgeVertices[triangleConnectionTable[findex]];
//					//float3 norm = UnityObjectToWorldNormal(normalize(cross(v0, v1)));
//					//float3 defnorm = UnityObjectToWorldNormal(normalize(cross(v0, v1)));
//
//					for (j = 0; j < 3; j++) {
//						vindex = triangleConnectionTable[findex + j];
//
//						float4 ppos = mul(_Matrix, float4(edgeVertices[vindex], 1));
//						o.pos = UnityObjectToClipPos(ppos);
//						float3 norm;
//						norm = UnityObjectToWorldNormal(normalize(edgeNormals[vindex]));
//						//if ((abs(edgeNormals[vindex].x) <= 0.001) &&
//						//	(abs(edgeNormals[vindex].y) <= 0.001) &&
//						//	(abs(edgeNormals[vindex].z) <= 0.001))
//						//{
//						//	norm = defnorm;
//						//}
//						//else {
//						//	norm = UnityObjectToWorldNormal(normalize(edgeNormals[vindex]));
//						//}
//						o.normal = normalize(mul(_Matrix, float4(norm,0)));
//
//						o.lightDir = normalize(WorldSpaceLightDir(ppos));
//						o.viewDir = normalize(WorldSpaceViewDir(ppos));
//						//TRANSFER_VERTEX_TO_FRAGMENT(o);
//
//
//						outStream.Append(o);
//					}
//					outStream.RestartStrip();
//				}
//			}
//
//			void frag_light(g2f_light IN,
//				out half4 outDiffuse : SV_Target0,
//				out half4 outSpecSmoothness : SV_Target1,
//				out half4 outNormal : SV_Target2,
//				out half4 outEmission : SV_Target3)
//			{
//				fixed3 normal = IN.normal;
//
//				float3 worldPos = IN.worldPos;
//
//				fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));
//
//#ifdef UNITY_COMPILER_HLSL
//				SurfaceOutputStandard o = (SurfaceOutputStandard)0;
//#else
//				SurfaceOutputStandard o;
//#endif
//				o.Albedo = _DiffuseColor.rgb;
//				o.Emission = _EmissionColor * _EmissionIntensity;
//				o.Metallic = _Metallic;
//				o.Smoothness = _Glossiness;
//				o.Alpha = 1.0;
//				o.Occlusion = 1.0;
//				o.Normal = normal;
//
//				// Setup lighting environment
//				UnityGI gi;
//				UNITY_INITIALIZE_OUTPUT(UnityGI, gi);
//				gi.indirect.diffuse = 0;
//				gi.indirect.specular = 0;
//				gi.light.color = 0;
//				gi.light.dir = half3(0, 1, 0);
//				gi.light.ndotl = LambertTerm(o.Normal, gi.light.dir);
//				// Call GI (lightmaps/SH/reflections) lighting function
//				UnityGIInput giInput;
//				UNITY_INITIALIZE_OUTPUT(UnityGIInput, giInput);
//				giInput.light = gi.light;
//				giInput.worldPos = worldPos;
//				giInput.worldViewDir = worldViewDir;
//				giInput.atten = 1.0;
//
//				giInput.ambient = IN.sh;
//
//				giInput.probeHDR[0] = unity_SpecCube0_HDR;
//				giInput.probeHDR[1] = unity_SpecCube1_HDR;
//
//#if UNITY_SPECCUBE_BLENDING || UNITY_SPECCUBE_BOX_PROJECTION
//				giInput.boxMin[0] = unity_SpecCube0_BoxMin; // .w holds lerp value for blending
//#endif
//
//#if UNITY_SPECCUBE_BOX_PROJECTION
//				giInput.boxMax[0] = unity_SpecCube0_BoxMax;
//				giInput.probePosition[0] = unity_SpecCube0_ProbePosition;
//				giInput.boxMax[1] = unity_SpecCube1_BoxMax;
//				giInput.boxMin[1] = unity_SpecCube1_BoxMin;
//				giInput.probePosition[1] = unity_SpecCube1_ProbePosition;
//#endif
//
//				LightingStandard_GI(o, giInput, gi);
//
//				// call lighting function to output g-buffer
//				outEmission = LightingStandard_Deferred(o, worldViewDir, gi, outDiffuse, outSpecSmoothness, outNormal);
//				outDiffuse.a = 1.0;
//
//#ifndef UNITY_HDR_ON
//				outEmission.rgb = exp2(-outEmission.rgb);
//#endif
//			}
			ENDCG
		}

		Pass {
			Tags{ "LightMode" = "ShadowCaster" }
			ZWrite On ZTest LEqual
			CGPROGRAM
			#pragma target 5.0
			#pragma vertex vert
			#pragma geometry geom_shadow
			#pragma fragment frag_shadow
			#pragma multi_compile_shadowcaster

			//#include "UnityCG.cginc"
			//#include "AutoLight.cginc"

			//#include "Libs/SimplexNoise3D.cginc"
			//#include "Libs/MarchingCubesTables.cginc"

			//struct appdata
			//{
			//	float4 vertex	: POSITION;
			//	float2 uv		: TEXCOORD0;
			//};

			//struct v2g
			//{
			//	float4 pos : SV_POSITION;
			//	float4 tangent : TANGENT;
			//	float3 normal : NORMAL;
			//	float4 texcoord : TEXCOORD0;
			//	float4 texcoord1 : TEXCOORD1;
			//	float4 texcoord2 : TEXCOORD2;
			//	float4 texcoord3 : TEXCOORD3;
			//	fixed4 color : COLOR;
			//};

			//struct g2f_shadow
			//{
			//	//float2 uv : TEXCOORD0;
			//	float4 pos		: SV_POSITION;
			//	float4 hpos			: TEXCOORD1;
			//};

			//int _Width;
			//int _Height;
			//int _Depth;

			//float _Scale;
			//float _SampleScale;
			//float _Threashold;

			//float3 _LightPos;
			//float4 _DiffuseColor;
			//float4 _SpecularColor;
			//float _SpecularPower;
			//float3 _HalfSize;
			//float4x4 _Matrix;

			//half _Glossiness;
			//half _Metallic;

			//sampler3D _MainTex;

			//uniform fixed4 _LightColor0;

			//// simplex noise test
			////float Sample(float x, float y, float z) {
			////	return snoise(float3(x + _Time.y, y, z) * _SampleScale);	// test
			////}

			//float Sample(float x, float y, float z) {

			//	if ((x <= 0) || (y <= 0) || (z <= 0) || (x >= _Width) || (y >= _Height) || (z >= _Depth))
			//		return 0;

			//	float4 uv = float4(x / _Width, y / _Height, z / _Depth, 0) * _SampleScale;
			//	//if (distance(uv.xyz, float3(0.5, 0.5, 0.5)) < 0.25) return 0;	// 中心部だけくり抜き

			//	float4 c = tex3Dlod(_MainTex, uv);
			//	return c.r;
			//}

			//float getOffset(float val1, float val2, float desired) {
			//	float delta = val2 - val1;
			//	if (delta == 0.0) {
			//		return 0.5;
			//	}
			//	return (desired - val1) / delta;
			//}

			//float3 getNormal(float fX, float fY, float fZ)
			//{
			//	float3 normal;
			//	float offset = 1.0;	// 0.5

			//	normal.x = Sample(fX - offset, fY, fZ) - Sample(fX + offset, fY, fZ);
			//	normal.y = Sample(fX, fY - offset, fZ) - Sample(fX, fY + offset, fZ);
			//	normal.z = Sample(fX, fY, fZ - offset) - Sample(fX, fY, fZ + offset);

			//	return normal;
			//}

			//v2g vert(appdata v)
			//{
			//	v2g o = (v2g)0;
			//	o.pos = v.vertex;
			//	return o;
			//}

			//// ジオメトリシェーダ(shadow用)
			//[maxvertexcount(18)]
			//void geom_shadow(point v2g input[1], inout TriangleStream<g2f_shadow> outStream)
			//{
			//	g2f_shadow o = (g2f_shadow)0;

			//	int i, j;
			//	float cubeValue[8];
			//	float3 edgeVertices[12] = {
			//		float3(0, 0, 0),
			//		float3(0, 0, 0),
			//		float3(0, 0, 0),
			//		float3(0, 0, 0),
			//		float3(0, 0, 0),
			//		float3(0, 0, 0),
			//		float3(0, 0, 0),
			//		float3(0, 0, 0),
			//		float3(0, 0, 0),
			//		float3(0, 0, 0),
			//		float3(0, 0, 0),
			//		float3(0, 0, 0) };
			//	float3 edgeNormals[12] = {
			//		float3(0, 0, 0),
			//		float3(0, 0, 0),
			//		float3(0, 0, 0),
			//		float3(0, 0, 0),
			//		float3(0, 0, 0),
			//		float3(0, 0, 0),
			//		float3(0, 0, 0),
			//		float3(0, 0, 0),
			//		float3(0, 0, 0),
			//		float3(0, 0, 0),
			//		float3(0, 0, 0),
			//		float3(0, 0, 0) };

			//	float3 pos = input[0].pos.xyz;
			//	float3 defpos = pos;

			//	for (i = 0; i < 8; i++) {
			//		cubeValue[i] = Sample(
			//			pos.x + vertexOffsetX[i],
			//			pos.y + vertexOffsetY[i],
			//			pos.z + vertexOffsetZ[i]);
			//	}

			//	pos *= _Scale;
			//	pos -= _HalfSize;

			//	int flagIndex = 0;

			//	for (i = 0; i < 8; i++) {
			//		if (cubeValue[i] <= _Threashold) {
			//			flagIndex |= (1 << i);
			//		}
			//	}

			//	int edgeFlags = cubeEdgeFlags[flagIndex];

			//	if ((edgeFlags == 0) || (edgeFlags == 255)) {
			//		return;
			//	}

			//	float offset = 0.5;
			//	float3 vertex;
			//	for (i = 0; i < 12; i++) {
			//		if ((edgeFlags & (1 << i)) != 0) {
			//			offset = getOffset(cubeValue[edgeConnectionX[i]], cubeValue[edgeConnectionY[i]], _Threashold);

			//			vertex.x = (vertexOffsetX[edgeConnectionX[i]] + offset * edgeDirectionX[i]);
			//			vertex.y = (vertexOffsetY[edgeConnectionX[i]] + offset * edgeDirectionY[i]);
			//			vertex.z = (vertexOffsetZ[edgeConnectionX[i]] + offset * edgeDirectionZ[i]);

			//			edgeVertices[i].x = pos.x + vertex.x * _Scale;
			//			edgeVertices[i].y = pos.y + vertex.y * _Scale;
			//			edgeVertices[i].z = pos.z + vertex.z * _Scale;

			//			edgeNormals[i] = getNormal(defpos.x + vertex.x, defpos.y + vertex.y, defpos.z + vertex.z);
			//		}
			//	}

			//	int vindex = 0;
			//	int findex = 0;
			//	for (i = 0; i < 5; i++) {
			//		findex = flagIndex * 16 + 3 * i;
			//		if (triangleConnectionTable[findex] < 0)
			//			break;

			//		// Normal
			//		float3 v0 = edgeVertices[triangleConnectionTable[findex + 1]] - edgeVertices[triangleConnectionTable[findex]];
			//		float3 v1 = edgeVertices[triangleConnectionTable[findex + 2]] - edgeVertices[triangleConnectionTable[findex]];
			//		//float3 norm = normalize(cross(v0, v1));
			//		//float3 defnorm = UnityObjectToWorldNormal(normalize(cross(v0, v1)));

			//		for (j = 0; j < 3; j++) {
			//			vindex = triangleConnectionTable[findex + j];

			//			float4 ppos = mul(_Matrix, float4(edgeVertices[vindex], 1));

			//			float3 norm;
			//			norm = UnityObjectToWorldNormal(normalize(edgeNormals[vindex]));

			//			float4 lpos1 = mul(unity_WorldToObject, ppos);
			//			o.pos = UnityClipSpaceShadowCasterPos(lpos1, normalize(mul(_Matrix, float4(norm, 0))));
			//			o.pos = UnityApplyLinearShadowBias(o.pos);
			//			o.hpos = o.pos;

			//			outStream.Append(o);
			//		}
			//		outStream.RestartStrip();
			//	}
			//}

			//fixed4 frag_shadow(g2f_shadow i) : SV_Target
			//{
			//	return i.hpos.zw.x / i.hpos.zw.y;
			//}

			ENDCG
		}
	}

	FallBack "Diffuse"
}
