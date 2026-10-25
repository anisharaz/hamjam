import { useEffect, useRef, useState } from 'react';
import { JamClient, canDecodeAac } from './engine.js';
import { Glyph, Icon, Logo } from './icons.jsx';

const LIVE = new Set(['connecting', 'connected', 'listening']);

const CHIP = {
  connecting: ['Connecting', 'warn'],
  connected: ['Waiting for audio', 'warn'],
  listening: ['Live', 'live'],
};

/** Mirrored equalizer bars drawn from the real playback level. */
function Bars({ jam, playing }) {
  const canvas = useRef(null);
  const playingRef = useRef(playing);
  playingRef.current = playing;

  useEffect(() => {
    const cv = canvas.current;
    const ctx = cv.getContext('2d');
    const N = 30;
    const v = new Array(N).fill(0.05);
    let raf;
    const draw = () => {
      const dpr = window.devicePixelRatio || 1;
      const w = cv.clientWidth, h = cv.clientHeight;
      if (cv.width !== w * dpr) { cv.width = w * dpr; cv.height = h * dpr; }
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, w, h);
      const lvl = playingRef.current ? jam.getLevel() : 0;
      const t = performance.now() / 1000;
      const slot = w / N, bw = slot * 0.56;
      ctx.fillStyle = playingRef.current ? '#1e6fe0' : 'rgba(30,111,224,0.28)';
      for (let i = 0; i < N; i++) {
        const wobble = (Math.sin(t * (2.2 + (i % 5) * 0.55) + i * 1.7) + 1) / 2;
        const centre = 1 - (Math.abs(i - N / 2) / (N / 2)) * 0.55;
        const target = playingRef.current ? 0.07 + 0.93 * lvl * (0.3 + 0.7 * wobble) * centre : 0.05;
        v[i] += (target - v[i]) * 0.28;
        const bh = Math.max(bw, v[i] * h);
        ctx.beginPath();
        ctx.roundRect(i * slot + (slot - bw) / 2, (h - bh) / 2, bw, bh, bw / 2);
        ctx.fill();
      }
      raf = requestAnimationFrame(draw);
    };
    draw();
    return () => cancelAnimationFrame(raf);
  }, [jam]);

  return <canvas ref={canvas} className="jp-bars" aria-hidden="true" />;
}

export default function JoinPage({ initialCode }) {
  const [code, setCode] = useState(initialCode);
  const [started, setStarted] = useState(false);
  const [state, setState] = useState('idle');
  const [reason, setReason] = useState('');
  const [playing, setPlaying] = useState(false);
  const [chat, setChat] = useState([]);
  const [notice, setNotice] = useState('');
  const [volume, setVolume] = useState(1);
  const [muted, setMuted] = useState(false);
  const [supported, setSupported] = useState(null);
  const [draft, setDraft] = useState('');
  const jam = useRef(null);
  const log = useRef(null);

  useEffect(() => { canDecodeAac().then(setSupported); }, []);
  useEffect(() => { document.title = started ? `HamJam · ${code}` : 'Join a jam · HamJam'; }, [started, code]);
  useEffect(() => { log.current?.scrollTo({ top: log.current.scrollHeight, behavior: 'smooth' }); }, [chat]);
  useEffect(() => () => jam.current?.leave(), []);
  useEffect(() => {
    if (!notice) return;
    const t = setTimeout(() => setNotice(''), 3500);
    return () => clearTimeout(t);
  }, [notice]);

  const onUpdate = (u) => {
    if (u.state) setState(u.state);
    if (u.reason) setReason(u.reason);
    if (u.playing !== undefined) setPlaying(u.playing);
    if (u.chat) setChat((c) => [...c.slice(-99), u.chat]);
    if (u.notice) setNotice(u.notice);
  };

  const join = (e) => {
    e?.preventDefault();
    if (code.length !== 6 || started) return;
    setStarted(true);
    setState('connecting');
    jam.current = new JamClient(onUpdate);
    jam.current.start(code).catch(() => onUpdate({ state: 'ended', reason: 'could not start audio' }));
  };

  const send = (e) => {
    e.preventDefault();
    const t = draft.trim();
    if (!t) return;
    jam.current?.chat(t);
    setDraft('');
  };

  const setVol = (v) => { setVolume(v); setMuted(false); jam.current?.setVolume(v); };
  const toggleMute = () => { const m = !muted; setMuted(m); jam.current?.setVolume(m ? 0 : volume); };
  const live = LIVE.has(state);

  return (
    <div className="jp">
      <header className="nav">
        <a className="brand" href="/" aria-label="HamJam home"><Logo size={36} /><span>HamJam</span></a>
        <nav><a href="/">Home</a></nav>
      </header>

      <main className="jp-main">
        {!started && (
          <form className="card jp-join" onSubmit={join}>
            <h1>Join a jam</h1>
            <p>Enter the 6-character code from your partner. The sound starts as soon as you join.</p>
            <input
              className="jp-code"
              value={code}
              onChange={(e) => setCode(e.target.value.replace(/[^A-Za-z0-9]/g, '').toUpperCase().slice(0, 6))}
              placeholder="CODE"
              aria-label="Invite code"
              autoFocus={!initialCode}
              autoComplete="off"
              autoCapitalize="characters"
              spellCheck="false"
            />
            <button className="btn" type="submit" disabled={code.length !== 6 || supported === false}>
              <Glyph name="play" size={20} /> Join and listen
            </button>
            {supported === false && (
              <p className="jp-warn">
                This browser can&apos;t decode the audio stream. Try the latest Chrome or Edge, or use the Android app.
              </p>
            )}
          </form>
        )}

        {started && state === 'unsupported' && (
          <div className="card jp-join">
            <h1>Browser not supported</h1>
            <p>This browser can&apos;t decode the audio stream. Try the latest Chrome or Edge, or use the Android app.</p>
            <a className="btn" href="/">Back to home</a>
          </div>
        )}

        {started && state !== 'unsupported' && (
          <div className="jp-grid">
            <section className="card jp-player">
              <div className="jp-head">
                <span className="jp-code-label">Jam <strong>{code}</strong></span>
                {live ? (
                  <span className={`chip ${CHIP[state][1]}`}><i />{CHIP[state][0]}</span>
                ) : (
                  <span className="chip end"><i />Ended</span>
                )}
              </div>

              <Bars jam={jam.current} playing={live && playing} />

              <div className="jp-controls">
                <button className="round" aria-label="Previous" disabled={!live} onClick={() => jam.current.control('previous')}>
                  <Glyph name="prev" size={26} />
                </button>
                <button className="round big" aria-label={playing ? 'Pause' : 'Play'} disabled={!live} onClick={() => jam.current.control('playPause')}>
                  <Glyph name={playing ? 'pause' : 'play'} size={34} />
                </button>
                <button className="round" aria-label="Next" disabled={!live} onClick={() => jam.current.control('next')}>
                  <Glyph name="next" size={26} />
                </button>
              </div>

              <div className="jp-vol">
                <button className="icon-btn" aria-label={muted ? 'Unmute' : 'Mute'} onClick={toggleMute} disabled={!live}>
                  <Icon name={muted || volume === 0 ? 'mute' : 'volume'} />
                </button>
                <input type="range" min="0" max="1" step="0.01" value={muted ? 0 : volume}
                       aria-label="Volume" onChange={(e) => setVol(+e.target.value)} disabled={!live} />
              </div>

              {notice && <p className="jp-notice" role="status">{notice}</p>}

              {!live && (
                <div className="jp-ended">
                  <p>{reason ? reason[0].toUpperCase() + reason.slice(1) : 'The jam has ended'}.</p>
                  <div className="cta">
                    <a className="btn" href="/">Back to home</a>
                    <a className="btn btn-ghost" href={`/j/${code}`}>Join again</a>
                  </div>
                </div>
              )}
              {live && <button className="btn btn-ghost jp-leave" onClick={() => jam.current.leave()}>Leave jam</button>}
            </section>

            <section className="card jp-chat">
              <h2>Chat</h2>
              <div className="jp-log" ref={log}>
                {chat.length === 0 && <p className="jp-empty">Live chat. Nothing is saved.</p>}
                {chat.map((m, i) => (
                  <p key={i} className={`msg ${m.from === 'guest' ? 'me' : 'them'}`}>{m.text}</p>
                ))}
              </div>
              <form className="jp-send" onSubmit={send}>
                <input value={draft} onChange={(e) => setDraft(e.target.value)} maxLength={500}
                       placeholder={live ? 'Message' : 'Jam ended'} disabled={!live} aria-label="Message" />
                <button className="round send" aria-label="Send" disabled={!live || !draft.trim()}>
                  <Icon name="send" />
                </button>
              </form>
            </section>
          </div>
        )}
      </main>
    </div>
  );
}
