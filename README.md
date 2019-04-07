# Fractal-ray-tracer
real time fractal path tracer for Processing

I just uploaded these projects so people can reuse or test the code, I didn't even bother creating a local copy on my computer... 
You will notice that you will have to modify the code to use some of the functionalities, it is an experimental version and may be a bit confusing. I was just messing around and didn't planned to share my code at the beginning.

The first folder (FractalRayTracer) includes an old version of the path tracer, using a diffuse material

The second folder (FractalRayTracer2) includes a new version of the path tracer, using a glass material, mist and glow. It is a bit faster and simpler too.

For both programs, the controls are :
 - z : forward
 - s : backward
 - q : left
 - d : right
 - space : up
 - c : down
 - mouse wheel : zoom
 - mouse wheel + a : aperture
 - mouse wheel + f : focal distance
 
To change the controls (for a QWERTY keyboard for instance) change the code in the keyPressed(), keyReleased() and mouseWheel() functions. I believe I included the proper QWERTY code in the first folder.
