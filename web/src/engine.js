// Browser listener for a HamJam room: WebSocket + WebCodecs AAC decoding + Web Audio playback.
import { frameTimestampUs, planSchedule } from './schedule.js';

const RELAY = import.meta.env.VITE_RELAY || `${location.protocol === 'https:' ? 'wss' : 'ws'}://${location.host}`;

const b64 = (s) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0));

/** True if this browser can decode the host's AAC stream. */
export async function canDecodeAac(sampleRate = 48000, channels = 2) {
  if (typeof AudioDecoder === 'undefined' || typeof AudioContext === 'undefined') return false;
  try {
    const r = await AudioDecoder.isConfigSupported({ codec: 'mp4a.40.2', sampleRate, numberOfChannels: channels });
    return !!r.supported;
  } catch {
    return false;
  }
}

/**
 * Usage: const jam = new JamClient(onUpdate); await jam.start('ABC123')  // from a click handler
 * onUpdate receives partial state: { state, reason, playing, chat }
 */
export class JamClient {
  constructor(onUpdate) {
    this.onUpdate = onUpdate;
    this.ws = null;
    this.ctx = null;
    this.decoder = null;
    this.sampleRate = 48000;
    this.frameNo = 0;
    this.nextTime = 0;
    this.volume = 1;
    this.closed = false;
    this.listening = false;
  }

  async start(code) {
    // created inside the click that called start(), so the browser lets audio play
    this.ctx = new AudioContext({ latencyHint: 'playback' });
    await this.ctx.resume();
    this.gain = this.ctx.createGain();
    this.analyser = this.ctx.createAnalyser();
    this.analyser.fftSize = 1024;
    this.analyser.connect(this.gain).connect(this.ctx.destination);
    this.samples = new Float32Array(this.analyser.fftSize);

    this.onUpdate({ state: 'connecting' });
    const ws = new WebSocket(RELAY);
    ws.binaryType = 'arraybuffer';
    this.ws = ws;
    ws.onopen = () => ws.send(JSON.stringify({ type: 'join', code, client: 'web' }));
    ws.onmessage = (e) => (typeof e.data === 'string' ? this.#text(JSON.parse(e.data)) : this.#audio(e.data));
    ws.onclose = () => this.#finish('disconnected');
    ws.onerror = () => this.#finish('could not reach the server');
  }

  #text(m) {
    switch (m.type) {
      case 'joined':
        this.onUpdate({ state: 'connected' });
        break;
      case 'error':
        this.#finish(m.error === 'room_not_found' ? 'room not found' : 'error');
        break;
      case 'ended':
        this.#finish('the host ended the jam');
        break;
      case 'meta':
        if (m.csd) this.#configure(m);
        break;
      case 'playback':
        this.onUpdate({ playing: !!m.playing });
        break;
      case 'chat':
        this.onUpdate({ chat: { from: m.from, text: m.text } });
        break;
      case 'swap_declined':
        if (m.reason === 'unsupported') this.onUpdate({ notice: 'Only the Android app can host.' });
        break;
    }
  }

  async #configure({ sampleRate, channels, csd }) {
    if (this.decoder) return;
    this.sampleRate = sampleRate;
    const config = { codec: 'mp4a.40.2', sampleRate, numberOfChannels: channels, description: b64(csd) };
    if (!(await canDecodeAac(sampleRate, channels))) return this.#finish('unsupported');
    this.decoder = new AudioDecoder({
      output: (data) => this.#play(data),
      error: () => this.#finish('audio decoding failed'),
    });
    this.decoder.configure(config);
  }

  #audio(buf) {
    if (!this.decoder || this.decoder.state !== 'configured') return;
    // the host sends raw AAC frames; drop frames if the decoder is falling behind
    if (this.decoder.decodeQueueSize > 25) return;
    this.decoder.decode(
      new EncodedAudioChunk({ type: 'key', timestamp: frameTimestampUs(this.frameNo++, this.sampleRate), data: buf }),
    );
  }

  #play(data) {
    try {
      const { numberOfChannels: ch, numberOfFrames: n, sampleRate } = data;
      const buffer = this.ctx.createBuffer(ch, n, sampleRate);
      const plane = new Float32Array(n);
      for (let c = 0; c < ch; c++) {
        data.copyTo(plane, { planeIndex: c, format: 'f32-planar' });
        buffer.copyToChannel(plane, c);
      }
      const { start, drop } = planSchedule(this.ctx.currentTime, this.nextTime);
      if (drop) return;
      const src = this.ctx.createBufferSource();
      src.buffer = buffer;
      src.connect(this.analyser);
      src.start(start);
      this.nextTime = start + buffer.duration;
      if (!this.listening) {
        this.listening = true;
        this.onUpdate({ state: 'listening' });
      }
    } finally {
      data.close();
    }
  }

  #finish(reason) {
    if (this.closed) return;
    this.closed = true;
    try { this.decoder?.close(); } catch { /* already closed */ }
    try { this.ws?.close(); } catch { /* already closed */ }
    this.ctx?.close().catch(() => {});
    this.onUpdate({ state: reason === 'unsupported' ? 'unsupported' : 'ended', reason });
  }

  /** 0..1 loudness of what is playing right now, for the visualizer. */
  getLevel() {
    if (!this.analyser || this.closed) return 0;
    this.analyser.getFloatTimeDomainData(this.samples);
    let sum = 0;
    for (const v of this.samples) sum += v * v;
    return Math.min(1, Math.sqrt(sum / this.samples.length) * 4.5);
  }

  setVolume(v) {
    this.volume = v;
    if (this.gain) this.gain.gain.value = v;
  }

  control(key) { this.#send({ type: 'control', key }); }
  chat(text) { this.#send({ type: 'chat', text }); }
  leave() { this.#finish('you left'); }

  #send(obj) {
    if (this.ws?.readyState === WebSocket.OPEN) this.ws.send(JSON.stringify(obj));
  }
}
