Shader "DZL/CloudLayer"
{
    Properties
    {
        _UseQuadMesh ("Use Quad Mesh ?", Range(0, 1)) = 0
        [NoScaleOffset]_FrontMap ("Front Map", 2D) = "white" { }
        [NoScaleOffset]_BackMap ("Front Map", 2D) = "white" { }
        _YRotation ("Texture Rotation", Range(0, 360)) = 180
        _Density ("Absorption", Range(1, 20)) = 1

        _WindOrientation ("Wind Orientation", Range(0, 360)) = 0
        _WindSpeed ("Wind Speed", Float) = 10
    }

    HLSLINCLUDE
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    ENDHLSL

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "Queue"="Transparent" "IgnoreProjector"="True"}

        Pass
        {
            Tags { "LightMode" = "UniversalForward" "RenderType" = "Transparent" }
            Blend SrcAlpha OneMinusSrcAlpha
            // Blend One One

            HLSLPROGRAM

            #pragma target 4.0
            #pragma vertex VERT
            #pragma fragment FRAG

            #pragma multi_compile_fog

            #include "CloudLayer.hlsl"

            v2f VERT(a2v i)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(i.position.xyz);
                o.posWS      = TransformObjectToWorld(i.position.xyz);
                o.texcoord   = i.texCoord.xy;
                return o;
            }
            
            real4 FRAG(v2f i): SV_TARGET
            {
                Light mainLight = GetMainLight();

                float3 LightDir = normalize(mainLight.direction);
                float3 ViewDir = normalize(_WorldSpaceCameraPos.xyz - i.posWS.xyz);
                
                LightDir = RotateAroundYInDegrees(LightDir, _YRotation);

                float HGPhase = PhaseHG(0.8, dot(LightDir, ViewDir));

                float3 RigRTBk; 
                float3 RigLBtF;

                if (_UseQuadMesh > 0.5)
                { 

                    float  Altitude        = 2000;
                    float3 PanoPosition    = GetCloudVolumeIntersection(0, -ViewDir);
                    float  ScrollDist      = 2 * Altitude;                                                                     // max horizontal distance clouds can travel, arbitrary but looks good
                    float2 PanoAlpha       = frac(_WindSpeed * _Time.y * 10 / ScrollDist + float2(0.0, 0.5)) - 0.5;
                    float3 ScrollDirection = DegToOrientation(_WindOrientation);
                    float3 Delta           = float3(ScrollDirection.x, 0.0f, ScrollDirection.y);
                    float4 CloudFront1     = SampleCloudFrontMap(normalize(PanoPosition + PanoAlpha.x * Delta * ScrollDist));
                    float4 CloudFront2     = SampleCloudFrontMap(normalize(PanoPosition + PanoAlpha.y * Delta * ScrollDist));
                    float4 CloudBack1      = SampleCloudBackMap(normalize(PanoPosition + PanoAlpha.x * Delta * ScrollDist));
                    float4 CloudBack2      = SampleCloudBackMap(normalize(PanoPosition + PanoAlpha.y * Delta * ScrollDist));
                           RigRTBk         = lerp(CloudFront1.xyz, CloudFront2.xyz, abs(2.0 * PanoAlpha.x));
                           RigLBtF         = lerp(CloudBack1.xyz, CloudBack2.xyz, abs(2.0 * PanoAlpha.x));
                }
                else
                {
                    RigRTBk = SAMPLE_TEXTURE2D(_FrontMap, sampler_linear_repeat, i.texcoord).rgb;
                    RigLBtF = SAMPLE_TEXTURE2D(_BackMap, sampler_linear_repeat, i.texcoord).rgb;
                }

                float3 Weights                  = LightDir > 0 ? RigRTBk.xyz : RigLBtF.xyz;
                float3 SqrDir                   = LightDir * LightDir;
                float  Transmission             = dot(SqrDir, Weights);

                float Opacity = pow(RigLBtF.y, 6);
                Opacity = ViewDir.y < 0 ? Opacity : 0;
                Opacity = saturate(Opacity * 0.1 * i.posWS.y);

                float3 DirectDiffuse      = exp(-1.0f * (1 - Transmission) * _Density) * mainLight.color;
                float3 RimEnhance         = min(pow(RigRTBk.z, 8), pow(Transmission, 8)) * HGPhase * mainLight.color * 3;

                       DirectDiffuse     += RimEnhance;
                       DirectDiffuse.rgb  = MixFog(DirectDiffuse.rgb, 0.5);

                    //    DirectDiffuse = RimEnhance2;
                    DirectDiffuse = ViewDir.y < 0 ? DirectDiffuse : 0;
                
                return float4(DirectDiffuse, Opacity);
            }

            ENDHLSL

        }
    }
}