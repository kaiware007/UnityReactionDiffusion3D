Shader "Custom/GPUMarchingCubesRender"
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
	}

	CGINCLUDE
#include "UnityCG.cginc"
//#include "AutoLight.cginc"
#include "Libs/SimplexNoise3D.cginc"
#include "Libs/MarchingCubesTables.cginc"

		struct v2g
		{
			float4 vertex : SV_POSITION;
		};

		struct g2f
		{
			//float2 uv : TEXCOORD0;
			float4 vertex	: SV_POSITION;
			float3 normal   : NORMAL;
			float4 worldPos : TEXCOORD0;
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

		sampler3D _MainTex;

		// simplex noise test
		//float Sample(float x, float y, float z) {
		//	return snoise(float3(x + _Time.y, y, z) * _SampleScale);	// test
		//}

		float Sample(float x, float y, float z) {
			
			float4 uv = float4(x / _Width, y / _Height, z / _Depth, 0) * _SampleScale;
			//if (distance(uv.xyz, float3(0.5, 0.5, 0.5)) < 0.25) return 0;	// 中心部だけくり抜き

			float4 c = tex3Dlod(_MainTex, uv);
			return c.r;			
		}

		float3 GetPosition(uint id) {
			float3 pos;
			pos.x = (float)(id % _Width);
			pos.y = (float)((id / _Width) % _Height);
			pos.z = (float)((id / (_Width * _Height)) % _Depth);
			return pos;
		}

		v2g vert(uint id : SV_VertexID)
		{
			float3 pos = GetPosition(id);

			v2g o = (v2g)0;
			o.vertex = float4(pos, 1);
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

			float3 pos = input[0].vertex.xyz;

			for (i = 0; i < 8; i++) {
				cubeValue[i] = Sample(
					pos.x + vertexOffsetX[i],
					pos.y + vertexOffsetY[i],
					pos.z + vertexOffsetZ[i]);
			}

			pos *= _Scale;

			int flagIndex = 0;

			for (i = 0; i < 8; i++) {
				if (cubeValue[i] <= _Threashold) {
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

					o.worldPos = float4(edgeVertices[vindex], 1);
					o.vertex = UnityObjectToClipPos(o.worldPos);
					o.normal = norm;

					outStream.Append(o);
				}
				outStream.RestartStrip();
			}
		}

		fixed4 frag(g2f i) : SV_Target
		{
			// sample the texture
			//fixed4 col = tex2D(_MainTex, i.uv);

			float3 lightDir = normalize(_LightPos.xyz - i.worldPos.xyz);
			float3 eyeDir = normalize(_WorldSpaceCameraPos.xyz - mul(unity_ObjectToWorld, i.worldPos).xyz);
			float3 halfDir = normalize(lightDir + eyeDir);

			half3 normal = i.normal.xyz;

			float diffStrength = abs(dot(normal, lightDir));
			float specStrength = abs(dot(normal, halfDir));

			float3 diffuse = diffStrength * _DiffuseColor.rgb;
			float3 specular = pow(specStrength, _SpecularPower) * _SpecularColor.rgb;

			fixed4 col;
			col.rgb = diffuse + specular;
			col.a = 1;
			return col;
		}
	ENDCG

	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			//Tags{ "LightMode" = "ForwardBase" }

			//Cull off
			CGPROGRAM
			#pragma target 5.0
			#pragma vertex vert
			#pragma geometry geom
			#pragma fragment frag
			ENDCG
		}

	}
}
