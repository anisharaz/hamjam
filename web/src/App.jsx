import { useState } from 'react';
import JoinPage from './JoinPage.jsx';
import PhoneMock from './PhoneMock.jsx';
import { Logo, Icon } from './icons.jsx';

// Same-origin: the relay streams the newest GitHub release as a real file download,
// so the browser (or the GitHub app) never takes over the link.
const APK_URL = '/download/latest.apk';
const RELEASES_URL = 'https://github.com/anisharaz/hamjam/releases';

const STEPS = [
  { n: 1, title: 'Host starts a jam', text: 'Open HamJam, tap Start hosting and allow screen capture once. You get a 6-character code.' },
  { n: 2, title: 'Partner joins', text: 'They install HamJam, type the code and tap join. The sound starts within a second.' },
  { n: 3, title: 'Play anything', text: 'Spotify, YouTube, a local file, a podcast. If your phone plays it, they hear it.' },
];

const FEATURES = [
  { icon: 'app', title: 'Any music app', text: 'Not tied to one service. HamJam shares what your phone is playing, calls and notifications stay out.' },
  { icon: 'play', title: 'Shared controls', text: 'The listener can play, pause, skip and go back, and it happens on the host\'s phone.' },
  { icon: 'chat', title: 'Live chat', text: 'Talk while you listen. Messages are relayed live and never stored anywhere.' },
  { icon: 'swap', title: 'Switch sides', text: 'Want to pick the next song? Ask to host, your partner approves, and you swap roles in the same jam.' },
  { icon: 'app', title: 'Listen from a computer', text: 'Your partner can open a link in Chrome or Edge on a laptop and listen, chat and use the controls. Only an Android phone can host.' },
  { icon: 'lock', title: 'Private by design', text: 'No accounts, no history. Audio is passed through, not recorded. Rooms vanish when the jam ends.' },
];

const FAQ = [
  { q: 'What do I need?', a: 'The host needs an Android phone with Android 10 or newer. The listener can use an Android phone with the app, or a computer browser with no install.' },
  { q: 'Can I listen on a computer?', a: 'Yes. Open the invite link, or enter the code in the box above, and press Join. It works in current Chrome and Edge, and in other browsers that can decode AAC audio. The computer can listen, chat and use play, pause and skip, but only an Android phone can host.' },
  { q: 'Why does Android ask about screen capture?', a: 'Android uses the same permission to share a phone\'s audio as it does for screen recording. HamJam only captures audio, never your screen. Calls and notification sounds are not included.' },
  { q: 'Do we both need a music subscription?', a: 'No. Only the host plays music. The listener hears the stream, so one subscription (or a free app) is enough.' },
  { q: 'Is anything saved?', a: 'No. There are no accounts. Chat and audio pass through the server live and are not stored. A jam disappears when the host ends it.' },
  { q: 'Some apps stay silent. Why?', a: 'A few apps (usually protected video or DRM content) block other apps from capturing their sound. Music apps generally work.' },
];

/** /j/ABC123 opens the in-browser listener; everything else is the landing page. */
export default function App() {
  const m = location.pathname.match(/^\/j\/([A-Za-z0-9]{0,6})\/?$/);
  return m ? <JoinPage initialCode={m[1].toUpperCase()} /> : <Landing />;
}

function JoinBox() {
  const [code, setCode] = useState('');
  const go = (e) => {
    e.preventDefault();
    if (code.length === 6) location.assign(`/j/${code}`);
  };
  return (
    <form className="joinbox" id="join" onSubmit={go}>
      <label htmlFor="code">Got a code? Listen right here in your browser.</label>
      <div className="joinrow">
        <input
          id="code"
          value={code}
          onChange={(e) => setCode(e.target.value.replace(/[^A-Za-z0-9]/g, '').toUpperCase().slice(0, 6))}
          placeholder="CODE"
          autoComplete="off"
          autoCapitalize="characters"
          spellCheck="false"
          inputMode="text"
        />
        <button className="btn" type="submit" disabled={code.length !== 6}>Join</button>
      </div>
    </form>
  );
}

function Landing() {
  return (
    <>
      <header className="nav">
        <a className="brand" href="#top" aria-label="HamJam home">
          <Logo size={36} />
          <span>HamJam</span>
        </a>
        <nav>
          <a href="#how">How it works</a>
          <a href="#features">Features</a>
          <a href="#faq">FAQ</a>
          <a href="#join">Join</a>
          <a className="btn btn-small" href={APK_URL} download="HamJam.apk">Download</a>
        </nav>
      </header>

      <main id="top">
        <section className="hero">
          <div className="hero-copy">
            <h1>
              Listen together,<br />
              <span className="accent">from anywhere.</span>
            </h1>
            <p className="lead">
              Share the sound of any music app with someone far away. They just enter a code, and you both
              control what plays.
            </p>
            <div className="cta">
              <a className="btn" href={APK_URL} download="HamJam.apk">
                <Icon name="download" /> Download for Android
              </a>
              <a className="btn btn-ghost" href="#how">See how it works</a>
            </div>
            <JoinBox />
            <p className="note">
              Hosting needs Android 10 or newer. Listen on Android or in any current browser.{' '}
              <a className="link" href={RELEASES_URL}>Release notes and older versions</a>
            </p>
          </div>
          <PhoneMock />
        </section>

        <section id="how" className="section">
          <h2>Up and running in a minute</h2>
          <div className="steps">
            {STEPS.map((s) => (
              <div className="card step" key={s.n}>
                <span className="step-n">{s.n}</span>
                <h3>{s.title}</h3>
                <p>{s.text}</p>
              </div>
            ))}
          </div>
        </section>

        <section id="features" className="section">
          <h2>Made for two</h2>
          <div className="grid">
            {FEATURES.map((f) => (
              <div className="card feature" key={f.title}>
                <span className="feature-icon"><Icon name={f.icon} /></span>
                <h3>{f.title}</h3>
                <p>{f.text}</p>
              </div>
            ))}
          </div>
        </section>

        <section id="install" className="section install">
          <div className="card install-card">
            <div>
              <h2>Get the app</h2>
              <p>
                Download the APK, open it, and allow installs from your browser if Android asks. Then
                host a jam, or join with your partner&apos;s code.
              </p>
            </div>
            <a className="btn" href={APK_URL} download="HamJam.apk">
              <Icon name="download" /> HamJam for Android
            </a>
          </div>
        </section>

        <section id="faq" className="section">
          <h2>Questions</h2>
          <div className="faq">
            {FAQ.map((f) => (
              <details className="card" key={f.q}>
                <summary>{f.q}</summary>
                <p>{f.a}</p>
              </details>
            ))}
          </div>
        </section>
      </main>

      <footer className="footer">
        <div className="brand"><Logo size={28} /><span>HamJam</span></div>
        <p>Made for listening together.</p>
      </footer>
    </>
  );
}
