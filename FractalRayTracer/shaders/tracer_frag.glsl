#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

//I didn't know where to put these so I kept them as constants in the shader
const int MAX_STEPS = 2000;			//maximum number of ray steps before considering the ray hit the shape
const float MAX_DIST = 20;			//radius of the "rendering sphere"
const float STEP_FACTOR = .95;	//amount of the distance to the fractal each step does, keep it under 1
const int MAX_STEP_TRIES = 20;	//number of tries when stepping outside of the shape after hitting it (for shadow rays)
const float EPSILON = .0000002;	//small value so the ray doesn't get stuck because the step size is rounded to 0 by the floating point precision

//idk if there's already a variable in glsl, just used this for trigonometry
const float PI = 3.14159265359;

//dimentions of the screen
uniform int width;
uniform int height;

//seed for the noise, useful for putting a static noise to help video compression
uniform int noiseSeed;
vec2 seed;

//parameters for the camera
uniform vec3 posCam;					 //position
uniform vec3 prevPosCam;		 	 //previous position, used for motion blur
uniform vec3 dirCam;				 	 //direction
uniform vec3 prevDirCam;		 	 //previous direction, for motion blur
uniform float focalLength;		 //focal length (zoom)
uniform float prevFocalLength; //previous focal length, for motion blur
uniform float shutter;				 //time of open shutter (amount of motion blur), keep it between 0 and 1
uniform float focalDistance;	 //distance to the focal plane (focus)
uniform float aperture;				 //size of aperture, (amount of blur in the foreground and background)

//minimum and maximum for adaptive sampling (to concentrate the sampling in the noisy areas)
uniform int maxSPP;
uniform int minSPP;
int relativeSPP;

//scene parameters
uniform vec3 shapeColor;				//color of the fractal (I don't have any coloration algorithm, I prefer it this way)
uniform vec3 backgroundColor;		//color of the background
uniform bool traceDirectLight;	//disabling direct light doubles the fps
uniform vec3 dirLight;					//direct light direction
uniform vec3 lightColor;				//direct light color
uniform float lightRadius;			//direct light radius (angle of the sun)
uniform float AOFactor;					//ambiant occlusion factor
uniform float mistFactor;				//mist factor
uniform float adaptiveMinDistFactor;//adaptive minimum distance factor
uniform float detailFactor;			//detail factor
uniform int fractalType;				//specifies which fractal to render (0 -> tetrahedron, 1 -> mandelbulb)

//noise function
float rand(vec2 n) {
	return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453);
}

//random float generator
float randomFloat(){
  seed.x++;
  seed.y--;
  return rand(seed);
}

//returns the size of the focus at a point, used to keep the detail where the focus is
float focusSize(vec3 pos){
	return aperture / focalDistance * abs((focalDistance - length(pos - posCam)));
}

//adaptive minimum distance at a given position, stops a ray as soon as it is closer than this distance
float adaptiveMinDist(vec3 pos){
	float pixelSize = length(pos - posCam)/focalLength / max(width, height);
	return pixelSize/detailFactor + focusSize(pos)*adaptiveMinDistFactor + EPSILON;
}

//returns the distance to the mandelbulb fractal (fractalType 1)
float getDistanceMandelbulb(vec3 pos) {
	float Bailout = 5;
	float Power = 8;
	int Iterations = 50;
	if(length(pos) > 1.3) return length(pos) - 1.2; //optimisation for when the ray is out of a sphere containing the mandelbulb
	vec3 z = pos;
	float dr = 1.0;
	float r = 0.0;
	for (int i = 0; i < Iterations ; i++) {
		r = length(z);
		if (r>Bailout) break;
		float theta = acos(z.z/r);
		float phi = atan(z.y,z.x);
		dr =  pow( r, Power-1.0)*Power*dr + 1.0;
		float zr = pow( r,Power);
		theta = theta*Power;
		phi = phi*Power;
		z = zr*vec3(sin(theta)*cos(phi), sin(phi)*sin(theta), cos(theta));
		z+=pos;
	}
	return 0.5*log(r)*r/dr;
}

//returns the distance to the tetrahedron fractal (fractalType 0)
float getDistanceTetrahedron(vec3 pos){
	float iterations = log(1/adaptiveMinDist(pos))/log(2); //adaptive iterations to preserve details in focus
	float scale = 2;
	vec3 offset = vec3(1, 1, 1);
	float melt = 5;
	for(int i = 0; i < int(iterations); i++){
		if(pos.x+pos.y < 0) pos = vec3(-pos.yx, pos.z);
		if(pos.x+pos.z < 0) pos = vec3(-pos.z, pos.y, -pos.x);
		if(pos.y+pos.z < 0) pos = vec3(pos.x, -pos.z, -pos.y);
		pos = pos*scale - offset*(scale-1);
	}
	float diam = melt / pow(2, iterations);
	return length(pos) * pow(scale, int(-iterations)) - diam;
}

//returns the distance to the choosen fractal
float getDistance(vec3 pos){
	if(fractalType == 0) return getDistanceTetrahedron(pos);
	else return getDistanceMandelbulb(pos);
}


//returns the normal to the fractal at a point
vec3 getNormal(vec3 pos, float p){
float normalSmooth = 1;
  vec3 xDir = vec3(p, 0, 0) * normalSmooth;
  vec3 yDir = vec3(0, p, 0) * normalSmooth;
  vec3 zDir = vec3(0, 0, p) * normalSmooth;

  float normalX = getDistance(pos + xDir)
                - getDistance(pos - xDir);
  float normalY = getDistance(pos + yDir)
                - getDistance(pos - yDir);
  float normalZ = getDistance(pos + zDir)
                - getDistance(pos - zDir);

  return normalize(vec3(normalX, normalY, normalZ));
}

//traces a ray
bool trace(in vec3 pos, in vec3 dir, out int nbSteps, out float minAngle, out vec3 hitPos, out vec3 hitNormal){
	vec3 posBefore = pos;
	minAngle = PI;
	dir = normalize(dir);
  int steps = 0;
	float amd;
  while(steps < MAX_STEPS && length(pos) < MAX_DIST){
    float distance = getDistance(pos);
		amd = adaptiveMinDist(pos);
    if(abs(distance) <= amd){
      hitPos = pos;
			nbSteps = steps;
      hitNormal = getNormal(pos, amd);
      return true;
    }
		float currentAngle = atan(distance - amd, length(pos - posBefore));
		if(currentAngle < minAngle) minAngle = currentAngle;
    pos = pos + dir * (STEP_FACTOR * distance);
    steps++;
  }
	if(steps >= MAX_STEPS){
		nbSteps = steps;
		hitPos = pos;
		hitNormal = getNormal(pos, amd);
		return true;
	} else {
		return false;
	}
}

//marches the ray just outside the fractal (to trace a shadow ray)
vec3 stepOutside(vec3 pos, vec3 normal){
	vec3 posBefore = pos;
	float amd = adaptiveMinDist(pos);
	vec3 delta = normal * amd;
	int tries = 0;
	bool inverted = false;
	if(getDistance(pos) < amd){
		pos += delta;
		tries++;
		if(tries > MAX_STEP_TRIES){
			if(inverted) return posBefore;
			delta *= -1; //tries the other way, in case of bad normal
			pos = posBefore;
			tries = 0;
			inverted = true;
		}
	}
	return pos;
}

//returns the color of the given ray
vec3 getColorOfRay(vec3 pos, vec3 dir){
	vec3 hitPos;
	vec3 hitNormal;
	int nbSteps;
	float maxAngle = atan(aperture, focalDistance);
	float minAngle;
	if(trace(pos, dir, nbSteps, minAngle, hitPos, hitNormal)){
		float angle = min(atan(focusSize(hitPos), length(hitPos - posCam)), maxAngle);
		relativeSPP = minSPP + int((maxSPP - minSPP) * angle/maxAngle);
		vec3 placeHolderVec;
		int placeHolderInt;
		vec3 directLight;
		if(traceDirectLight){
			vec3 posOutside = stepOutside(hitPos, hitNormal);
			if(!trace(posOutside, -dirLight, placeHolderInt, minAngle, placeHolderVec, placeHolderVec)){
				float lightAmount = min(1, minAngle/lightRadius);
				directLight = lightColor * max(dot(hitNormal, -dirLight), 0) * lightAmount;
			}
		}
		float OAAmount = pow(.5, nbSteps*AOFactor);
		float mistAmount = 1-pow(.5, length(hitPos-posCam)*mistFactor);
		vec3 finalColor =  (shapeColor * backgroundColor + shapeColor * directLight) * OAAmount;
		finalColor = finalColor * (1-mistAmount) + backgroundColor * mistAmount;
		return finalColor;
	} else {
		if(minAngle > maxAngle) relativeSPP = minSPP;
		return backgroundColor;
	}
}

//samples a ray using the camera settings
vec3 getSample(){

	//linear interpolation for motion blur
	float interpolationFactor = randomFloat() * shutter;
	vec3 pos = interpolationFactor * posCam + (1-interpolationFactor) * prevPosCam;
	vec3 dir = interpolationFactor * dirCam + (1-interpolationFactor) * prevDirCam;
	float interpolatedFocalLength = interpolationFactor * focalLength + (1-interpolationFactor) * prevFocalLength;

	//coodinates on the screen
	vec2 coords = (gl_FragCoord.xy - vec2(width+randomFloat(), height+randomFloat())/2) / max(width, height);

	vec3 camX = vec3(-dir.y, dir.x, 0);
	vec3 camY = cross(camX, dir);
	vec3 sensorX = camX * (coords.x/length(camX));
	vec3 sensorY = camY * (coords.y/length(camY));
	vec3 centerSensor = pos - dir * interpolatedFocalLength;
	vec3 posOnSensor = centerSensor + sensorX + sensorY;

	vec3 posInFocus = pos + (pos - posOnSensor) * (focalDistance / length(pos - posOnSensor));

	float angle = randomFloat() * 2*PI - PI;
	float radius = aperture*sqrt(randomFloat());

	float xAperture = radius * cos(angle);
	float yAperture = radius * sin(angle);

	vec3 vecAperture = camX * (xAperture / length(camX)) + camY * (yAperture / length(camY));
	vec3 eyePlusAperture = pos + vecAperture;
	vec3 newDir = normalize(posInFocus - eyePlusAperture);

	return getColorOfRay(eyePlusAperture, newDir);
}


//main of the shader
void main() {
	seed.x = noiseSeed * .0178552;
  seed.y = (gl_FragCoord.y * width + gl_FragCoord.x) * .001651861;

	vec3 sumColor = vec3(0, 0, 0);
	relativeSPP = maxSPP;
	int SPP = 0;
	while(SPP < relativeSPP){
		sumColor += getSample();
		SPP++;
	}

	gl_FragColor = vec4(sumColor / SPP, 1);
}
