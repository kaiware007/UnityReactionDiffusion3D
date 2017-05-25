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
		_SpecularColor("Specular", Color) = ( 1,1,1,1 )
		_SpecularPower("Specular Power", Range(0,100)) = 32

		_Glossiness("Smoothness", Range(0,1)) = 0.5
		_Metallic("Metallic", Range(0,1)) = 0.0
	}

	SubShader
	{
		Tags{ "RenderType" = "Opaque" }

		Pass{
			Tags{ "LightMode" = "ForwardBase" }
			Lighting On

			CGPROGRAM
			#pragma target 5.0
			#pragma vertex vert
			#pragma geometry geom_light
			#pragma fragment frag_light
			#pragma multi_compile_fwdbase

			#include "UnityCG.cginc"
			#include "AutoLight.cginc"

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
				float4 texcoord : TEXCOORD0;
				float4 texcoord1 : TEXCOORD1;
				float4 texcoord2 : TEXCOORD2;
				float4 texcoord3 : TEXCOORD3;
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
				LIGHTING_COORDS(3, 4)
			};

			int _Width;
			int _Height;
			int _Depth;

			float _Scale;
			float _SampleScale;
			float _Threashold;

			float3 _LightPos;
			float4 _DiffuseColor;
			float4 _SpecularColor;
			float _SpecularPower;
			float3 _HalfSize;
			float4x4 _Matrix;

			half _Glossiness;
			half _Metallic;

			sampler3D _MainTex;

			uniform fixed4 _LightColor0;

			// simplex noise test
			//float Sample(float x, float y, float z) {
			//	return snoise(float3(x + _Time.y, y, z) * _SampleScale);	// test
			//}

			float Sample(float x, float y, float z) {

				if ((x <= 0) || (y <= 0) || (z <= 0) || (x >= _Width) || (y >= _Height) || (z >= _Depth))
					return 0;

				float4 uv = float4(x / _Width, y / _Height, z / _Depth, 0) * _SampleScale;
				//if (distance(uv.xyz, float3(0.5, 0.5, 0.5)) < 0.25) return 0;	// 中心部だけくり抜き

				float4 c = tex3Dlod(_MainTex, uv);
				return c.r;
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
				for (i = 0; i < 12; i++) {
					if ((edgeFlags & (1 << i)) != 0) {
						edgeVertices[i].x = pos.x + (vertexOffsetX[edgeConnectionX[i]] + offset * edgeDirectionX[i]) * _Scale;
						edgeVertices[i].y = pos.y + (vertexOffsetY[edgeConnectionX[i]] + offset * edgeDirectionY[i]) * _Scale;
						edgeVertices[i].z = pos.z + (vertexOffsetZ[edgeConnectionX[i]] + offset * edgeDirectionZ[i]) * _Scale;
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
					
					for (j = 0; j < 3; j++) {
						vindex = triangleConnectionTable[findex + j];

						float4 ppos = mul(_Matrix, float4(edgeVertices[vindex], 1));
						o.pos = UnityObjectToClipPos(ppos);
						o.normal = normalize(mul(_Matrix, float4(norm,0)));

						o.lightDir = normalize(WorldSpaceLightDir(ppos));
						o.viewDir = normalize(WorldSpaceViewDir(ppos));
						TRANSFER_VERTEX_TO_FRAGMENT(o);


						outStream.Append(o);
					}
					outStream.RestartStrip();
				}
			}

			fixed4 frag_light(g2f_light i) : SV_Target
			{
				///
				float atten = LIGHT_ATTENUATION(i);
				//float atten = 1;
				fixed3 normal = i.normal;

				half3 h = normalize(i.lightDir + i.viewDir);

				fixed diff = saturate(dot(normal, i.lightDir));

				float nh = saturate(dot(normal, h));
				float spec = pow(nh, _Metallic * 32.0) * _Glossiness;

				fixed4 color;
				color.rgb = UNITY_LIGHTMODEL_AMBIENT.rgb * _DiffuseColor.rgb;
				color.rgb += (_DiffuseColor.rgb * _LightColor0.rgb * diff + _LightColor0.rgb * _SpecularColor.rgb * spec) * (atten * 2);
				color.a = _DiffuseColor.a + (_LightColor0.a * _SpecularColor.a * spec * atten);
				
				return color;
				
				///
				//float atten = LIGHT_ATTENUATION(i);
				//return _DiffuseColor * atten;	// test
			}
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

			#include "UnityCG.cginc"
			#include "AutoLight.cginc"

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
				float4 texcoord : TEXCOORD0;
				float4 texcoord1 : TEXCOORD1;
				float4 texcoord2 : TEXCOORD2;
				float4 texcoord3 : TEXCOORD3;
				fixed4 color : COLOR;
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
			float4 _SpecularColor;
			float _SpecularPower;
			float3 _HalfSize;
			float4x4 _Matrix;

			half _Glossiness;
			half _Metallic;

			sampler3D _MainTex;

			uniform fixed4 _LightColor0;

			// simplex noise test
			//float Sample(float x, float y, float z) {
			//	return snoise(float3(x + _Time.y, y, z) * _SampleScale);	// test
			//}

			float Sample(float x, float y, float z) {

				if ((x <= 0) || (y <= 0) || (z <= 0) || (x >= _Width) || (y >= _Height) || (z >= _Depth))
					return 0;

				float4 uv = float4(x / _Width, y / _Height, z / _Depth, 0) * _SampleScale;
				//if (distance(uv.xyz, float3(0.5, 0.5, 0.5)) < 0.25) return 0;	// 中心部だけくり抜き

				float4 c = tex3Dlod(_MainTex, uv);
				return c.r;
			}

			v2g vert(appdata v)
			{
				v2g o = (v2g)0;
				o.pos = v.vertex;
				return o;
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
				for (i = 0; i < 12; i++) {
					if ((edgeFlags & (1 << i)) != 0) {
						edgeVertices[i].x = pos.x + (vertexOffsetX[edgeConnectionX[i]] + offset * edgeDirectionX[i]) * _Scale;
						edgeVertices[i].y = pos.y + (vertexOffsetY[edgeConnectionX[i]] + offset * edgeDirectionY[i]) * _Scale;
						edgeVertices[i].z = pos.z + (vertexOffsetZ[edgeConnectionX[i]] + offset * edgeDirectionZ[i]) * _Scale;
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
					float3 norm = normalize(cross(v0, v1));
					
					for (j = 0; j < 3; j++) {
						vindex = triangleConnectionTable[findex + j];

						float4 ppos = mul(_Matrix, float4(edgeVertices[vindex], 1));

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
		}
	}

	FallBack "Diffuse"
}
