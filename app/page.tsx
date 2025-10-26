export default function Page() {
  return (
    <>
      {/* Hero */}
      <section className="section">
        <div className="container hero-grid items-center">
          <div>
            <span className="badge">Minimal. Precise. Production-minded.</span>
            <h1 className="mt-6 text-4xl md:text-6xl font-semibold tracking-tight leading-[1.1]">
              Construction intelligence<br />for teams that ship.
            </h1>
            <p className="mt-5 text-lg text-mute max-w-xl">
              From foundation to roof—signals, takeoffs, and bid support in one elegant surface.
              Built for estimators, PMs, and principals who hate noise.
            </p>
            <div className="mt-8 flex gap-3">
              <a className="btn" href="#contact">Request access</a>
              <a className="btn-outline" href="#services">What we do</a>
            </div>
            <div className="mt-8 flex items-center gap-2 text-xs text-mute">
              <span className="kbd">⌘</span><span> + </span><span className="kbd">K</span>
              <span className="opacity-70"> Quick palette</span>
            </div>
          </div>
          <div className="card shadow-soft">
            <div className="border-b border-line/70 pb-4 mb-4">
              <div className="text-sm text-mute">Live Signals</div>
              <div className="text-2xl font-semibold mt-1">Pre-bid → Award pipeline</div>
            </div>
            <ul className="space-y-3 text-sm">
              <li className="flex justify-between"><span>Planholders & sign-ins</span><span className="text-brand">+24 this week</span></li>
              <li className="flex justify-between"><span>DOT bid tabs</span><span className="text-brand">8 new</span></li>
              <li className="flex justify-between"><span>Council approvals</span><span className="text-brand">4 passed</span></li>
              <li className="flex justify-between"><span>Permits & CIPs</span><span className="text-brand">City roll-ups</span></li>
            </ul>
          </div>
        </div>
      </section>

      {/* Work */}
      <section id="work" className="section border-t border-b border-line/60">
        <div className="container">
          <div className="text-mute text-sm mb-6">Trusted by disciplined builders</div>
          <div className="grid grid-cols-2 md:grid-cols-5 gap-6 opacity-80">
            <div className="card h-20 flex items-center justify-center">ACME</div>
            <div className="card h-20 flex items-center justify-center">CIVIX</div>
            <div className="card h-20 flex items-center justify-center">URBAN</div>
            <div className="card h-20 flex items-center justify-center">ALPHA</div>
            <div className="card h-20 flex items-center justify-center">OMEGA</div>
          </div>
        </div>
      </section>

      {/* Services */}
      <section id="services" className="section">
        <div className="container">
          <div className="max-w-2xl">
            <h2 className="text-2xl md:text-4xl font-semibold tracking-tight">Services</h2>
            <p className="mt-3 text-mute">Minimal surface, maximal signal. Modular—add only what moves the bid forward.</p>
          </div>
          <div className="mt-10 grid md:grid-cols-3 gap-6">
            <div className="card">
              <div className="text-sm text-mute">01</div>
              <div className="mt-2 text-xl font-medium">Opportunity signals</div>
              <p className="mt-2 text-sm text-mute">Pre-bid through award: planholders, agendas, permits, bonds, bid tabs.</p>
            </div>
            <div className="card">
              <div className="text-sm text-mute">02</div>
              <div className="mt-2 text-xl font-medium">Takeoff support</div>
              <p className="mt-2 text-sm text-mute">Calibrated areas/lengths/counts mapped to CSI. Clean exports.</p>
            </div>
            <div className="card">
              <div className="text-sm text-mute">03</div>
              <div className="mt-2 text-xl font-medium">Bid composer</div>
              <p className="mt-2 text-sm text-mute">Margins, alternates, and branded PDFs with totals that foot.</p>
            </div>
          </div>
        </div>
      </section>

      {/* About */}
      <section id="about" className="section border-t border-line/60">
        <div className="container grid md:grid-cols-2 gap-10">
          <div>
            <h3 className="text-2xl font-semibold tracking-tight">Principles</h3>
            <ul className="mt-6 space-y-3 text-mute">
              <li>• Signal over noise</li>
              <li>• Deterministic first, ML later</li>
              <li>• Own your data lineage</li>
              <li>• Fast by default</li>
            </ul>
          </div>
          <div className="card">
            <div className="text-mute text-sm">Snapshot</div>
            <div className="mt-3 grid grid-cols-2 gap-4 text-sm">
              <div><div className="text-mute">Sources</div><div className="text-fg">APIs + open data</div></div>
              <div><div className="text-mute">Viewer</div><div className="text-fg">PDF + vector</div></div>
              <div><div className="text-mute">Exports</div><div className="text-fg">CSV / JSON / PDF</div></div>
              <div><div className="text-mute">Deploy</div><div className="text-fg">Vercel / Docker</div></div>
            </div>
          </div>
        </div>
      </section>

      {/* Contact */}
      <section id="contact" className="section">
        <div className="container">
          <div className="card">
            <div className="grid md:grid-cols-2 gap-6 items-center">
              <div>
                <div className="badge">Let’s build clean.</div>
                <h3 className="mt-4 text-2xl font-semibold tracking-tight">Request access</h3>
                <p className="mt-2 text-mute">Tell us your trade, region, and typical project sizes. We’ll tailor a pilot.</p>
              </div>
              <form className="grid grid-cols-1 gap-3">
                <input className="card focus:outline-none" placeholder="Name" />
                <input className="card focus:outline-none" placeholder="Work email" />
                <input className="card focus:outline-none" placeholder="Company" />
                <textarea className="card h-24 resize-none focus:outline-none" placeholder="What do you need?"></textarea>
                <button className="btn w-fit">Send</button>
                <div className="text-xs text-mute">No spam. No noise.</div>
              </form>
            </div>
          </div>
        </div>
      </section>
    </>
  );
}
