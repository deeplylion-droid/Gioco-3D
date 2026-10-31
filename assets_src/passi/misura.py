import subprocess, numpy as np, glob, os, sys
def leggi(f):
    raw=subprocess.run(['ffmpeg','-loglevel','error','-i',f,'-f','f32le','-ac','1','-ar','48000','-'],capture_output=True).stdout
    return np.frombuffer(raw,np.float32)
def db(x): return 20*np.log10(max(x,1e-9))
def misura(f):
    x=leggi(f); sr=48000
    a=np.abs(x); pk=a.max(); ip=int(a.argmax())
    env=np.convolve(a,np.ones(48)/48,'same')
    on=np.argmax(env>0.1*env.max()); att=(np.argmax(env>0.9*env.max())-on)/sr*1000
    above=np.where(env>env.max()*0.0316)[0]  # -30 dB
    dur=(above[-1]-above[0])/sr*1000 if len(above) else 0
    seg=x[on:on+int(0.03*sr)]; S=np.abs(np.fft.rfft(seg*np.hanning(len(seg))))**2; fr=np.fft.rfftfreq(len(seg),1/sr)
    alte=S[fr>4000].sum()/S.sum(); cen=(fr*S).sum()/S.sum()
    S2=np.abs(np.fft.rfft(x*np.hanning(len(x))))**2; fr2=np.fft.rfftfreq(len(x),1/sr); cen2=(fr2*S2).sum()/S2.sum()
    rms=np.sqrt(np.mean(x[above[0]:above[-1]]**2)) if len(above)>1 else 0
    return dict(picco=db(pk),rms=db(rms),attacco_ms=att,durata_ms=dur,alte_4k_30ms=alte*100,centroide_attacco=cen,centroide=cen2,crest=db(pk)-db(rms))
gruppi=sys.argv[1:]
for g in gruppi:
    fs=sorted(glob.glob(g))
    ms=[misura(f) for f in fs]
    k=ms[0].keys()
    print(os.path.basename(g).ljust(28), '  '.join('%s %.1f'%(kk, np.mean([m[kk] for m in ms])) for kk in k))
