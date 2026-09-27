/* ═══════════════════════════════════════════════════════════════════
   GSKORP RALLY — Estilos visuales (postprocesado)
   Cadena: escena → buffer HDR (+profundidad) → tonemapping ACES → efectos → pantalla.
   El HUD es HTML encima del canvas: nunca pasa por acá.
   Solo se compilan los efectos que usa el preset activo (rápido en celulares).
   ═══════════════════════════════════════════════════════════════════ */
import * as THREE from 'three';

/* ─── presets: valores 0-100 (los 11 del pedido, exactos) + los propios ─── */
export const VISUAL_PRESETS={
 none:{},
 claude:{dlss5:38,bloom2:45,godrays:55,sunflare:60,lensdirt2:40,dofdepth:70,haze:60,grade:85,videolook:70,speedblur:65,chromatic:8,vignette:34,filmgrain:9,noise:5,halation:12,raindrops:100,roadshake:40},
 tv:{dlss5:50,bloom2:22,sunflare:35,grade:35,videolook:35,speedblur:35,saturation:10,contrast:10,vignette:12,chromatic:4,raindrops:60,roadshake:20},
 dlss5:{dlss5:85,sharpness:20,contrast:8,saturation:5},
 fotorrealista:{tonemapping:70,bloom:35,chromatic:20,vignette:45,filmgrain:25,exposure:40,contrast:30,halation:20,sharpness:15,camerashake:10,motionblur:15},
 casero:{lensdistortion:30,chromatic:25,halation:25,chromasubsampling:60,interlacing:40,filmgrain:35,vignette:40,camerashake:45,motionblur:30,rollingshutter:20,autofocus:20,lensdirt:15,compression:20,noise:20,contrast:15},
 bodycam:{lensdistortion:40,chromatic:30,vignette:55,camerashake:35,motionblur:25,rollingshutter:30,autofocus:25,filmgrain:20,noise:15,compression:15,exposure:20,edgesoften:20},
 gopro:{gopro:80,saturation:30,sharpness:25,contrast:20,vignette:25,chromatic:15,filmgrain:10},
 cinematic:{dofsim:85,bokeh:80,filmtone:90,cinematiccamera:100,bloom:30,halation:25,vignette:30,filmgrain:15,exposure:10},
 genesis:{lensdistortion:18,chromatic:8,vignette:18,camerashake:12,motionblur:28,rollingshutter:6,autofocus:10,filmgrain:12,noise:4,exposure:12,saturation:4,edgesoften:8,bloom:22,tonemapping:22,contrast:18,fog:22,halation:10,lensdirt:6},
 aeroflow:{windstream:75,mistflow:40,motionblur:35,chromatic:18,bloom:15,filmgrain:10,vignette:25,exposure:15,contrast:20,tonemapping:30,lensdistortion:10,halation:20},
 hillclimb:{tonemapping:60,contrast:25,exposure:20,bloom:25,fog:35,chromatic:15,vignette:35,filmgrain:20,motionblur:30,camerashake:15,halation:15,lensdirt:10},
 vhs:{vhs:70,scanlines:55,chromatic:25,noise:35,vignette:45,filmgrain:30,chromasubsampling:50,interlacing:30,rollingshutter:15},
 termico:{thermal:100,contrast:20,brightness:10},
};
export const PRESET_INFO=[
 ['none','⚪','Normal','Sin postprocesado. El más liviano.'],
 ['claude','✨','Claude · Realidad','Hecho para confundirse con un video real: foco en tu auto, bruma de distancia, rayos de sol entre los árboles, destello de lente, gotas en lluvia.'],
 ['tv','📺','Transmisión TV','Como una transmisión de rally por televisión: nítido, colores de broadcast, destello de sol.'],
 ['dlss5','🚀','DLSS 5','Mejora de nitidez sin cambiar el color.'],
 ['fotorrealista','🏆','Fotorrealista','Captura fotorrealista equilibrada.'],
 ['casero','📹','Video casero','Grabado con un teléfono: vibración, compresión y ruido.'],
 ['bodycam','👮','Bodycam','Cámara corporal: gran angular y autoenfoque errático.'],
 ['gopro','🎿','GoPro','Cámara de acción: gran angular, colores intensos.'],
 ['cinematic','🎬','Cinematic Camera','Desenfoque de fondo, bokeh y grade de cine.'],
 ['genesis','🌿','Genesis','Realismo cinematográfico calibrado para autos.'],
 ['aeroflow','💨','Aeroflow F1','Túnel de viento: estrías aerodinámicas y llovizna.'],
 ['hillclimb','🎮','Hill Climb','El look base del juego, mejora sutil.'],
 ['vhs','📼','VHS','Cinta de los 80: scanlines y tracking.'],
 ['termico','🔥','Visión térmica','Cámara infrarroja militar.'],
];
/* efectos que dependen de profundidad o sol (para saber qué calcular) */
const HEAVY=['bokeh','dofsim','dofdepth','godrays','bloom','bloom2','filmgrain','motionblur','speedblur'];

/* ─── código GLSL de cada efecto (en el orden de aplicación) ─── */
const UV_FX={
 lensdistortion:`{vec2 d=uv-vec2(0.5);uv=vec2(0.5)+d*(1.0+u_lensdistortion*0.5*dot(d,d));}`,
 gopro:`{vec2 d=uv-vec2(0.5);uv=vec2(0.5)+d*(1.0+u_gopro*0.8*dot(d,d));}`,
 camerashake:`{float t=u_time*2.5;vec2 shake=vec2(smoothNoise(vec2(t,0.0))-0.5,smoothNoise(vec2(0.0,t))-0.5)*u_camerashake*0.03*u_motion;uv+=shake;}`,
 roadshake:`{float t=u_time*19.0;vec2 shake=vec2(smoothNoise(vec2(t,3.1))-0.5,smoothNoise(vec2(1.7,t))-0.5)*u_roadshake*0.006*u_rough;uv+=shake;}`,
 rollingshutter:`{uv.x+=(uv.y-0.5)*u_rollingshutter*0.02*sin(u_time*3.0);}`,
 raindrops:`{vec2 g=uv*vec2(u_resolution.x/u_resolution.y,1.0)*7.0;vec2 id=floor(g);vec2 f=fract(g)-0.5;float rnd=rand(id);float slide=fract(u_time*(0.05+rnd*0.12)+rnd);vec2 c=vec2((rand(id+3.1)-0.5)*0.6,0.5-slide*1.2);float r=0.08+rnd*0.14;float dd=length((f-c)*vec2(1.0,0.8));float m=smoothstep(r,r*0.55,dd)*step(0.55,rnd)*u_raindrops*u_rain;uv+=(f-c)*m*0.06;dropShade=m;}`,
};
const COLOR_FX={
 chromatic:`{vec2 d=uv-vec2(0.5);float r=length(d);float offset=u_chromatic*0.008;color=vec3(texture2D(u_texture,uv+d*offset*r).r,texture2D(u_texture,uv).g,texture2D(u_texture,uv-d*offset*r).b);}`,
 dlss5:`{float dx=1.0/u_resolution.x;float dy=1.0/u_resolution.y;vec3 c=color;vec3 n=texture2D(u_texture,uv+vec2(0.0,-dy)).rgb;vec3 s=texture2D(u_texture,uv+vec2(0.0,dy)).rgb;vec3 e=texture2D(u_texture,uv+vec2(dx,0.0)).rgb;vec3 w=texture2D(u_texture,uv+vec2(-dx,0.0)).rgb;vec3 mn=min(min(min(n,s),min(e,w)),c);vec3 mx=max(max(max(n,s),max(e,w)),c);vec3 amp=clamp(min(mn,1.0-mx)/max(mx,0.0001),0.0,1.0);vec3 wgt3=amp*(-1.0/mix(8.0,5.0,u_dlss5));vec3 casColor=((n+s+e+w)*wgt3+c)/(1.0+4.0*wgt3);vec3 hf=c-(n+s+e+w)*0.25;color=mix(color,casColor+hf*0.4,u_dlss5);}`,
 dofdepth:`{float z=linDepth(uv);float coc=clamp(abs(1.0-u_focus/max(z,0.01))*1.6,0.0,1.0)*u_dofdepth*smoothstep(u_focus*0.7,u_focus*1.6,z);if(coc>0.02){vec3 acc=color;float tot=1.0;float rad=coc*0.012;for(int i=1;i<8;i++){float fi=float(i);float a=fi*2.39996323;float r=sqrt(fi/8.0)*rad;vec2 o=vec2(cos(a),sin(a))*r*vec2(u_resolution.y/u_resolution.x,1.0);float zs=linDepth(uv+o);float w=step(u_focus*0.8,zs);acc+=texture2D(u_texture,uv+o).rgb*w;tot+=w;}color=acc/tot;}}`,
 dofsim:`{float distFromFocus=abs(uv.y-0.5);float blurAmount=smoothstep(0.08,0.45,distFromFocus)*u_dofsim;if(blurAmount>0.001){vec3 blurred=vec3(0.0);float radius=blurAmount*0.02;for(int i=0;i<8;i++){float fi=float(i);float angle=fi*2.39996323;float r=sqrt(fi/8.0)*radius;vec2 offset=vec2(cos(angle),sin(angle))*r;blurred+=texture2D(u_texture,uv+offset).rgb;}color=mix(color,blurred/8.0,blurAmount);}}`,
 bokeh:`{vec3 bokehSum=vec3(0.0);float bokehCount=0.0;float radius=u_bokeh*0.08;for(int i=0;i<12;i++){float fi=float(i);float angle=fi*2.39996323;float r=sqrt(fi/12.0)*radius;vec2 offset=vec2(cos(angle),sin(angle))*r;vec3 s=texture2D(u_texture,uv+offset).rgb;float sLuma=luma(s);if(sLuma>0.75){bokehSum+=s*(sLuma-0.75);bokehCount+=1.0;}}if(bokehCount>0.0)color+=(bokehSum/bokehCount)*u_bokeh*1.8;}`,
 haze:`{float z=linDepth(uv);float sky=step(u_far*0.9,z);float f=(1.0-exp(-z*0.0026))*(1.0-sky);float sunAmt=u_sun.z*pow(max(0.0,1.0-distance(uv,u_sun.xy)*1.3),3.0);vec3 hc=mix(u_hazeColor,vec3(1.0,0.92,0.78),sunAmt*0.6);color=mix(color,hc,f*u_haze*0.55);color=mix(color,color*vec3(0.97,0.99,1.03),f*u_haze);}`,
 filmtone:`{vec3 x=color*1.2;vec3 aces=(x*(2.51*x+0.03))/(x*(2.43*x+0.59)+0.14);aces=pow(aces,vec3(0.95));aces*=vec3(1.02,1.0,0.98);color=mix(color,aces,u_filmtone);}`,
 cinematiccamera:`{vec3 x=color;vec3 aces=(x*(2.51*x+0.03))/(x*(2.43*x+0.59)+0.14);color=mix(color,aces,u_cinematiccamera);float lum=luma(color);vec3 warm=color*vec3(1.06,1.0,0.92);vec3 cool=color*vec3(0.92,0.98,1.08);color=mix(cool,warm,smoothstep(0.3,0.7,lum));vec3 desat=mix(vec3(lum),color,0.7);color=mix(color,desat,smoothstep(0.25,0.0,lum));color=mix(color,(color-0.5)*1.08+0.5,u_cinematiccamera);}`,
 grade:`{float lum=luma(color);vec3 sh=vec3(0.93,0.99,1.06),hi=vec3(1.05,1.0,0.93);vec3 g=color*mix(sh,hi,smoothstep(0.2,0.75,lum));g=mix(vec3(luma(g)),g,1.06);g=g*g*(3.0-2.0*g)*0.35+g*0.65;color=mix(color,g,u_grade);}`,
 videolook:`{vec3 c=color;c=c/(1.0+c*0.18)*1.16;c=c*0.93+0.035;float l=luma(c);c=mix(c,c*vec3(0.98,1.01,1.0),0.5);c=mix(vec3(l),c,0.92+0.08*smoothstep(0.2,0.8,l));color=mix(color,c,u_videolook);}`,
 brightness:`color*=(1.0+u_brightness*0.8);`,
 contrast:`color=(color-0.5)*(1.0+u_contrast*0.8)+0.5;`,
 saturation:`{float l=luma(color);color=mix(vec3(l),color,1.0+u_saturation*0.8);}`,
 exposure:`color*=(1.0+u_exposure*0.5);`,
 gopro_col:`{float lg=luma(color);color=mix(vec3(lg),color,1.0+u_gopro*0.5);color=(color-0.5)*(1.0+u_gopro*0.3)+0.5;}`,
 tonemapping:`color=mix(color,color/(color+vec3(1.0)),u_tonemapping);`,
 sepia:`{vec3 sepia=vec3(dot(color,vec3(0.393,0.769,0.189)),dot(color,vec3(0.349,0.686,0.168)),dot(color,vec3(0.272,0.534,0.131)));color=mix(color,sepia,u_sepia);}`,
 fog:`{float fogFactor=(1.0-luma(color))*u_fog;color=mix(color,vec3(0.7,0.75,0.8),fogFactor*0.6);}`,
 thermal:`{float lum=luma(color);vec3 tc;if(lum<0.2)tc=mix(vec3(0.0,0.0,0.3),vec3(0.2,0.0,0.6),lum/0.2);else if(lum<0.4)tc=mix(vec3(0.2,0.0,0.6),vec3(0.8,0.0,0.4),(lum-0.2)/0.2);else if(lum<0.6)tc=mix(vec3(0.8,0.0,0.4),vec3(1.0,0.3,0.0),(lum-0.4)/0.2);else if(lum<0.8)tc=mix(vec3(1.0,0.3,0.0),vec3(1.0,0.9,0.0),(lum-0.6)/0.2);else tc=mix(vec3(1.0,0.9,0.0),vec3(1.0,1.0,1.0),(lum-0.8)/0.2);color=mix(color,tc,u_thermal);}`,
 scanlines:`color*=mix(1.0,sin(uv.y*u_resolution.y*1.2)*0.15+0.85,u_scanlines);`,
 vhs:`{float shift=sin(uv.y*40.0+u_time*5.0)*0.003*u_vhs;color=texture2D(u_texture,vec2(uv.x+shift,uv.y)).rgb;color+=(rand(uv+u_time*10.0)-0.5)*0.08*u_vhs;color.r=texture2D(u_texture,vec2(uv.x+shift+0.002,uv.y)).r;}`,
 sharpness:`{vec3 blurred=(texture2D(u_texture,uv+vec2(-1.0/u_resolution.x,0.0)).rgb+texture2D(u_texture,uv+vec2(1.0/u_resolution.x,0.0)).rgb)*0.5;color+=(color-blurred)*u_sharpness*0.5;}`,
 edgesoften:`{vec3 blurred=(texture2D(u_texture,uv+vec2(-1.0/u_resolution.x,0.0)).rgb+texture2D(u_texture,uv+vec2(1.0/u_resolution.x,0.0)).rgb)*0.5;color=mix(color,blurred,u_edgesoften*0.7);}`,
 bloom:`{float dx=1.0/u_resolution.x*4.0;float dy=1.0/u_resolution.y*4.0;vec3 s1=texture2D(u_texture,uv+vec2(dx,0.0)).rgb;vec3 s2=texture2D(u_texture,uv-vec2(dx,0.0)).rgb;vec3 s3=texture2D(u_texture,uv+vec2(0.0,dy)).rgb;vec3 s4=texture2D(u_texture,uv-vec2(0.0,dy)).rgb;vec3 bloomSum=vec3(0.0);float samples=0.0;float b1=luma(s1);if(b1>0.7){bloomSum+=s1*(b1-0.7);samples++;}float b2=luma(s2);if(b2>0.7){bloomSum+=s2*(b2-0.7);samples++;}float b3=luma(s3);if(b3>0.7){bloomSum+=s3*(b3-0.7);samples++;}float b4=luma(s4);if(b4>0.7){bloomSum+=s4*(b4-0.7);samples++;}if(samples>0.0)color+=(bloomSum/samples)*u_bloom*2.0;}`,
 bloom2:`{vec3 acc=vec3(0.0);vec2 px=1.0/u_resolution;for(int i=0;i<8;i++){float fi=float(i);float a=fi*2.39996323;float r=(2.0+fi*2.0);vec3 s=texture2D(u_texture,uv+vec2(cos(a),sin(a))*r*px*1.5).rgb;float l=luma(s);float k=max(0.0,l-0.62);k=k*k/(k+0.12);acc+=s*k;}color+=acc*0.2*u_bloom2;}`,
 halation:`{float bc=luma(texture2D(u_texture,uv).rgb);if(bc>0.8){color.r+=(bc-0.8)*u_halation*0.5;color.g+=(bc-0.8)*u_halation*0.1;}}`,
 godrays:`if(u_sun.z>0.01){vec2 dir=(u_sun.xy-uv);float ill=0.0;float dec=1.0;vec2 st=dir/10.0;vec2 p=uv;for(int i=0;i<10;i++){p+=st;float sky=step(u_far*0.9,linDepth(clamp(p,0.001,0.999)));ill+=sky*dec;dec*=0.93;}ill/=10.0;float fall=pow(max(0.0,1.0-length(dir)*0.9),1.5);color+=vec3(1.0,0.9,0.72)*ill*fall*u_sun.z*u_godrays*0.55;}`,
 sunflare:`if(u_sun.z>0.01){float occ=0.0;for(int i=0;i<5;i++){vec2 o=vec2(float(i-2)*0.004,float(i==0?1:(i==4?-1:0))*0.004);occ+=step(u_far*0.9,linDepth(clamp(u_sun.xy+o,0.001,0.999)));}occ/=5.0;float v=u_sun.z*occ*u_sunflare;vec2 d=uv-u_sun.xy;d.x*=u_resolution.x/u_resolution.y;float g=exp(-length(d)*7.0);float streak=exp(-abs(d.y)*90.0)*exp(-abs(d.x)*2.2);vec3 fl=vec3(1.0,0.93,0.8)*(g*0.55+streak*0.35);vec2 axis=vec2(0.5)-u_sun.xy;for(int i=1;i<4;i++){float fi=float(i);vec2 gp=u_sun.xy+axis*(0.55*fi);vec2 gd=uv-gp;gd.x*=u_resolution.x/u_resolution.y;float ring=smoothstep(0.06*fi,0.05*fi,length(gd))*0.10;fl+=vec3(0.55,0.8,1.0)*ring/fi+vec3(1.0,0.6,0.3)*ring*0.5/fi;}color+=fl*v;sunGlow=v*g;}`,
 windstream:`{vec2 flowUV=uv;flowUV.x-=u_time*0.8;float streakSeed=floor(flowUV.y*200.0)/200.0;float streakRand=rand(vec2(streakSeed,floor(flowUV.x*3.0)));float streakMask=smoothstep(0.85,0.98,streakRand);float pulse=sin((uv.x+u_time*0.5)*15.0+uv.y*30.0)*0.5+0.5;float dx=1.0/u_resolution.x;float dy=1.0/u_resolution.y;float lc=luma(texture2D(u_texture,uv).rgb);float lr=luma(texture2D(u_texture,uv+vec2(dx,0.0)).rgb);float lu=luma(texture2D(u_texture,uv+vec2(0.0,dy)).rgb);float edge=sqrt((lc-lr)*(lc-lr)+(lc-lu)*(lc-lu));float streak=streakMask*(0.15+edge*4.0)*pulse;color+=vec3(0.55,0.85,1.0)*streak*u_windstream*0.5;}`,
 mistflow:`{vec2 dropUV=uv*vec2(40.0,20.0);dropUV.y-=u_time*3.0;dropUV.x-=u_time*1.5;float drop=rand(floor(dropUV));if(drop>0.96){float dropAmount=smoothstep(0.96,1.0,drop);vec2 localUV=fract(dropUV)-0.5;float dropShape=clamp(1.0-length(localUV)*2.0,0.0,1.0);float trail=clamp(1.0-abs(localUV.y)*2.0,0.0,1.0);float droplet=max(dropShape,trail*0.5);color+=vec3(0.75,0.9,1.0)*droplet*dropAmount*u_mistflow*0.4;}vec2 mistUV=uv*vec2(80.0,5.0);mistUV.y-=u_time*5.0;float mist=rand(vec2(floor(mistUV.x),floor(mistUV.y)));if(mist>0.93)color+=vec3(0.7,0.85,1.0)*(mist-0.93)*u_mistflow*0.3;}`,
 filmgrain:`color+=(rand(uv*u_resolution+u_time*100.0)-0.5)*u_filmgrain*0.15;`,
 noise:`{color+=(rand(uv*u_resolution*2.0+u_time*50.0)-0.5)*u_noise*0.1;color.r+=(rand(uv*100.0+u_time)-0.5)*u_noise*0.05;color.b+=(rand(uv*100.0+u_time+5.0)-0.5)*u_noise*0.05;}`,
 chromasubsampling:`{vec2 bUV=floor(uv*u_resolution/4.0)*4.0/u_resolution;vec3 chroma=texture2D(u_texture,bUV).rgb;vec3 result=color-luma(chroma)+luma(color);result=mix(color,(result+chroma)*0.5,u_chromasubsampling);color=mix(color,result,u_chromasubsampling);}`,
 interlacing:`if(mod(floor(uv.y*u_resolution.y),2.0)>0.5){color=mix(color,texture2D(u_texture,uv+vec2(0.0,1.0/u_resolution.y)).rgb,u_interlacing*0.5);}`,
 compression:`{vec2 bUV=floor(uv*u_resolution/8.0)*8.0/u_resolution;color=mix(color,mix(texture2D(u_texture,bUV).rgb,color,0.5),u_compression);}`,
 lensdirt:`color*=mix(1.0,smoothNoise(uv*15.0)*0.5+0.5,u_lensdirt*0.4);`,
 lensdirt2:`{float dirt=smoothNoise(uv*9.0)*0.6+smoothNoise(uv*31.0+3.0)*0.4;dirt=smoothstep(0.45,0.95,dirt);color+=vec3(1.0,0.95,0.85)*dirt*(sunGlow*3.0+0.02)*u_lensdirt2;}`,
 lensfog:`{float d=distance(uv,vec2(0.5));color=mix(color,mix(color,vec3(0.9,0.92,0.95),0.5),smoothstep(0.2,0.7,d)*u_lensfog);}`,
 autofocus:`{float fh=sin(u_time*3.0)*0.5+0.5;vec3 blurred=texture2D(u_texture,uv+(uv-0.5)*fh*u_autofocus*0.02).rgb;color=mix(color,blurred,u_autofocus*0.5);}`,
 motionblur:`{float mb=u_motionblur*(0.15+0.85*u_speed);vec2 dir=uv-vec2(0.5);vec3 sum=vec3(0.0);for(float i=0.0;i<4.0;i+=1.0){sum+=texture2D(u_texture,uv-dir*i*0.01*mb).rgb;}color=mix(color,sum/4.0,mb);}`,
 speedblur:`{float sp=u_speed*u_speedblur;if(sp>0.02){vec2 dir=uv-vec2(0.5,0.45);float m=smoothstep(0.12,0.5,length(dir));vec3 sum=color;for(int i=1;i<6;i++){sum+=texture2D(u_texture,uv-dir*float(i)*0.0045*sp).rgb;}color=mix(color,sum/6.0,m*min(1.0,sp*1.4));}}`,
 vignette:`{float d=distance(uv,vec2(0.5));color*=1.0-smoothstep(0.3,0.8,d)*u_vignette;}`,
};
const ORDER_UV=['lensdistortion','gopro','camerashake','roadshake','rollingshutter','raindrops'];
const ORDER_COLOR=['chromatic','dlss5','dofdepth','dofsim','bokeh','haze','filmtone','cinematiccamera','grade','videolook','brightness','contrast','saturation','exposure','gopro_col','tonemapping','sepia','fog','thermal','scanlines','vhs','sharpness','edgesoften','bloom','bloom2','halation','godrays','sunflare','windstream','mistflow','filmgrain','noise','chromasubsampling','interlacing','compression','lensdirt','lensdirt2','lensfog','autofocus','motionblur','speedblur','vignette'];
export const ALL_EFFECT_IDS=[...new Set([...ORDER_UV,...ORDER_COLOR.filter(k=>k!=='gopro_col')])];

const HELPERS=`
float rand(vec2 co){return fract(sin(dot(co.xy,vec2(12.9898,78.233)))*43758.5453);}
float luma(vec3 c){return dot(c,vec3(0.2126,0.7152,0.0722));}
float smoothNoise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);float a=rand(i);float b=rand(i+vec2(1.0,0.0));float c=rand(i+vec2(0.0,1.0));float d=rand(i+vec2(1.0,1.0));return mix(mix(a,b,f.x),mix(c,d,f.x),f.y);}
float linDepth(vec2 uv){float d=texture2D(u_depth,uv).x;float z=d*2.0-1.0;return (2.0*u_near*u_far)/(u_far+u_near-z*(u_far-u_near));}
`;

export class PostFX{
 constructor(renderer){
  this.r=renderer;this.preset='none';this.fps=60;this.lowT=0;this.level=0;this.auto=true;this.intensity=1;this.values={};
  const gl=renderer.getContext();const e=renderer.extensions;
  this.supported=renderer.capabilities.isWebGL2&&(e.has('EXT_color_buffer_half_float')||e.has('EXT_color_buffer_float'));
  const type=this.supported?THREE.HalfFloatType:THREE.UnsignedByteType;
  this.hdr=new THREE.WebGLRenderTarget(4,4,{type,depthBuffer:true,minFilter:THREE.LinearFilter,magFilter:THREE.LinearFilter});
  this.hdr.depthTexture=new THREE.DepthTexture(4,4);this.hdr.depthTexture.type=THREE.UnsignedIntType;
  this.ldr=new THREE.WebGLRenderTarget(4,4,{type:THREE.UnsignedByteType,depthBuffer:false,minFilter:THREE.LinearFilter,magFilter:THREE.LinearFilter});
  this.qs=new THREE.Scene();this.qc=new THREE.OrthographicCamera(-1,1,1,-1,0,1);this.quad=new THREE.Mesh(new THREE.PlaneGeometry(2,2));this.quad.frustumCulled=false;this.qs.add(this.quad);
  /* pase 1: tonemapping ACES (igual que el render directo) + sRGB */
  this.tm=new THREE.ShaderMaterial({uniforms:{u_tex:{value:this.hdr.texture},u_exp:{value:1}},depthTest:false,depthWrite:false,
   vertexShader:'varying vec2 vUv;void main(){vUv=uv;gl_Position=vec4(position.xy,0.0,1.0);}',
   fragmentShader:`precision highp float;uniform sampler2D u_tex;uniform float u_exp;varying vec2 vUv;
    vec3 RRTAndODTFit(vec3 v){vec3 a=v*(v+0.0245786)-0.000090537;vec3 b=v*(0.983729*v+0.4329510)+0.238081;return a/b;}
    vec3 aces(vec3 c){const mat3 I=mat3(vec3(0.59719,0.07600,0.02840),vec3(0.35458,0.90834,0.13383),vec3(0.04823,0.01566,0.83777));const mat3 O=mat3(vec3(1.60475,-0.10208,-0.00327),vec3(-0.53108,1.10813,-0.07276),vec3(-0.07367,-0.00605,1.07602));c*=u_exp/0.6;c=I*c;c=RRTAndODTFit(c);c=O*c;return clamp(c,0.0,1.0);}
    vec3 srgb(vec3 c){return mix(c*12.92,pow(c,vec3(1.0/2.4))*1.055-0.055,step(0.0031308,c));}
    void main(){gl_FragColor=vec4(srgb(aces(texture2D(u_tex,vUv).rgb)),1.0);}`});
  this.fx=null;this.u={};this.setPreset('none');}
 setPreset(name){if(!VISUAL_PRESETS[name])name='none';this.preset=name;this.level=0;this.lowT=0;this.values={...VISUAL_PRESETS[name]};this.build();}
 build(){if(this.fx)this.fx.dispose();const v=this.values,act=k=>(v[k]||0)>0;
  const keys=ALL_EFFECT_IDS;const U={u_texture:{value:this.ldr.texture},u_depth:{value:this.hdr.depthTexture},u_resolution:{value:new THREE.Vector2(1,1)},u_time:{value:0},u_speed:{value:0},u_motion:{value:0},u_rough:{value:0},u_rain:{value:0},
   u_sun:{value:new THREE.Vector3(0.5,0.5,0)},u_near:{value:0.15},u_far:{value:2500},u_focus:{value:8},u_hazeColor:{value:new THREE.Color(0.7,0.78,0.86)}};
  for(const k of keys)U['u_'+k]={value:(v[k]||0)/100};this.u=U;
  if(this.preset==='none'){this.fx=null;return;}
  let uvCode='',colCode='';for(const k of ORDER_UV)if(act(k))uvCode+=UV_FX[k]+'\n';
  for(const k of ORDER_COLOR){const id=k==='gopro_col'?'gopro':k;if(act(id))colCode+=COLOR_FX[k]+'\n';}
  const decl=Object.keys(U).map(k=>{const t=U[k].value;return `uniform ${t&&t.isVector2?'vec2':t&&t.isVector3?'vec3':t&&t.isColor?'vec3':t&&t.isTexture?'sampler2D':'float'} ${k};`;}).join('\n');
  this.fx=new THREE.ShaderMaterial({uniforms:U,depthTest:false,depthWrite:false,
   vertexShader:'varying vec2 vUv;void main(){vUv=uv;gl_Position=vec4(position.xy,0.0,1.0);}',
   fragmentShader:`precision highp float;\n${decl}\nvarying vec2 vUv;\n${HELPERS}\nvoid main(){vec2 uv=vUv;float dropShade=0.0;float sunGlow=0.0;\n${uvCode}\nuv=clamp(uv,0.001,0.999);vec3 color=texture2D(u_texture,uv).rgb;\n${colCode}\ncolor*=1.0-dropShade*0.08;gl_FragColor=vec4(clamp(color,0.0,1.0),1.0);}`});}
 get active(){return this.preset!=='none'&&this.supported&&!!this.fx;}
 /* auto-calidad: FPS bajos → recorta los efectos pesados (nunca la resolución) */
 autoQuality(fps,dt){if(!this.auto||!this.active)return;this.fps=fps;
  const want=fps<20?2:fps<30?1:0;if(want>this.level){this.lowT+=dt;if(this.lowT>2){this.level=want;this.lowT=0;this.applyLevel();}}else this.lowT=0;}
 applyLevel(){const base=VISUAL_PRESETS[this.preset];for(const k of ALL_EFFECT_IDS){let x=(base[k]||0)/100;
   if(this.level>=1&&HEAVY.includes(k))x*=0.5;if(this.level>=2){if(['bokeh','dofsim','dofdepth','godrays'].includes(k))x=0;else x*=0.7;}if(this.u['u_'+k])this.u['u_'+k].value=x*this.intensity;}}
 /* frame: info = {time,speed01,rough01,rain01,camera,sunDir,focus,hazeColor} */
 render(scene,camera,info){const r=this.r;
  if(!this.active){r.setRenderTarget(null);r.render(scene,camera);return;}
  const sz=r.getDrawingBufferSize(this._v||(this._v=new THREE.Vector2()));
  if(this.hdr.width!==sz.x||this.hdr.height!==sz.y){this.hdr.setSize(sz.x,sz.y);this.ldr.setSize(sz.x,sz.y);}
  const U=this.u;U.u_resolution.value.set(sz.x,sz.y);U.u_time.value=info.time%1000;U.u_speed.value+=(info.speed-U.u_speed.value)*0.1;U.u_motion.value=Math.min(1,info.speed*1.5);U.u_rough.value+=(info.rough-U.u_rough.value)*0.2;U.u_rain.value=info.rain;
  U.u_near.value=camera.near;U.u_far.value=camera.far;U.u_focus.value=info.focus||8;if(info.hazeColor)U.u_hazeColor.value.copy(info.hazeColor);
  if(info.sunDir){const p=this._p||(this._p=new THREE.Vector3());p.copy(info.sunDir).multiplyScalar(1000).add(camera.position);const fwd=this._f||(this._f=new THREE.Vector3());camera.getWorldDirection(fwd);const facing=fwd.dot(info.sunDir);p.project(camera);
   const vis=facing>0&&Math.abs(p.x)<1.25&&Math.abs(p.y)<1.25?Math.min(1,facing*1.4)*(1-Math.max(0,Math.max(Math.abs(p.x),Math.abs(p.y))-0.95)*4):0;U.u_sun.value.set(p.x*0.5+0.5,p.y*0.5+0.5,Math.max(0,vis)*(info.sunPower??1));}
  this.tm.uniforms.u_exp.value=r.toneMappingExposure;
  const tmOld=r.toneMapping;
  r.setRenderTarget(this.hdr);r.render(scene,camera);
  r.toneMapping=THREE.NoToneMapping;this.quad.material=this.tm;r.setRenderTarget(this.ldr);r.render(this.qs,this.qc);
  this.quad.material=this.fx;r.setRenderTarget(null);r.render(this.qs,this.qc);r.toneMapping=tmOld;}
}
