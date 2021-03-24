// Engine_Shadow

// Inherit methods from CroneEngine
Engine_Shadow : CroneEngine {

	// MxSamples specific
	var shadowPlayer;
	// MxSamples ^

	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

	alloc {

		(0..5).do({arg i; 
			SynthDef("shadowsynth"++i,{ 
				arg amp=0.5, hz=220, pan=0, envgate=1,
				attack=0.015,decay=1,release=2,sustain=0.9,
				lpf=20000,
				feedback=0.5,delaytime=0.25;

				// vars
				var ender,snd,local,in,ampcheck;

				// dreamcrusher
				in = Splay.ar(Pulse.ar(Lag.ar(hz*
						LinLin.kr(SinOsc.kr(LFNoise0.kr(1)/2),-1,1,0.99,1.01),1),
						LinLin.kr(SinOsc.kr(LFNoise0.kr(1)),-1,1,0.45,0.55)
				));
				in = Balance2.ar(in[0] ,in[1],SinOsc.kr(
					LinLin.kr(LFNoise0.kr(0.1),-1,1,0.05,0.2)
				)*0.1);
			    ampcheck = Amplitude.kr(Mix.ar(in));
			    in = in * (ampcheck > 0.02); // noise gate
			    local = LocalIn.ar(2);
			    local = OnePole.ar(local, 0.4);
			    local = OnePole.ar(local, -0.08);
			    local = Rotate2.ar(local[0], local[1],0.2);
				local = DelayN.ar(local, 0.5,
					VarLag.kr(delaytime,0.1,warp:\sine)
				);
			    local = LeakDC.ar(local);
			    local = ((local + in) * 1.25).softclip;
			    local = LPF.ar(local,lpf);
			    LocalOut.ar(local*feedback)
				snd = Balance2.ar(local[0] * 0.2,local[1]*0.2,SinOsc.kr(
					LinLin.kr(LFNoise0.kr(0.1),-1,1,0.05,0.2)
				)*0.1);

				// envelope stuff
				ender = EnvGen.ar(
					Env.new(
						curve: 'cubed',
						levels: [0,1,sustain,0],
						times: [attack+0.015,decay,release],
						releaseNode: 2,
					),
					gate: envgate,
				);
				

				// manual pan
				snd = Mix.ar([
					Pan2.ar(snd[0],-1+(2*pan),amp),
					Pan2.ar(snd[1],1+(2*pan),amp),
				]);
				snd = snd * ender;
				Out.ar(0,snd)
			}).add;	
		});

		shadowPlayer = Array.fill(4,{arg i;
			Synth("shadowsynth"++i, target:context.xg);
		});

		this.addCommand("shadowon","iffffffffff", { arg msg;
			// lua is sending 1-index
			shadowPlayer[msg[1]-1].set(
				\envgate,1,
				\hz,msg[2],
				\amp,msg[3],
				\pan,msg[4],
				\attack,msg[5],
				\decay,msg[6],
				\sustain,msg[7],
				\release,msg[8],
				\lpf,msg[9],
				\feedback,msg[10],
				\delaytime,msg[11],
			);
		});

		this.addCommand("shadowoff","i", { arg msg;
			// lua is sending 1-index
			shadowPlayer[msg[1]-1].set(
				\envgate,0,
			);
		});

	}

	free {
		(0..5).do({arg i; shadowPlayer[i].free});
	}
}
