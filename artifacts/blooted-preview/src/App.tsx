import { useState } from 'react';
import { Bluetooth, RotateCw, Smartphone, ExternalLink } from 'lucide-react';

const SRC = import.meta.env.BASE_URL + 'flutter/index.html';

function Home() {
  const [key, setKey] = useState(0);
  const [loaded, setLoaded] = useState(false);
  const reload = () => { setLoaded(false); setKey((k) => k + 1); };

  return (
    <div className="min-h-[100dvh] w-full flex flex-col bg-[radial-gradient(ellipse_at_top,hsl(176_40%_88%),hsl(var(--background))_60%)]">
      <header className="rise flex flex-wrap items-center gap-3 px-4 sm:px-6 py-3 border-b border-border/70 bg-card/70 backdrop-blur">
        <div className="relative grid place-items-center h-9 w-9 rounded-lg bg-primary text-primary-foreground">
          <span className="bt-pulse absolute inset-0 rounded-lg bg-primary/40" />
          <Bluetooth className="relative h-5 w-5" />
        </div>
        <div className="min-w-0 mr-auto">
          <h1 className="text-lg font-bold leading-tight tracking-tight">Blooted</h1>
          <p className="font-mono text-[11px] text-muted-foreground">Android BLE · Flutter örnek uygulaması</p>
        </div>
        <a href={SRC} target="_blank" rel="noreferrer" data-testid="link-open-flutter"
          className="inline-flex items-center gap-1.5 rounded-md border border-border px-3 py-1.5 text-sm hover:bg-secondary transition-colors">
          <ExternalLink className="h-4 w-4" /> Yeni sekmede aç
        </a>
        <button onClick={reload} data-testid="button-reload-preview"
          className="inline-flex items-center gap-1.5 rounded-md bg-primary px-3 py-1.5 text-sm text-primary-foreground hover:opacity-90 transition-opacity">
          <RotateCw className={`h-4 w-4 transition-transform ${loaded ? '' : 'animate-spin'}`} /> Önizlemeyi yenile
        </button>
      </header>

      <div role="note" data-testid="text-preview-notice"
        className="rise flex items-center gap-2 px-4 sm:px-6 py-2 text-sm bg-accent/15 border-b border-accent/40 text-foreground" style={{ animationDelay: '80ms' }}>
        <Smartphone className="h-4 w-4 shrink-0 text-accent-foreground" />
        <span>Flutter arayüz önizlemesi — gerçek Bluetooth işlemleri Android cihaz gerektirir.</span>
      </div>

      <main className="flex-1 flex justify-center p-3 sm:p-6">
        <div className="rise relative w-full max-w-[440px] h-[calc(100dvh-150px)] min-h-[520px] rounded-[2rem] border-[10px] border-foreground bg-card shadow-[0_24px_60px_-20px_hsl(206_48%_13%/0.45)] overflow-hidden" style={{ animationDelay: '160ms' }}>
          {!loaded && (
            <div className="absolute inset-0 p-5 space-y-3 animate-pulse" aria-hidden>
              <div className="h-10 rounded-md bg-muted" />
              <div className="h-24 rounded-md bg-muted" />
              <div className="h-16 rounded-md bg-muted" />
              <p className="font-mono text-xs text-muted-foreground pt-2">Flutter yükleniyor…</p>
            </div>
          )}
          <iframe key={key} src={SRC} title="Blooted Flutter örnek uygulaması"
            data-testid="iframe-flutter-preview" onLoad={() => setLoaded(true)}
            className={`relative h-full w-full border-0 transition-opacity duration-500 ${loaded ? 'opacity-100' : 'opacity-0'}`} />
        </div>
      </main>
    </div>
  );
}

function App() {
  return <Home />;
}

export default App;
