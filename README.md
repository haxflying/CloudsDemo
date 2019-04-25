# CloudsDemo
A small demo for volumetric clouds, SDF mesh and noise based ocean  
Terrain: Houdini heighfield for heightMap, Substance designer for Texture, and Custom Shader for final result  
Clouds: Precomputed 3D woley noise and 2D cloud texture for base Shape, raytracing + downsampling + TAA for rendering  
Mesh SDF: Mesh made with Maya, samplered to SDF 3D texture and combined with 3D noise, write depth first then render with drawmesh  
Ocean: base noise algorithm from TDM shadertoy, added atmosphere scattering of sky for refelct  
GlobalFog: effect ocean by add ray plane intersection when generate worldpos from depth map, some tricky calculate for sun fade and horizontal fog  
SnowShader: edited from tszirr's implemention of "Real-time Rendering of Procedural Multiscale Materials", Nvidia
![image](https://github.com/haxflying/CloudsDemo/blob/ubw/showcase9.png)
![image](https://github.com/haxflying/CloudsDemo/blob/master/showcase6.png)
![image](https://github.com/haxflying/CloudsDemo/blob/master/showcase4.png)
![image](https://github.com/haxflying/CloudsDemo/blob/master/showcase7.png)
![image](https://github.com/haxflying/CloudsDemo/blob/master/showcase0.png)
![image](https://github.com/haxflying/CloudsDemo/blob/master/showcase1.png)
![image](https://github.com/haxflying/CloudsDemo/blob/master/showcase2.png)
![image](https://github.com/haxflying/CloudsDemo/blob/master/showcase3.png)
