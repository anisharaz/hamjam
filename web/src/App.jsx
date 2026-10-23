import PhoneMock from './PhoneMock.jsx';
import { Logo, Icon } from './icons.jsx';

const APK_URL = '/download/latest.apk';

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
  { icon: 'bell', title: 'Works in the background', text: 'Lock the screen or switch apps. A notification shows the jam is active and brings you back in one tap.' },
  { icon: 'lock', title: 'Private by design', text: 'No accounts, no history. Audio is passed through, not recorded. Rooms vanish when the jam ends.' },
];

const FAQ = [
  { q: 'What do I need?', a: 'Both of you need an Android phone. The host needs Android 10 or newer. The listener only has to install the app.' },
  { q: 'Why does Android ask about screen capture?', a: 'Android uses the same permission to share a phone\'s audio as it does for screen recording. HamJam only captures audio, never your screen. Calls and notification sounds are not included.' },
  { q: 'Do we both need a music subscription?', a: 'No. Only the host plays music. The listener hears the stream, so one subscription (or a free app) is enough.' },
  { q: 'Is anything saved?', a: 'No. There are no accounts. Chat and audio pass through the server live and are not stored. A jam disappears when the host ends it.' },
  { q: 'Some apps stay silent. Why?', a: 'A few apps (usually protected video or DRM content) block other apps from capturing their sound. Music apps generally work.' },
];

export default function App() {
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
          <a className="btn btn-small" href={APK_URL}>Download</a>
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
              <a className="btn" href={APK_URL}>
                <Icon name="download" /> Download for Android
              </a>
              <a className="btn btn-ghost" href="#how">See how it works</a>
            </div>
            <p className="note">Android 10 or newer to host. Listeners need Android too.</p>
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
            <a className="btn" href={APK_URL}>
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
