using System;
using System.Collections.Generic;
using UnityEngine;

namespace SurfImpact
{
    /// <summary>
    /// All audio is synthesised at startup (no audio assets): SFX, a mellow
    /// procedural music loop and an ocean ambience bed.
    /// </summary>
    public class SurfAudio : MonoBehaviour
    {
        const int Rate = 44100;
        readonly Dictionary<string, AudioClip> _clips = new Dictionary<string, AudioClip>();
        AudioSource _sfx, _music, _ambient;
        float _master = .8f;
        bool _muted;

        public static SurfAudio Build()
        {
            var go = new GameObject("Audio");
            var audio = go.AddComponent<SurfAudio>();
            audio.Init();
            return audio;
        }

        void Init()
        {
            _sfx = gameObject.AddComponent<AudioSource>();
            _sfx.playOnAwake = false;
            _sfx.spatialBlend = 0f;
            _music = gameObject.AddComponent<AudioSource>();
            _music.playOnAwake = false;
            _music.loop = true;
            _music.spatialBlend = 0f;
            _ambient = gameObject.AddComponent<AudioSource>();
            _ambient.playOnAwake = false;
            _ambient.loop = true;
            _ambient.spatialBlend = 0f;

            BuildClips();
            _music.clip = _clips["music"];
            _music.volume = .32f;
            _ambient.clip = _clips["jungle"];
            _ambient.volume = .30f;
            _music.Play();
            _ambient.Play();
        }

        // ------------------------------------------------------------- public API

        public void Play(string name, float volume = 1f)
        {
            if (_muted) return;
            if (_clips.TryGetValue(name, out AudioClip c))
                _sfx.PlayOneShot(c, Mathf.Clamp01(volume) * _master);
        }

        public void SetMusic(bool on)
        {
            if (_music == null) return;
            if (on && !_music.isPlaying) _music.Play();
            else if (!on && _music.isPlaying) _music.Pause();
        }

        public void SetAmbient(bool on)
        {
            if (_ambient == null) return;
            if (on && !_ambient.isPlaying) _ambient.Play();
            else if (!on && _ambient.isPlaying) _ambient.Pause();
        }

        public void SetMasterVolume(float v)
        {
            _master = Mathf.Clamp01(v);
            if (_music != null) _music.volume = .32f * _master;
            if (_ambient != null) _ambient.volume = .38f * _master;
        }

        public void SetMuted(bool muted)
        {
            _muted = muted;
            AudioListener.volume = muted ? 0f : 1f;
        }

        public bool Muted => _muted;

        // ------------------------------------------------------------ generation

        void BuildClips()
        {
            _clips["coin"] = Make("coin", .30f, Coin);
            _clips["heart"] = Make("heart", .55f, Heart);
            _clips["bolt"] = Make("bolt", .38f, Bolt);
            _clips["gate"] = Make("gate", .60f, Gate);
            _clips["trick"] = Make("trick", .55f, Trick);
            _clips["jump"] = Make("jump", .30f, Jump);
            _clips["land"] = Make("land", .20f, Land);
            _clips["crash"] = Make("crash", .55f, Crash);
            _clips["boost"] = Make("boost", .60f, Boost);
            _clips["kraken"] = Make("kraken", 1.1f, Kraken);
            _clips["tick"] = Make("tick", .07f, Tick);
            _clips["click"] = Make("click", .08f, Click);
            _clips["gameover"] = Make("gameover", 1.1f, GameOver);
            _clips["win"] = Make("win", 1.0f, Win);

            _clips["ocean"] = MakeLoop("ocean", 8f, OceanBed);
            _clips["jungle"] = MakeLoop("jungle", 12f, Jungle);
            _clips["music"] = MakeLoop("music", 16f, Music);
        }

        delegate float Sampler(float t, int index, float duration);

        AudioClip Make(string name, float duration, Sampler sampler)
        {
            int count = Mathf.CeilToInt(duration * Rate);
            var data = new float[count];
            float peak = 0f;
            for (int i = 0; i < count; i++)
            {
                float t = i / (float)Rate;
                data[i] = sampler(t, i, duration);
                peak = Mathf.Max(peak, Mathf.Abs(data[i]));
            }
            if (peak > 0f) for (int i = 0; i < count; i++) data[i] = data[i] / peak * .85f;
            var clip = AudioClip.Create(name, count, 1, Rate, false);
            clip.SetData(data, 0);
            return clip;
        }

        /// <summary>Loops get a short edge fade and a tail/head crossfade to avoid clicks.</summary>
        AudioClip MakeLoop(string name, float duration, Sampler sampler)
        {
            int count = Mathf.CeilToInt(duration * Rate);
            var data = new float[count];
            float peak = 0f;
            for (int i = 0; i < count; i++)
            {
                float t = i / (float)Rate;
                data[i] = sampler(t, i, duration);
                peak = Mathf.Max(peak, Mathf.Abs(data[i]));
            }
            if (peak > 0f) for (int i = 0; i < count; i++) data[i] = data[i] / peak;
            int fade = Mathf.Min(count / 3, Rate / 4);
            for (int i = 0; i < fade; i++)
            {
                float a = i / (float)fade;
                data[i] *= a;
                data[count - 1 - i] *= a;
            }
            var clip = AudioClip.Create(name, count, 1, Rate, false);
            clip.SetData(data, 0);
            return clip;
        }

        static float Sine(float t, float freq) => Mathf.Sin(t * freq * Mathf.PI * 2f);
        static float Env(float t, float dur, float attack, float release)
        {
            float a = attack <= 0 ? 1f : Mathf.Clamp01(t / attack);
            float r = release <= 0 ? 1f : Mathf.Clamp01((dur - t) / release);
            return Mathf.Min(a, r);
        }
        static float Noise(ref uint state)
        {
            state ^= state << 13; state ^= state >> 17; state ^= state << 5;
            return (state & 0xFFFFFF) / 8388607.5f - 1f;
        }

        // ---------------------------------------------------------------- SFX

        float Coin(float t, int i, float dur)
        {
            float f = t < .08f ? 988f : 1318f;
            float env = Mathf.Exp(-Mathf.Max(0f, t - .02f) * 13f);
            float s = Sine(t, f) + .22f * Sine(t, f * 2f) + .08f * Sine(t, f * 3f);
            return s * env * .55f;
        }

        float Heart(float t, int i, float dur)
        {
            float[] notes = { 523.25f, 659.25f, 783.99f, 1046.5f };
            float sum = 0f;
            for (int n = 0; n < notes.Length; n++)
            {
                float start = n * .085f;
                if (t < start) continue;
                float lt = t - start;
                float env = Mathf.Exp(-lt * 7f) * Mathf.Clamp01(lt * 120f);
                sum += (Sine(lt, notes[n]) + .25f * Sine(lt, notes[n] * 2.01f)) * env;
            }
            return sum * .35f;
        }

        float Bolt(float t, int i, float dur)
        {
            float f = Mathf.Lerp(300f, 1300f, Mathf.Pow(t / dur, .55f));
            float env = Env(t, dur, .005f, .2f);
            float s = Sine(t, f) + .35f * Mathf.Sign(Sine(t, f * .5f)) + .15f * Sine(t, f * 2.3f);
            return s * env * .4f;
        }

        float Gate(float t, int i, float dur)
        {
            float[] notes = { 523.25f, 659.25f, 783.99f };
            float sum = 0f;
            for (int n = 0; n < notes.Length; n++)
            {
                float start = n * .09f;
                if (t < start) continue;
                float lt = t - start;
                float env = Mathf.Exp(-lt * 4.5f) * Mathf.Clamp01(lt * 100f);
                sum += (Sine(lt, notes[n]) + .3f * Sine(lt, notes[n] * 2f)) * env;
            }
            return sum * .4f;
        }

        float Trick(float t, int i, float dur)
        {
            float[] notes = { 659.25f, 783.99f, 987.77f, 1318.5f };
            float sum = 0f;
            for (int n = 0; n < notes.Length; n++)
            {
                float start = n * .07f;
                if (t < start) continue;
                float lt = t - start;
                sum += Sine(lt, notes[n]) * Mathf.Exp(-lt * 10f) * Mathf.Clamp01(lt * 150f);
            }
            return sum * .4f;
        }

        float Jump(float t, int i, float dur)
        {
            float f = Mathf.Lerp(220f, 760f, t / dur);
            float env = Env(t, dur, .01f, .14f);
            float s = Sine(t, f) * .5f + Sine(t, f * 1.5f) * .2f;
            return s * env * .5f;
        }

        float Land(float t, int i, float dur)
        {
            float f = Mathf.Lerp(120f, 52f, t / dur);
            float env = Mathf.Exp(-t * 20f);
            uint st = (uint)(i + 1) * 2654435761u;
            return (Sine(t, f) * .7f + Noise(ref st) * .25f) * env * .5f;
        }

        float Crash(float t, int i, float dur)
        {
            uint st = 1234567u + (uint)i;
            float n = Noise(ref st);
            // cheap one-pole smoothing
            float env = Mathf.Exp(-t * 6.5f);
            float thump = Sine(t, 75f) * Mathf.Exp(-t * 16f);
            return (n * .5f + thump * .8f) * env * .7f;
        }

        float Boost(float t, int i, float dur)
        {
            float f = Mathf.Lerp(160f, 1400f, Mathf.Pow(t / dur, .7f));
            float env = Env(t, dur, .02f, .3f);
            float saw = Mathf.Repeat(t * f, 1f) * 2f - 1f;
            return (saw * .25f + Sine(t, f) * .4f) * env * .5f;
        }

        float Kraken(float t, int i, float dur)
        {
            float f = 48f + Mathf.Sin(t * 5f) * 7f;
            float env = Env(t, dur, .15f, .5f);
            float growl = Mathf.Repeat(t * f, 1f) * 2f - 1f;
            uint st = 99173u + (uint)i / 4;
            float n = Noise(ref st);
            return (growl * .45f + n * .18f + Sine(t, f * 2f) * .2f) * env * .6f;
        }

        float Tick(float t, int i, float dur)
        {
            return Sine(t, 1150f) * Mathf.Exp(-t * 45f) * .5f;
        }

        float Click(float t, int i, float dur)
        {
            return Sine(t, 780f) * Mathf.Exp(-t * 60f) * .35f;
        }

        float GameOver(float t, int i, float dur)
        {
            float[] notes = { 440f, 349.23f, 261.63f, 196f };
            float sum = 0f;
            for (int n = 0; n < notes.Length; n++)
            {
                float start = n * .18f;
                if (t < start) continue;
                float lt = t - start;
                sum += Sine(lt, notes[n]) * Mathf.Exp(-lt * 3.2f) * Mathf.Clamp01(lt * 80f);
            }
            return sum * .4f;
        }

        float Win(float t, int i, float dur)
        {
            float[] notes = { 523.25f, 659.25f, 783.99f, 1046.5f, 1318.5f };
            float sum = 0f;
            for (int n = 0; n < notes.Length; n++)
            {
                float start = n * .1f;
                if (t < start) continue;
                float lt = t - start;
                sum += Sine(lt, notes[n]) * Mathf.Exp(-lt * 3.5f) * Mathf.Clamp01(lt * 90f);
            }
            return sum * .4f;
        }

        // -------------------------------------------------------------- loops

        float OceanBed(float t, int i, float dur)
        {
            // slow overlapping swells made of filtered noise + low sine
            uint st = (uint)(i * 2654435761u + 17u);
            float n = Noise(ref st);
            // amplitude modulation with two slow periods that complete whole cycles in 8s
            float swell = .55f + .25f * Mathf.Sin(t * Mathf.PI * 2f * .125f) + .12f * Mathf.Sin(t * Mathf.PI * 2f * .25f + 1.1f);
            float rumble = Sine(t, 48f) * .05f + Sine(t, 31f + Mathf.Sin(t * .4f) * 4f) * .05f;
            return (n * .22f * swell + rumble);
        }

        float Jungle(float t, int i, float dur)
        {
            // soft wind bed
            uint st = (uint)(i * 2654435761u + 91u);
            float n = Noise(ref st);
            float wind = n * (.10f + .05f * Mathf.Sin(t * Mathf.PI * 2f * .083f + .7f));

            // low insect hum, slowly swelling
            float hum = Mathf.Sin(t * Mathf.PI * 2f * 180f) * .012f
                      * (.5f + .5f * Mathf.Sin(t * Mathf.PI * 2f * .17f));

            // sparse two-note bird whistles at fixed times
            float chirp = 0f;
            float[] times = { 1.1f, 2.9f, 5.4f, 7.1f, 9.5f, 10.9f };
            for (int k = 0; k < times.Length; k++)
            {
                float lt = t - times[k];
                if (lt < 0f || lt > .24f) continue;
                float f = 2100f + 700f * Mathf.Sin(lt * 80f);
                float env = Mathf.Sin(Mathf.Clamp01(lt / .24f) * Mathf.PI);
                chirp += Mathf.Sin(lt * f * Mathf.PI * 2f) * env * .11f;
            }
            return wind + hum + chirp;
        }

        float Music(float t, int i, float dur)
        {
            // 4 x 4s chords: Am, F, C, G. Pads + pentatonic plucks + soft bass.
            float[][] chords =
            {
                new[] { 110f, 164.81f, 220f, 261.63f },  // A2 E3 A3 C4
                new[] { 87.31f, 130.81f, 174.61f, 220f }, // F2 C3 F3 A3
                new[] { 130.81f, 196f, 261.63f, 329.63f },// C3 G3 C4 E4
                new[] { 98f, 146.83f, 196f, 246.94f },    // G2 D3 G3 B3
            };
            float[] scale = { 440f, 523.25f, 587.33f, 659.25f, 783.99f, 880f, 1046.5f };
            int chordIndex = Mathf.FloorToInt(t / 4f) % chords.Length;
            float local = t - Mathf.Floor(t / 4f) * 4f;
            float sum = 0f;
            float[] chord = chords[chordIndex];
            float padEnv = Mathf.Clamp01(local / .9f) * Mathf.Clamp01((4f - local) / 1f);
            for (int n = 0; n < chord.Length; n++)
            {
                float detune = 1f + (n - 1.5f) * .0012f;
                sum += Sine(t, chord[n] * detune) * .055f * padEnv;
                sum += Sine(t, chord[n] * 2.001f * detune) * .018f * padEnv;
            }
            // plucks every eighth note
            float step = .5f;
            int stepIndex = Mathf.FloorToInt(t / step);
            float stepT = t - stepIndex * step;
            staticPluckPattern(stepIndex, scale, out float note, out float amp);
            float pluckEnv = Mathf.Exp(-stepT * 6.5f) * Mathf.Clamp01(stepT * 200f);
            sum += (Sine(stepT, note) + .28f * Sine(stepT, note * 2f)) * pluckEnv * amp * .16f;
            // bass on each beat
            float beatT = t - Mathf.Floor(t / 1f);
            float bassEnv = Mathf.Exp(-beatT * 4f) * .9f;
            sum += Sine(t, chord[0] * .5f) * bassEnv * .10f;
            // soft kick at chord start
            float kickEnv = Mathf.Exp(-local * 9f);
            sum += Sine(local, 55f) * kickEnv * .16f;
            return sum;
        }

        static void staticPluckPattern(int step, float[] scale, out float note, out float amp)
        {
            int[] pattern = { 0, 2, 1, 3, 2, 4, 3, 5, 1, 3, 2, 4, 0, 5, 4, 2, 0, 3, 2, 1, 3, 5, 4, 2, 1, 4, 3, 5, 2, 3, 4, 1 };
            int idx = pattern[step % pattern.Length];
            note = scale[idx];
            amp = (step % 2 == 0) ? 1f : .7f;
        }
    }
}
