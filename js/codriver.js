/* ═══ Voz del copiloto: frases grabadas (audio/copilot.wav + .json) reproducidas por WebAudio
   con filtro de intercom. Funciona offline y en el WebView de Android (donde speechSynthesis suele faltar). ═══ */
export class CoDriver{
 constructor(name='copilot'){this.name=name;this.buf=null;this.map=null;this.loading=null;this.busyUntil=0;this.queue=[];this.failed=false;}
 load(ctx){if(this.loading||!ctx)return this.loading;this.ctx=ctx;
  this.loading=Promise.all([fetch('audio/'+this.name+'.json').then(r=>r.json()),fetch('audio/'+this.name+'.wav').then(r=>r.arrayBuffer())])
   .then(([m,ab])=>new Promise((res,rej)=>{const p=ctx.decodeAudioData(ab,res,rej);if(p&&p.then)p.then(res,rej);}).then(b=>{this.map=m;this.buf=b;this.chain();}))
   .catch(e=>{console.warn('copiloto',e);this.failed=true;});return this.loading;}
 get ready(){return !!(this.buf&&this.map);}
 chain(){const c=this.ctx;/* intercom: banda telefónica + leve saturación */
  const hp=c.createBiquadFilter();hp.type='highpass';hp.frequency.value=320;const lp=c.createBiquadFilter();lp.type='lowpass';lp.frequency.value=3600;
  const pk=c.createBiquadFilter();pk.type='peaking';pk.frequency.value=1800;pk.Q.value=0.9;pk.gain.value=5;
  const sh=c.createWaveShaper(),cv=new Float32Array(512);for(let i=0;i<512;i++){const x=i/255.5-1;cv[i]=Math.tanh(x*1.6)/Math.tanh(1.6);}sh.curve=cv;
  this.out=c.createGain();this.out.gain.value=0.9;hp.connect(lp).connect(pk).connect(sh).connect(this.out).connect(c.destination);this.input=hp;}
 /* keys: lista de claves del sprite; volume 0..1 */
 say(keys,volume=1){if(!this.ready)return false;const c=this.ctx;keys=keys.filter(k=>this.map[k]);if(!keys.length)return true;
  const now=c.currentTime;/* si viene atrasado (más de 1.2 s en cola) se descarta lo viejo: la nota nueva es la que importa */
  let t=Math.max(now+0.02,this.busyUntil);if(t-now>1.2){for(const s of this.queue)try{s.stop();}catch(e){}this.queue=[];t=now+0.02;}
  this.out.gain.setValueAtTime(0.95*volume,now);const rate=1.08;
  for(const k of keys){const [off,dur]=this.map[k];const s=c.createBufferSource();s.buffer=this.buf;s.playbackRate.value=rate;s.connect(this.input);s.start(t,off,dur);
   this.queue.push(s);s.onended=()=>{const i=this.queue.indexOf(s);if(i>=0)this.queue.splice(i,1);};t+=dur/rate+0.02;}
  this.busyUntil=t+0.08;return true;}
 stop(){for(const s of this.queue)try{s.stop();}catch(e){}this.queue=[];this.busyUntil=0;}
}
export function noteKeys(o){if(o.crest)return ['cresta'];const k=[o.sev+o.dir];if(o.long)k.push('larga');if(o.tight)k.push('cierra');else if(o.open)k.push('abre');if(o.into)k.push('y');return k;}
