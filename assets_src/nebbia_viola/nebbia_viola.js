// La nebbia viola di NotHuman (la stanza del medico, 29 ottobre 2026), staccata dal gioco per usarla in qualunque scena
// Three.js. Non e' un filtro colore: e' una nebbia vera, calcolata con la profondita' della scena. Per ogni punto dello
// schermo si cammina lungo il raggio dall'occhio alla cosa vista, e a ogni passo la nebbia toglie un po' della luce di
// dietro e ci mette la sua. E' piu' fitta in basso e fatta a ciuffi che vanno col vento. Ha l'aria viola, i raggi del
// sole (anche solo dai vetri di una finestra), l'alone delle lampade e la polvere nella luce. Dopo il tone mapping,
// ColoreViola porta le ombre al blu viola e le luci al bianco freddo.
//
// Uso (Three.js r150 o piu' nuovo, WebGL 2), al posto di renderer.render(scene, camera):
//   const rt = new THREE.WebGLRenderTarget(w, h, { type: THREE.HalfFloatType, samples: 4 });
//   rt.depthTexture = new THREE.DepthTexture(w, h);             // la nebbia ha bisogno della profondita'
//   const composer = new EffectComposer(renderer, rt);
//   composer.addPass(new RenderPass(scene, camera));
//   composer.addPass(new NebbiaViola(camera, { luci: [{ posizione: [0, 2.4, 0] }] }));
//   composer.addPass(new OutputPass());                          // il tone mapping (nel gioco AgX) e lo sRGB
//   composer.addPass(new ColoreViola());
//   // e a ogni fotogramma: composer.render();  al ridimensionamento: composer.setSize(w, h)
// Le misure sono in metri, col pavimento a y = 0 (o a "quota"). Vedi LEGGIMI.md.

import * as THREE from "three";
import { ShaderPass } from "three/addons/postprocessing/ShaderPass.js";

// i valori della nebbia viola, come nel gioco. I colori sono luce vera (prima del tone mapping), tarati con
// l'esposizione del gioco (renderer.toneMappingExposure = 2.6, AgX): con un'esposizione piu' bassa alza "forza"
export const NEBBIA_VIOLA = {
  passi: 20, // i passi lungo ogni raggio (10 sui telefoni)
  lontano: 14, // fin dove si calcola la nebbia, in metri
  quota: 0, // l'altezza del pavimento
  densita: 0.08, // la nebbia dappertutto, per metro
  strato: 0.8, // in piu' vicino al pavimento...
  altezza: 3.0, // ...che si dirada salendo (piu' alto il numero, piu' basso lo strato)
  ciuffi: 1, // 0 nebbia uniforme, 1 tutta a banchi e ciuffi
  scala: 1.3, // la grandezza dei ciuffi (piu' alto, piu' piccoli)
  vento: [0.06, 0.01, -0.035], // metri al secondo
  aria: [0.02, 0.018, 0.055], // il colore della nebbia, anche al buio
  raggi: [0.24, 0.2, 0.42], // la luce del sole nella nebbia (lilla)
  caldo: [1.0, 0.5, 0.62], // l'alone delle lampade (rosa caldo)
  particelle: 0.35, // la polvere che brilla nella luce
  forza: 1, // tutta la luce della nebbia insieme
  sole: null, // { direzione: [x, y, z] (dove va la luce: dal cielo verso il basso), forza: 1 }
  finestra: null, // { origine: [x, y, z], u: [1, 0, 0], v: [0, 1, 0], vetri: [[u0, v0, u1, v1], ...] }
  luci: [], // fino a 4: { posizione: [x, y, z], forza: 0.18, colore: [r, g, b] (se manca, "caldo") }
};

// il filtro colore finale della nebbia viola, come nel gioco
export const COLORE_VIOLA = { ombre: [0.56, 0.54, 1.0], luci: [0.84, 0.88, 1.0], tinta: 0.9, contrasto: 0.45, saturazione: 1, vignetta: 0.5 };

const VERTICI = "varying vec2 vUv; void main() { vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }";

const NEBBIA = `uniform sampler2D tDiffuse, tDepth, tRumore;
uniform mat4 proiezioneInv, mondoCamera;
uniform vec3 occhio, vento, aria, raggi, soleDir, finO, finU, finV;
uniform float tempo, densita, strato, altezza, quota, ciuffi, scala, sole, particelle, lontano, forza;
uniform vec3 luciPos[4];
uniform vec3 luciCol[4];
uniform int nLuci;
uniform vec4 vetri[8];
uniform int nVetri;
varying vec2 vUv;
// il rumore in 3D con una lettura sola: nel rosso la tabella, nel verde la stessa spostata di (37, 17), cioe' la fetta dopo
float rumore(vec3 x) {
  vec3 p = floor(x);
  vec3 f = fract(x);
  f = f * f * (3.0 - 2.0 * f);
  vec2 uv = p.xy + vec2(37.0, 17.0) * p.z + f.xy;
  vec2 rg = texture2D(tRumore, (uv + 0.5) / 256.0).yx;
  return mix(rg.x, rg.y, f.z);
}
float fbm(vec3 p) { return 0.55 * rumore(p) + 0.3 * rumore(p * 2.07 + 13.1) + 0.15 * rumore(p * 4.3 + 7.7); }
float vetro(vec2 q, vec2 a, vec2 b) { vec2 s = smoothstep(a, a + 0.025, q) * smoothstep(b, b - 0.025, q); return s.x * s.y; }
// il sole: senza finestra arriva dappertutto; con la finestra solo dove, risalendo il raggio del sole fino al muro, si
// passa da un vetro (cosi' si vedono i raggi)
float finestra(vec3 p) {
  if (nVetri == 0) return 1.0;
  vec3 n = cross(finU, finV);
  float dn = dot(soleDir, n);
  if (abs(dn) < 1e-5) return 0.0;
  float s = dot(p - finO, n) / dn;
  if (s <= 0.0) return 0.0;
  vec3 q3 = p - soleDir * s - finO;
  vec2 q = vec2(dot(q3, finU), dot(q3, finV));
  float a = 0.0;
  for (int i = 0; i < 8; i++) {
    if (i >= nVetri) break;
    a += vetro(q, vetri[i].xy, vetri[i].zw);
  }
  return a;
}
void main() {
  vec3 col = texture2D(tDiffuse, vUv).rgb;
  // il punto visto, in coordinate del mondo, dalla profondita'
  float z = texture2D(tDepth, vUv).x;
  vec4 v = proiezioneInv * vec4(vUv * 2.0 - 1.0, z * 2.0 - 1.0, 1.0);
  v /= v.w;
  vec3 P = (mondoCamera * vec4(v.xyz, 1.0)).xyz;
  vec3 rd = P - occhio;
  float L = length(rd);
  rd /= max(L, 0.0001);
  L = min(L, lontano);
  float dt = L / float(PASSI);
  // la nebbia sparpaglia la luce soprattutto in avanti: i raggi si vedono di piu' guardando verso il sole
  float c = dot(-rd, soleDir);
  float fase = 0.35 + 0.65 * 0.64 / pow(1.36 - 1.2 * c, 1.5);
  // un inizio diverso per ogni punto dello schermo (rumore a gradiente intrecciato): pochi passi senza strisce
  float j = fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715))));
  float T = 1.0;
  vec3 S = vec3(0.0);
  for (int i = 0; i < PASSI; i++) {
    float t = (float(i) + j) * dt;
    vec3 p = occhio + rd * t;
    float n = fbm(p * vec3(scala, scala * 1.8, scala) + vento * tempo);
    float d = (densita + strato * exp(-max(p.y - quota, 0.0) * altezza)) * mix(1.0, smoothstep(0.3, 0.75, n) * 2.0, ciuffi);
    vec3 luce = aria;
    float raggio = sole > 0.0 ? sole * fase * finestra(p) : 0.0;
    luce += raggi * raggio;
    for (int k = 0; k < 4; k++) {
      if (k >= nLuci) break;
      vec3 a = p - luciPos[k];
      luce += luciCol[k] / (dot(a, a) + 0.08);
    }
    // la polvere: puntini che salgono piano, visibili nella luce
    float g = rumore(p * 22.0 + vec3(0.0, -tempo * 0.25, tempo * 0.05));
    luce += particelle * smoothstep(0.86, 0.97, g) * (0.15 + raggio * 3.0) * raggi;
    float tr = exp(-d * dt);
    S += T * (1.0 - tr) * luce * forza;
    T *= tr;
  }
  gl_FragColor = vec4(col * T + S, 1.0);
}`;

// il rumore per la nebbia: 256 x 256 valori a caso, e nel verde gli stessi spostati di (37, 17)
let rumoreCondiviso = null;
function texturaRumore() {
  if (rumoreCondiviso) return rumoreCondiviso;
  const n = 256, r = new Uint8Array(n * n), d = new Uint8Array(n * n * 4);
  let s = 1234567;
  for (let i = 0; i < r.length; i++) { s = (Math.imul(s, 1664525) + 1013904223) >>> 0; r[i] = s >>> 24; }
  for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) {
    const i = (y * n + x) * 4;
    d[i] = r[y * n + x];
    d[i + 1] = r[((y - 17 + n) % n) * n + ((x - 37 + n) % n)];
    d[i + 3] = 255;
  }
  const t = new THREE.DataTexture(d, n, n, THREE.RGBAFormat, THREE.UnsignedByteType);
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.magFilter = t.minFilter = THREE.LinearFilter;
  t.generateMipmaps = false;
  t.needsUpdate = true;
  rumoreCondiviso = t;
  return t;
}

// la nebbia: va subito dopo il RenderPass, quando i colori sono ancora luce vera (prima del tone mapping)
export class NebbiaViola extends ShaderPass {
  constructor(camera, opzioni = {}) {
    const vec3 = () => new THREE.Vector3();
    super(new THREE.ShaderMaterial({
      defines: { PASSI: opzioni.passi ?? NEBBIA_VIOLA.passi },
      uniforms: {
        tDiffuse: { value: null }, tDepth: { value: null }, tRumore: { value: texturaRumore() },
        proiezioneInv: { value: camera.projectionMatrixInverse }, mondoCamera: { value: camera.matrixWorld },
        occhio: { value: vec3() }, tempo: { value: 0 }, vento: { value: vec3() }, aria: { value: vec3() },
        raggi: { value: vec3() }, soleDir: { value: new THREE.Vector3(0, -1, 0) }, sole: { value: 0 },
        densita: { value: 0 }, strato: { value: 0 }, altezza: { value: 1 }, quota: { value: 0 }, ciuffi: { value: 0 },
        scala: { value: 1 }, particelle: { value: 0 }, lontano: { value: 14 }, forza: { value: 1 },
        finO: { value: vec3() }, finU: { value: new THREE.Vector3(1, 0, 0) }, finV: { value: new THREE.Vector3(0, 1, 0) },
        vetri: { value: Array.from({ length: 8 }, () => new THREE.Vector4()) }, nVetri: { value: 0 },
        luciPos: { value: Array.from({ length: 4 }, vec3) }, luciCol: { value: Array.from({ length: 4 }, vec3) }, nLuci: { value: 0 },
      },
      vertexShader: VERTICI,
      fragmentShader: NEBBIA,
    }));
    this.camera = camera;
    this.opzioni = { ...NEBBIA_VIOLA };
    this.imposta(opzioni);
  }

  // cambia uno o piu' valori (anche mentre si gioca): nebbia.imposta({ densita: 0.12, luci: [...] })
  imposta(opzioni = {}) {
    const o = Object.assign(this.opzioni, opzioni);
    const u = this.uniforms;
    for (const k of ["densita", "strato", "altezza", "quota", "ciuffi", "scala", "particelle", "lontano", "forza"]) u[k].value = o[k];
    u.vento.value.fromArray(o.vento);
    u.aria.value.fromArray(o.aria);
    u.raggi.value.fromArray(o.raggi);
    u.sole.value = o.sole ? o.sole.forza ?? 1 : 0;
    if (o.sole) u.soleDir.value.fromArray(o.sole.direzione).normalize();
    const f = o.finestra;
    const vetri = f ? f.vetri.slice(0, 8) : [];
    u.nVetri.value = vetri.length;
    if (f) {
      u.finO.value.fromArray(f.origine);
      u.finU.value.fromArray(f.u || [1, 0, 0]).normalize();
      u.finV.value.fromArray(f.v || [0, 1, 0]).normalize();
      vetri.forEach((r, i) => u.vetri.value[i].fromArray(r));
    }
    const luci = (o.luci || []).slice(0, 4);
    u.nLuci.value = luci.length;
    luci.forEach((l, i) => {
      u.luciPos.value[i].fromArray(l.posizione);
      u.luciCol.value[i].fromArray(l.colore || o.caldo).multiplyScalar(l.forza ?? 0.18);
    });
    if (this.material.defines.PASSI !== o.passi) {
      this.material.defines.PASSI = o.passi;
      this.material.needsUpdate = true;
    }
  }

  render(renderer, writeBuffer, readBuffer, deltaTime, maskActive) {
    if (!readBuffer.depthTexture && !this.avvisato) {
      this.avvisato = true;
      console.warn("NebbiaViola: manca la profondita'. Dai all'EffectComposer un render target con rt.depthTexture = new THREE.DepthTexture(w, h)");
    }
    this.uniforms.tDepth.value = readBuffer.depthTexture;
    this.uniforms.tempo.value += deltaTime || 0;
    this.camera.getWorldPosition(this.uniforms.occhio.value);
    super.render(renderer, writeBuffer, readBuffer, deltaTime, maskActive);
  }
}

// il colore alla fine, dopo l'OutputPass: un po' di contrasto a "S", le ombre verso il blu viola e le luci verso il
// bianco freddo, la vignetta
export class ColoreViola extends ShaderPass {
  constructor(opzioni = {}) {
    const o = { ...COLORE_VIOLA, ...opzioni };
    super({
      uniforms: {
        tDiffuse: { value: null }, contrasto: { value: o.contrasto }, saturazione: { value: o.saturazione },
        vignetta: { value: o.vignetta }, tinta: { value: o.tinta },
        ombre: { value: new THREE.Vector3(...o.ombre) }, luci: { value: new THREE.Vector3(...o.luci) },
      },
      vertexShader: VERTICI,
      fragmentShader: `uniform sampler2D tDiffuse; uniform float contrasto, saturazione, vignetta, tinta; uniform vec3 ombre, luci;
varying vec2 vUv;
const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
vec3 tonoColore(vec3 c) {
  float l = dot(c, LUMA);
  vec3 t = mix(ombre, luci, smoothstep(0.05, 0.7, l));
  t /= max(dot(t, LUMA), 0.001);
  vec3 g = c * t;
  float lg = dot(g, LUMA);
  g = mix(vec3(lg), g, 0.85);
  return pow(max(g, vec3(0.0)), vec3(1.12)) * 0.9;
}
void main() {
  vec4 c = texture2D(tDiffuse, vUv);
  vec3 x = clamp(c.rgb, 0.0, 1.0);
  float l = dot(x, LUMA);
  x = clamp(mix(vec3(l), x, saturazione), 0.0, 1.0);
  x = mix(x, x * x * (3.0 - 2.0 * x), contrasto);
  x = mix(x, tonoColore(x), tinta);
  vec2 d = vUv - 0.5;
  x *= mix(1.0, smoothstep(0.85, 0.25, length(d * vec2(1.0, 0.75))), vignetta);
  gl_FragColor = vec4(x, c.a);
}`,
    });
  }
}
