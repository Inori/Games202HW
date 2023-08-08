#ifdef GL_ES
precision mediump float;
#endif

// Phong related variables
uniform sampler2D uSampler;
uniform vec3 uKd;
uniform vec3 uKs;
uniform vec3 uLightPos;
uniform vec3 uCameraPos;
uniform vec3 uLightIntensity;

varying highp vec2 vTextureCoord;
varying highp vec3 vFragPos;
varying highp vec3 vNormal;

// Shadow map related variables
#define NUM_SAMPLES 20
#define BLOCKER_SEARCH_NUM_SAMPLES NUM_SAMPLES
#define PCF_NUM_SAMPLES NUM_SAMPLES
#define NUM_RINGS 10
#define LIGHT_SIZE 20.0

#define EPS 1e-3
#define PI 3.141592653589793
#define PI2 6.283185307179586

uniform sampler2D uShadowMap;

varying vec4 vPositionFromLight;

highp float rand_1to1(highp float x ) { 
  // -1 -1
  return fract(sin(x)*10000.0);
}

highp float rand_2to1(vec2 uv ) { 
  // 0 - 1
	const highp float a = 12.9898, b = 78.233, c = 43758.5453;
	highp float dt = dot( uv.xy, vec2( a,b ) ), sn = mod( dt, PI );
	return fract(sin(sn) * c);
}

float unpack(vec4 rgbaDepth) {
    const vec4 bitShift = vec4(1.0, 1.0/256.0, 1.0/(256.0*256.0), 1.0/(256.0*256.0*256.0));
    return dot(rgbaDepth, bitShift);
}

vec2 poissonDisk[NUM_SAMPLES];

void poissonDiskSamples( const in vec2 randomSeed ) {

  float ANGLE_STEP = PI2 * float( NUM_RINGS ) / float( NUM_SAMPLES );
  float INV_NUM_SAMPLES = 1.0 / float( NUM_SAMPLES );

  float angle = rand_2to1( randomSeed ) * PI2;
  float radius = INV_NUM_SAMPLES;
  float radiusStep = radius;

  for( int i = 0; i < NUM_SAMPLES; i ++ ) {
    poissonDisk[i] = vec2( cos( angle ), sin( angle ) ) * pow( radius, 0.75 );
    radius += radiusStep;
    angle += ANGLE_STEP;
  }
}

// return sample point in unit sphere
void uniformDiskSamples( const in vec2 randomSeed ) {

  float randNum = rand_2to1(randomSeed);
  float sampleX = rand_1to1( randNum ) ;
  float sampleY = rand_1to1( sampleX ) ;

  float angle = sampleX * PI2;
  float radius = sqrt(sampleY);

  for( int i = 0; i < NUM_SAMPLES; i ++ ) {
    poissonDisk[i] = vec2( radius * cos(angle) , radius * sin(angle)  );

    sampleX = rand_1to1( sampleY ) ;
    sampleY = rand_1to1( sampleX ) ;

    angle = sampleX * PI2;
    radius = sqrt(sampleY);
  }
}


float useShadowMap(sampler2D shadowMap, vec4 shadowCoord){
  // interpolate coord
  float shadowU = (shadowCoord.x + 1.0) * 0.5;
  float shadowV = (shadowCoord.y + 1.0) * 0.5;
  vec2 uv = vec2(shadowU, shadowV);

  // blocker to light
  float depth = unpack(texture2D(shadowMap, uv));
  // viewport to ndc
  float distanceBlocker = depth * 2.0 - 1.0;

  // shading point to light 
  float distanceShPoint = shadowCoord.z;
  // depth bias
  float bias = 0.01;
  return distanceShPoint + EPS > distanceBlocker + bias? 0.0 : 1.0;
}


float PCF(sampler2D shadowMap, vec4 coords) {
  vec3 shadowCoordNDC = (vPositionFromLight.xyz / vPositionFromLight.w + 1.0) / 2.0;
  // interpolate coord

  vec2 uv = shadowCoordNDC.xy;

  const float pixelRadius = 10.0;
  const float resolution = 2048.0;
  
  // generate random values
  //uniformDiskSamples(uv);
  

  float inShadowSum = 0.0;
  for (int i = 0; i != PCF_NUM_SAMPLES; i += 1)
  {
    // random uv
    vec2 randomUV = uv + (pixelRadius / resolution) * poissonDisk[i];
    // blocker to light
    float depth = unpack(texture2D(shadowMap, randomUV));
    // viewport to ndc
    //float distanceBlocker = depth * 2.0 - 1.0;
    float distanceBlocker = depth;

    // shading point to light 
    float distanceShPoint = shadowCoordNDC.z;
    // depth bias
    float bias = 0.01;
    // count in shadow
    float inShadow = distanceShPoint + EPS > distanceBlocker + bias? 1.0 : 0.0;
    inShadowSum += inShadow;
  }

  float visibility = 1.0 - inShadowSum / float(PCF_NUM_SAMPLES);
  return visibility;
}

float findBlocker( sampler2D shadowMap,  vec2 uv, float zReceiver ) {
	 // blocker to light
  float depth = unpack(texture2D(shadowMap, uv));
  // viewport to ndc
  float zBlocker = depth * 2.0 - 1.0;
  // depth bias
  //float bias = 0.01;
  //
  // bool inShadow = zReceiver + EPS > zBlocker + bias;
  // if (!inShadow)
  // {
  //   return 0.0;
  // }

  const float pixelRadius = 10.0;
  const float resolution = 2048.0;

  float zBlockerSum = 0.0;
  for (int i = 0; i != BLOCKER_SEARCH_NUM_SAMPLES; i += 1)
  {
    // random uv
    vec2 randomUV = uv + (pixelRadius / resolution) * poissonDisk[i];
    // blocker to light
    float depthBlocker = unpack(texture2D(shadowMap, randomUV));
    //
    zBlockerSum += depthBlocker;
  }

  float zBlockerAvg = zBlockerSum / float(BLOCKER_SEARCH_NUM_SAMPLES);
  return zBlockerAvg;
}

float PCSS(sampler2D shadowMap, vec4 coords){

  // interpolate coord
  float shadowU = (coords.x + 1.0) * 0.5;
  float shadowV = (coords.y + 1.0) * 0.5;
  vec2 uv = vec2(shadowU, shadowV);

  // generate random values
  uniformDiskSamples(uv);

  float depthShPoint = coords.z;

  // STEP 1: avgblocker depth
  float depthBockerAvg = findBlocker(shadowMap, uv, depthShPoint);
  depthBockerAvg = depthBockerAvg * 2.0 - 1.0;
  if (abs(depthShPoint - depthBockerAvg) < 0.01)
  {
    return 1.0;
  }

  // STEP 2: penumbra size
  float penumbraSize = ((depthShPoint - depthBockerAvg) / (depthBockerAvg + EPS)) * LIGHT_SIZE;

  // STEP 3: filtering
  const float resolution = 2048.0;
  float pixelRadius = penumbraSize / 2.0;

  float inShadowSum = 0.0;
  for (int i = 0; i != PCF_NUM_SAMPLES; i += 1)
  {
    // random uv
    vec2 randomUV = uv + (pixelRadius / resolution) * poissonDisk[i];
    // blocker to light
    float depth = unpack(texture2D(shadowMap, randomUV));
    // viewport to ndc
    float distanceBlocker = depth * 2.0 - 1.0;
    // depth bias
    float bias = 0.01;
    // count in shadow
    float inShadow = depthShPoint + EPS > distanceBlocker + bias? 1.0 : 0.0;
    inShadowSum += inShadow;
  }

  float visibility = 1.0 - inShadowSum / float(PCF_NUM_SAMPLES);
  return visibility;
}


vec3 blinnPhong() {
  vec3 color = texture2D(uSampler, vTextureCoord).rgb;
  color = pow(color, vec3(2.2));

  vec3 ambient = 0.05 * color;

  vec3 lightDir = normalize(uLightPos);
  vec3 normal = normalize(vNormal);
  float diff = max(dot(lightDir, normal), 0.0);
  vec3 light_atten_coff =
      uLightIntensity / pow(length(uLightPos - vFragPos), 2.0);
  vec3 diffuse = diff * light_atten_coff * color;

  vec3 viewDir = normalize(uCameraPos - vFragPos);
  vec3 halfDir = normalize((lightDir + viewDir));
  float spec = pow(max(dot(halfDir, normal), 0.0), 32.0);
  vec3 specular = uKs * light_atten_coff * spec;

  vec3 radiance = (ambient + diffuse + specular);
  vec3 phongColor = pow(radiance, vec3(1.0 / 2.2));
  return phongColor;
}

void main(void) {
  poissonDiskSamples(vTextureCoord);
  float visibility = 0.0;

  //visibility = useShadowMap(uShadowMap, vPositionFromLight);
  visibility = PCF(uShadowMap, vPositionFromLight);
  //visibility = PCSS(uShadowMap, vPositionFromLight);

  vec3 phongColor = blinnPhong();

  gl_FragColor = vec4(phongColor * visibility, 1.0);
}