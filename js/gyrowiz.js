/* ═══ Calibración del acelerómetro (dirección inclinando el teléfono) ═══
   1) Sostené el teléfono como para jugar → CALIBRAR (ese es el centro)
   2) Inclinalo a la izquierda  3) a la derecha → se ve la aguja moverse; si va al revés se invierte solo
   4) Listo. Se abre al activar el acelerómetro y con el botón Calibrar (Opciones o pausa). */
let cssDone=false;
function css(){if(cssDone)return;cssDone=true;const s=document.createElement('style');s.textContent=`
#gyroWiz{position:fixed;inset:0;z-index:80;background:rgba(4,8,14,.82);display:flex;align-items:center;justify-content:center;font-family:system-ui,sans-serif;color:#fff}
#gyroWiz .box{width:min(460px,92vw);background:#10161f;border:1px solid #ffffff22;border-radius:18px;padding:16px 18px;text-align:center;box-shadow:0 10px 40px #000a}
#gyroWiz h3{margin:0 0 4px;font:900 18px system-ui}#gyroWiz p{margin:4px 0 10px;font:600 13px/1.35 system-ui;opacity:.9}
#gyroWiz .meter{position:relative;height:38px;border-radius:19px;background:#1d2530;margin:10px 0;overflow:hidden}
#gyroWiz .meter i{position:absolute;top:0;bottom:0;width:2px;left:50%;background:#ffffff55}
#gyroWiz .meter b{position:absolute;top:5px;width:28px;height:28px;border-radius:50%;background:#ff7a1a;left:calc(50% - 14px);transition:left .05s linear;box-shadow:0 0 12px #ff7a1a88}
#gyroWiz .meter .zl,#gyroWiz .meter .zr{position:absolute;top:0;bottom:0;width:22%;background:#3ddc8426}#gyroWiz .meter .zl{left:0}#gyroWiz .meter .zr{right:0}
#gyroWiz .steps{display:flex;justify-content:center;gap:8px;margin:6px 0 12px;font:800 12px system-ui}#gyroWiz .steps span{opacity:.4}#gyroWiz .steps span.on{opacity:1;color:#ff9a4a}#gyroWiz .steps span.ok{opacity:1;color:#3ddc84}
#gyroWiz .row{display:flex;gap:8px;justify-content:center}#gyroWiz button{border:0;border-radius:12px;padding:10px 16px;font:900 14px system-ui;color:#fff;background:#39414d}
#gyroWiz button.go{background:linear-gradient(180deg,#ff7a1a,#d9480f)}`;document.head.appendChild(s);}

export function gyroWizard(api,done){css();const o=document.createElement('div');o.id='gyroWiz';document.body.appendChild(o);
 let step=0,okT=0,raf=0,last=performance.now();
 const T=[['Sostené el teléfono derecho','Agarralo como para jugar, con la pantalla hacia vos y sin inclinar. Después tocá CALIBRAR.'],
  ['Inclinalo a la IZQUIERDA','Giralo como un volante hacia la izquierda hasta que la bola llegue a la zona verde.'],
  ['Ahora a la DERECHA','Giralo hacia la derecha hasta la zona verde.'],
  ['¡Listo, calibrado!','Si al jugar lo sentís raro, volvé a Opciones (o a la pausa) → Calibrar.']];
 const render=()=>{const [h,p]=T[step];o.innerHTML=`<div class="box"><div class="steps">${['Centro','Izquierda','Derecha','Listo'].map((n,i)=>`<span class="${i<step?'ok':i===step?'on':''}">${i<step?'✔ ':''}${n}</span>`).join('<span>›</span>')}</div>
  <h3>${h}</h3><p>${p}</p><div class="meter"><span class="zl"></span><span class="zr"></span><i></i><b></b></div>
  <div class="row">${step===0?'<button class="go" data-a="cal">CALIBRAR</button>':''}${step===3?'<button data-a="again">Repetir</button><button class="go" data-a="ok">JUGAR</button>':'<button data-a="x">Cancelar</button>'}</div></div>`;};
 const close=()=>{cancelAnimationFrame(raf);o.remove();if(done)done();};
 o.addEventListener('click',e=>{const a=e.target.dataset&&e.target.dataset.a;if(!a)return;
  if(a==='cal'){api.recal();step=1;okT=0;render();}else if(a==='again'){step=0;render();}else close();});
 const tick=t=>{const dt=Math.min(0.1,(t-last)/1000);last=t;const v=Math.max(-1,Math.min(1,api.value()||0));const b=o.querySelector('.meter b');if(b)b.style.left=`calc(${50+v*44}% - 14px)`;
  if(step===1||step===2){const want=step===1?-1:1;
   /* ¿va al revés? (en el primer paso la bola se fue fuerte para el otro lado) → se invierte y se sigue */
   if(step===1&&v>0.75){api.setInvert(!api.invert());okT=0;}
   if(v*want>0.6){okT+=dt;if(okT>0.35){step++;okT=0;render();}}else okT=0;}
  raf=requestAnimationFrame(tick);};
 render();raf=requestAnimationFrame(tick);}
