"""Original synthetic environmental textures, without speech or copyrighted music."""
from pathlib import Path
import wave,numpy as np
root=Path(__file__).resolve().parents[1]
folder=root/'assets/audio';folder.mkdir(exist_ok=True)
rate=22050;duration=16;n=rate*duration;t=np.arange(n)/rate;rng=np.random.default_rng(618)
for name in ['sea','wind','waterfall']:
    noise=rng.standard_normal(n)
    cutoff={'sea':700,'wind':350,'waterfall':2300}[name]
    spectrum=np.fft.rfft(noise);freq=np.fft.rfftfreq(n,1/rate)
    spectrum*=1/(1+(freq/cutoff)**2)
    signal=np.fft.irfft(spectrum,n=n)
    envelope=0.65+0.30*np.sin(2*np.pi*t/(8 if name=='sea' else 16))
    signal=signal*envelope
    # Seamless periodic bandlimited noise, normalized with generous headroom.
    signal=signal/max(abs(signal))*0.30
    pcm=(signal*32767).astype('<i2')
    with wave.open(str(folder/(name+'.wav')),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate);f.writeframes(pcm.tobytes())
    (folder/(name+'.wav.import')).write_text('[remap]\nimporter="wav"\ntype="AudioStreamWAV"\n\n[deps]\nsource_file="res://assets/audio/'+name+'.wav"\n\n[params]\nforce/max_rate=false\nedit/loop_mode=2\nedit/loop_begin=0\nedit/loop_end=-1\n',encoding='utf-8')
(folder/'SOURCE.txt').write_text('Original project-generated ambient sound textures. Seed 618. No human speech, no song samples. tools/create_ambience.py. CC0 dedication for these three WAV files only.\n',encoding='utf-8')
print('Created 3 original ambient loops.')
