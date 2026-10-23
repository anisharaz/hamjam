/** A static, CSS-animated rendition of the app's jam screen. */
const BARS = Array.from({ length: 28 }, (_, i) => i);

export default function PhoneMock() {
  return (
    <div className="phone" aria-hidden="true">
      <div className="phone-screen">
        <div className="m-header">
          <span className="m-title">Hosting</span>
          <span className="m-chip"><i /> Live</span>
        </div>

        <div className="m-card m-code">
          <small>INVITE CODE</small>
          <strong>K7M2QX</strong>
          <span>1 person listening</span>
        </div>

        <div className="m-card m-player">
          <div className="eq">
            {BARS.map((i) => (
              <span key={i} style={{ animationDelay: `${(i * 97) % 900}ms`, animationDuration: `${700 + ((i * 53) % 500)}ms` }} />
            ))}
          </div>
          <div className="m-controls">
            <span className="m-btn" />
            <span className="m-play"><b /><b /></span>
            <span className="m-btn" />
          </div>
        </div>

        <div className="m-chat">
          <p className="bubble them">Can you hear it?</p>
          <p className="bubble me">Loud and clear 🎧</p>
        </div>
      </div>
    </div>
  );
}
