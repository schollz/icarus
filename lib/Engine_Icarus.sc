// Engine_Icarus

// Inherit methods from CroneEngine
Engine_Icarus : CroneEngine {

	// MxSamples specific
	var icarusPlayer;
	var osfun;
	// MxSamples ^

	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

	alloc {

		(0..5).do({arg i; 
			SynthDef("icarussynth"++i,{ 
				arg amp=0.5, hz=220, pan=0, envgate=0,
				attack=0.015,decay=1,release=2,sustain=0.9,
				lpf=20000,portamento=0.1,destruction=0,
				feedback=0.5,delaytime=0.25, sublevel=0;

				// vars
				var ender,snd,local,in,ampcheck;

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

				// dreamcrusher
				// try using SawTooth for PWM
				in = Splay.ar(Pulse.ar(Lag.kr(hz+(
					SinOsc.kr(LFNoise0.kr(1))*
					(((hz).cpsmidi+1).midicps-(hz))/5
					),portamento),
						LFTri.kr(LFNoise0.kr(1)*3).range(0.45,0.55)
						// LinLin.kr(SinOsc.kr(LFNoise0.kr(1)*3),-1,1,0.45,0.55)
				));
				// add suboscillator
				in = in + (sublevel*Splay.ar(Pulse.ar(Lag.kr(hz/2+(
					SinOsc.kr(LFNoise0.kr(1))*
					(((hz/2).cpsmidi+1).midicps-(hz/2))/5
					),portamento),
						LFTri.kr(LFNoise0.kr(1)*3).range(0.45,0.55)
						// LinLin.kr(SinOsc.kr(LFNoise0.kr(1)*3),-1,1,0.45,0.55)
				)));
				in = Balance2.ar(in[0] ,in[1],SinOsc.kr(
					LinLin.kr(LFNoise0.kr(0.1),-1,1,0.05,0.2)
				)*0.1);
				in = in * ender;
			    ampcheck = Amplitude.kr(Mix.ar(in));
			    in = in * (ampcheck > 0.02); // noise gate
			    local = LocalIn.ar(2);
			    local = OnePole.ar(local, 0.4);
			    local = OnePole.ar(local, -0.08);
			    local = Rotate2.ar(local[0], local[1],0.2);
				local = DelayN.ar(local, 0.5,
					// VarLag.kr(LinLin.kr(LFNoise0.kr(0.1),-1,1,0.15,0.3),1/0.1,warp:\sine)
					// VarLag.kr(delaytime,0.1,warp:\sine)
					Lag.kr(delaytime,0.05)+rrand(-0.05,0.05)
				);
			    local = LeakDC.ar(local);
			    local = ((local + in) * 1.25).softclip;
			    local = LPF.ar(local,Lag.kr(lpf,1));
				// add destruction
				local = ((local*((1-EnvGen.kr(
				        Env(
				            levels: [0, 1,0], 
				            times: [0.1,0.1],
							curve:\sine,
				        ),
				        gate: Dust.kr(destruction)
				))))+local)/2;



			    LocalOut.ar(local*Lag.kr(feedback,1));
				snd = Balance2.ar(local[0] * 0.2,local[1]*0.2,SinOsc.kr(
					LinLin.kr(LFNoise0.kr(0.1),-1,1,0.05,0.2)
				)*0.1);
				

				// manual pan
				snd = Mix.ar([
					Pan2.ar(snd[0],-1+(2*pan),amp),
					Pan2.ar(snd[1],1+(2*pan),amp),
				]);
			    SendTrig.kr(Dust.kr(10.0),0,Amplitude.kr(snd[0]+snd[1],3,3));
				Out.ar(0,snd)
			}).add;	
		});

	    osfun = OSCFunc(
	    	{ 
	    		arg msg, time; 
	    		if (msg[3]>0, {
		    		// [time, msg].postln;
					NetAddr("127.0.0.1", 10111).sendMsg("ampcheck",time,msg[3]);   //sendMsg works out the correct OSC message for you
	    		},{})
	    	},'/tr', context.server.addr);

		icarusPlayer = Array.fill(4,{arg i;
			Synth("icarussynth"++i, target:context.xg);
		});

		this.addCommand("icaruson","if", { arg msg;
			// lua is sending 1-index
			icarusPlayer[msg[1]-1].set(
				\envgate,1,
				\hz,msg[2],
			);
		});

		this.addCommand("icarusoff","i", { arg msg;
			// lua is sending 1-index
			icarusPlayer[msg[1]-1].set(
				\envgate,0,
			);
		});

		this.addCommand("amp","f", { arg msg;
			(0..5).do({arg i; 
				icarusPlayer[i].set(\amp,msg[1]);
			});
		});

		this.addCommand("pan","f", { arg msg;
			(0..5).do({arg i; 
				icarusPlayer[i].set(\pan,msg[1]);
			});
		});

		this.addCommand("attack","f", { arg msg;
			(0..5).do({arg i; 
				icarusPlayer[i].set(\attack,msg[1]);
			});
		});

		this.addCommand("release","f", { arg msg;
			(0..5).do({arg i; 
				icarusPlayer[i].set(\release,msg[1]);
			});
		});

		this.addCommand("decay","f", { arg msg;
			(0..5).do({arg i; 
				icarusPlayer[i].set(\decay,msg[1]);
			});
		});

		this.addCommand("sustain","f", { arg msg;
			(0..5).do({arg i; 
				icarusPlayer[i].set(\sustain,msg[1]);
			});
		});

		this.addCommand("delaytime","f", { arg msg;
			(0..5).do({arg i; 
				icarusPlayer[i].set(\delaytime,msg[1]);
			});
		});

		this.addCommand("feedback","f", { arg msg;
			(0..5).do({arg i; 
				icarusPlayer[i].set(\feedback,msg[1]);
			});
		});

		this.addCommand("destruction","f", { arg msg;
			(0..5).do({arg i; 
				icarusPlayer[i].set(\destruction,msg[1]);
			});
		});

		this.addCommand("lpf","f", { arg msg;
			(0..5).do({arg i; 
				icarusPlayer[i].set(\lpf,msg[1]);
			});
		});

		this.addCommand("portamento","f", { arg msg;
			(0..5).do({arg i; 
				icarusPlayer[i].set(\portamento,msg[1]);
			});
		});

		this.addCommand("sub","f", { arg msg;
			(0..5).do({arg i; 
				icarusPlayer[i].set(\sublevel,msg[1]);
			});
		});

	}

	free {
		(0..5).do({arg i; icarusPlayer[i].free});
		osfun.free;
	}
}
