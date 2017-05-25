Shader "Custom/GPUMarchingCubesRenderStandardDeferredTest"
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
		_SpecularColor("Specular", Color) = ( 1,1,1,1 )
		_SpecularPower("Specular Power", Range(0,100)) = 32

		_Glossiness("Smoothness", Range(0,1)) = 0.5
		_Metallic("Metallic", Range(0,1)) = 0.0
	}

	SubShader
	{
		Tags{ "RenderType" = "Opaque" }

	CGINCLUDE
#include "HLSLSupport.cginc"
#include "UnityShaderVariables.cginc"

#define UNITY_PASS_DEFERRED
#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "UnityPBSLighting.cginc"

#include "Libs/SimplexNoise3D.cginc"
#include "Libs/MarchingCubesTables.cginc"


		struct v2g
		{
			float4 pos : SV_POSITION;
			float4 tangent : TANGENT;
			float3 normal : NORMAL;
			float4 texcoord : TEXCOORD0;
			float4 texcoord1 : TEXCOORD1;
			float4 texcoord2 : TEXCOORD2;
			float4 texcoord3 : TEXCOORD3;
			fixed4 color : COLOR;
		};

		struct g2f
		{
			//float2 uv : TEXCOORD0;
			float4 pos		: SV_POSITION;
			//float3 normal		: NORMAL;
			float3 worldPos		: TEXCOORD0;
			float3  worldNormal	: TEXCOORD1;
#ifndef DIRLIGHTMAP_OFF
			half3  viewDir		: TEXCOORD3;
#endif
			float4 lmap			: TEXCOORD4;
#ifdef LIGHTMAP_OFF
#if UNITY_SHOULD_SAMPLE_SH
			half3 sh			: TEXCOORD5;
#endif
#else
#ifdef DIRLIGHTMAP_OFF
			float4 lmapFadePos	: TEXCOORD5;
#endif
#endif
		};

		struct ShaderData
		{
			int width;
			int height;
			int depth;
			float renderScale;
			float sampleScale;
			float threashold;
			float3 lightPos;
		};

		//int _Width;
		//int _Height;
		//int _Depth;

		//float _Scale;
		//float _SampleScale;
		//float _Threashold;

		float3 _LightPos;
		float4 _DiffuseColor;
		float4 _SpecularColor;
		float _SpecularPower;

		half _Glossiness;
		half _Metallic;
		
		StructuredBuffer<ShaderData> _ShaderData;
		
		sampler3D _MainTex;

		// simplex noise test
		//float Sample(float x, float y, float z) {
		//	return snoise(float3(x + _Time.y, y, z) * _SampleScale);	// test
		//}

		float Sample(float x, float y, float z) {
			
			float4 uv = float4(x / _ShaderData[0].width, y / _ShaderData[0].height, z / _ShaderData[0].depth, 0) * _ShaderData[0].sampleScale;
			//if (distance(uv.xyz, float3(0.5, 0.5, 0.5)) < 0.25) return 0;	// 中心部だけくり抜き

			float4 c = tex3Dlod(_MainTex, uv);
			return c.r;			
		}

		float3 GetPosition(uint id) {
			float3 pos;
			pos.x = (float)(id % _ShaderData[0].width);
			pos.y = (float)((id / _ShaderData[0].width) % _ShaderData[0].height);
			pos.z = (float)((id / (_ShaderData[0].width * _ShaderData[0].height)) % _ShaderData[0].depth);
			return pos;
		}

		v2g vert(uint id : SV_VertexID)
		{
			float3 pos = GetPosition(id);

			v2g o = (v2g)0;
			o.pos = float4(pos, 1);
			return o;
		}

		// ジオメトリシェーダ
		[maxvertexcount(18)]
		void geom(point v2g input[1], inout TriangleStream<g2f> outStream)
		{
			g2f o = (g2f)0;

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
				float3(0, 0, 0)};
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

			for (i = 0; i < 8; i++) {
				cubeValue[i] = Sample(
					pos.x + vertexOffsetX[i],
					pos.y + vertexOffsetY[i],
					pos.z + vertexOffsetZ[i]);
			}

			pos *= _ShaderData[0].renderScale;

			int flagIndex = 0;

			for (i = 0; i < 8; i++) {
				if (cubeValue[i] <= _ShaderData[0].threashold) {
					flagIndex |= (1 << i);
				}
			}

			int edgeFlags = cubeEdgeFlags[flagIndex];

			if ((edgeFlags == 0)||(edgeFlags == 255)) {
				return;
			}

			float offset = 0.5;
			for (i = 0; i < 12; i++) {
				if ((edgeFlags & (1 << i)) != 0) {
					edgeVertices[i].x = pos.x + (vertexOffsetX[edgeConnectionX[i]] + offset * edgeDirectionX[i]) * _ShaderData[0].renderScale;
					edgeVertices[i].y = pos.y + (vertexOffsetY[edgeConnectionX[i]] + offset * edgeDirectionY[i]) * _ShaderData[0].renderScale;
					edgeVertices[i].z = pos.z + (vertexOffsetZ[edgeConnectionX[i]] + offset * edgeDirectionZ[i]) * _ShaderData[0].renderScale;
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
				float3 norm = UnityObjectToWorldNormal(normalize(cross(v0, v1)));
				//o.worldNormal = UnityObjectToWorldNormal(v.normal);

				for (j = 0; j < 3; j++) {
					vindex = triangleConnectionTable[findex + j];

					//o.worldPos = float4(edgeVertices[vindex], 1);
					o.worldPos = mul(unity_ObjectToWorld, float4(edgeVertices[vindex],1)).xyz;
					o.pos = UnityObjectToClipPos(o.worldPos);
					o.worldNormal = norm;
					//o.worldNormal = UnityObjectToWorldNormal(normalize(cross(v0, v1)));
					//o.worldNormal = float3(norm.x, norm.y, norm.z);

#ifndef DIRLIGHTMAP_OFF
					o.viewDir = UnityWorldSpaceViewDir(o.worldPos);
#endif

#ifndef DYNAMICLIGHTMAP_OFF
					o.lmap.zw = v.texcoord2.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
#else
					o.lmap.zw = 0;
#endif

#ifndef LIGHTMAP_OFF
					o.lmap.xy = v.texcoord1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
#ifdef DIRLIGHTMAP_OFF
					o.lmapFadePos.xyz = (mul(unity_ObjectToWorld, v.vertex).xyz - unity_ShadowFadeCenterAndType.xyz) * unity_ShadowFadeCenterAndType.w;
					o.lmapFadePos.w = (-UnityObjectToViewPos(v.vertex).z) * (1.0 - unity_ShadowFadeCenterAndType.w);
#endif
#else
					o.lmap.xy = 0;
#if UNITY_SHOULD_SAMPLE_SH
					o.sh = 0;
					o.sh = ShadeSHPerVertex(o.worldNormal, o.sh);
#endif
#endif
					outStream.Append(o);
				}
				outStream.RestartStrip();
			}
		}

		void surf(g2f IN, inout SurfaceOutputStandard o)
		{
			//fixed4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;
			o.Albedo = _DiffuseColor.rgb;
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			o.Alpha = _DiffuseColor.a;
		}

		//fixed4 frag(g2f i) : SV_Target
		void frag(g2f i,
			out half4 outDiffuse        : SV_Target0,
			out half4 outSpecSmoothness : SV_Target1,
			out half4 outNormal			: SV_Target2,
			out half4 outEmission		: SV_Target3)
		{

			float3 worldPos = i.worldPos;
			fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));

			//SurfaceOutputStandard o = (SurfaceOutputStandard)0;
			SurfaceOutputStandard o;
			UNITY_INITIALIZE_OUTPUT(SurfaceOutputStandard, o);
			o.Albedo = 0.0;
			o.Emission = 0.0;
			o.Alpha = 0.0;
			o.Occlusion = 1.0;
			o.Normal = i.worldNormal;

			surf(i, o);

			UnityGI gi;
			UNITY_INITIALIZE_OUTPUT(UnityGI, gi);
			gi.indirect.diffuse = 0;
			gi.indirect.specular = 0;
			gi.light.color = 0;
			gi.light.dir = half3(0, 1, 0);
			gi.light.ndotl = LambertTerm(o.Normal, gi.light.dir);

			UnityGIInput giInput;
			UNITY_INITIALIZE_OUTPUT(UnityGIInput, giInput);
			giInput.light = gi.light;
			giInput.worldPos = worldPos;
			giInput.worldViewDir = worldViewDir;
			giInput.atten = 1;

#if defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON)
			giInput.lightmapUV = i.lmap;
#else
			giInput.lightmapUV = 0.0;
#endif

#if UNITY_SHOULD_SAMPLE_SH
			giInput.ambient = i.sh;
#else
			giInput.ambient.rgb = 0.0;
#endif

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

			outEmission = LightingStandard_Deferred(o, worldViewDir, gi, outDiffuse, outSpecSmoothness, outNormal);
#ifndef UNITY_HDR_ON
			outEmission.rgb = exp2(-outEmission.rgb);
#endif

			UNITY_OPAQUE_ALPHA(outDiffuse.a);

			// sample the texture
			//fixed4 col = tex2D(_MainTex, i.uv);

			//float3 lightDir = normalize(_LightPos.xyz - i.worldPos.xyz);
			//float3 eyeDir = normalize(_WorldSpaceCameraPos.xyz - mul(unity_ObjectToWorld, i.worldPos).xyz);
			//float3 halfDir = normalize(lightDir + eyeDir);

			//half3 normal = i.normal.xyz;

			//float diffStrength = abs(dot(normal, lightDir));
			//float specStrength = abs(dot(normal, halfDir));

			//float3 diffuse = diffStrength * _DiffuseColor.rgb;
			//float3 specular = pow(specStrength, _SpecularPower) * _SpecularColor.rgb;

			//fixed4 col;
			//col.rgb = diffuse + specular;
			//col.a = 1;
			//return col;
		}
	ENDCG


		Pass
		{
			//Tags{ "LightMode" = "ForwardBase" }
			Tags{ "LightMode" = "Deferred" }

			//Cull off
			CGPROGRAM
			#pragma target 5.0
			#pragma vertex vert
			#pragma geometry geom
			#pragma fragment frag
			#pragma exclude_renderers nomrt
			#pragma multi_compile_prepassfinal
			#pragma skip_variants FOG_LINEAR FOG_EXP FOG_EXP2
			ENDCG
		}

	}

	FallBack "Diffuse"
}
