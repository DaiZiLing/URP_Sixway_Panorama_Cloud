
float    _Density;
float    _WindOrientation;
float    _WindSpeed;
float    _YRotation;
float    _UseQuadMesh;

TEXTURE2D(_FrontMap);
TEXTURE2D(_BackMap);

SAMPLER(sampler_linear_repeat);

struct a2v
{
    float4 position:     POSITION;
    float2 texCoord:     TEXCOORD;
};

struct v2f
{
    float4 positionCS:     SV_POSITION;
    float3 posWS:          TEXCOORD0;
    float2 texcoord:       TEXCOORD1;
};

// ----------------------------------------------------------
// Helper Function Ported From HDRP Start
// ----------------------------------------------------------

float2 IntersectSphere ( float sphereRadius , float cosChi , float radialDistance , float rcpRadialDistance )
{

    float d = Sq ( sphereRadius * rcpRadialDistance ) - saturate ( 1 - cosChi * cosChi ) ;

    return ( d < 0 ) ? d : ( radialDistance * float2 ( - cosChi - sqrt ( d ) ,
    - cosChi + sqrt ( d ) ) ) ;
}

float2 IntersectSphere ( float sphereRadius , float cosChi , float radialDistance )
{
    return IntersectSphere ( sphereRadius , cosChi , radialDistance , rcp ( radialDistance ) ) ;
}


float3 GetCloudVolumeIntersection(int index, float3 Dir)
{
    const float _EarthRadius = 6378100.0f;
    return Dir * -IntersectSphere(2000.0 + _EarthRadius, -Dir.y, _EarthRadius).x;
}

float3 DegToOrientation(float Deg)
{
    float Rad = 2 * PI * Deg / 360.0;
    return float3(cos(Rad), sin(Rad), 0.0);
}

float3 RotateAroundYInDegrees (float3 V, float degrees)
{
    float alpha = degrees * PI / 180.0;
    float sina, cosa;
    sincos(alpha, sina, cosa);
    float2x2 m = float2x2(cosa, -sina, sina, cosa);
    return float3(mul(m, V.xz), V.y).xzy;
}

float2 GetLatLongCoords ( float3 Dir , float UpperHemisphereOnly )
{
    Dir = RotateAroundYInDegrees(Dir, _YRotation);

    const  float2 InvAtan = float2 ( 0.1591 , 0.3183 ) ;
    float  FastATan2      = FastAtan2 ( Dir.x , Dir.z ) ;
    float2 UV             = float2 (FastATan2 , FastASin ( Dir . y ) ) * InvAtan + 0.5 ;
    UV     . y            = UpperHemisphereOnly ? UV . y * 2.0 - 1.0 : UV . y ;
    return UV ;
}

// ----------------------------------------------------------
// Helper Function Ported From HDRP END
// ----------------------------------------------------------

float4 SampleCloudFrontMap(float3 Dir)
{
    float2 Coords = GetLatLongCoords(Dir, 1.0);
    return SAMPLE_TEXTURE2D(_FrontMap, sampler_linear_repeat, Coords).rgba;
}

float4 SampleCloudBackMap(float3 Dir)
{
    float2 Coords = GetLatLongCoords(Dir, 1.0);
    return SAMPLE_TEXTURE2D(_BackMap, sampler_linear_repeat, Coords).rgba;
}

float PhaseHG(float G, float CosTheta)
{
    float G2 = G * G;

    float  Nom = 1.0f - G2;
    float  Denom = 4.0f * PI * pow(1.0f + G2 - 2.0f * G * (CosTheta), 1.5f);

    return Nom / Denom;
}
