Shader "Hidden/Mixture/Splatter"
{	
	Properties
	{
		// By default a shader node is supposed to handle all the input texture dimension, we use a prefix to determine which one is used
		[InlineTexture]_Source_2D("Source", 2D) = "white" {}
		[InlineTexture]_Source_3D("Source", 3D) = "white" {}
		[InlineTexture]_Source_Cube("Source", Cube) = "white" {}

		_SourceCrop("Source Crop", Vector) = (0, 0, 0, 0)

		[Enum(Grid, 0, Random, 1, R2, 2, Halton, 3, FibonacciSpiral, 4)] _Sequence("Sequence", Float) = 0

		// Sequence parameters Sequance
		_SplatDensity("Splat Density", Float) = 4

		[Enum(Blend, 0, Add, 1, Sub, 2, Max, 3, Min, 4)]_Operator("Operator", Float) = 0
	}

	CGINCLUDE
	
	#include "Packages/com.alelievr.mixture/Runtime/Shaders/MixtureFixed.cginc"

	#pragma target 3.0
	// The list of defines that will be active when processing the node with a certain dimension
	#pragma shader_feature CRT_2D
	#pragma vertex CustomRenderTextureVertexShader
	#pragma fragment mixture

	TEXTURE_SAMPLER_X(_Source);
	float4 _SourceCrop;
	float _SplatDensity;
	float _Sequence;
	float _Operator;

	ENDCG

	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			Name "Splatter"

			CGPROGRAM

			float4 SampleSplat(float3 uv)
			{
				// Source crop:
				if (any(uv.xy > 1 - _SourceCrop.zw) || any(uv.xy < _SourceCrop.xy))
					return 0;

				// TODO: handle rotation

				return SAMPLE_X(_Source, uv, float3(0, 0, 0));
			}

			void AccumulateColor(inout float4 color, float4 newcolor)
			{
				switch (_Sequence)
				{
					case 0: // Blend (1 - src alpha)
						float a = newcolor.a * (1 - color.a);
						color.rgb = color.rgb * color.a + newcolor.rgb * a;
						color.a = color.a + a;
						color.rgb /= color.a;
						break;
					case 1: // Add
						color += newcolor;
						break;
					case 2: // Sub
						color -= newcolor;
						break;
					case 3: // Max
						color = max(color, newcolor);
						break;
					case 4: // Min
						color = min(color, newcolor);
						break;
				}
			}

			float4 mixture(v2f_customrendertexture i) : SV_Target
			{
				float4 color = 0;

				float2 uv = i.localTexcoord.xy;

				switch (_Sequence)
				{
					case 0: // Grid:
						uv *= _SplatDensity;
						for (int x = 0; x < _SplatDensity; x++)
						{
							for (int y = 0; y < _SplatDensity; y++)
							{
								float2 uv2 = frac(uv) + float2(x, y) * rcp(_SplatDensity);
								AccumulateColor(color, SampleSplat(float3(uv2, 0)));
							}
						}
						break;
					case 1:
						break;
				}
				return color;
			}
			ENDCG
		}
	}
}