import { useState } from 'react';
import { RotateCcw, ExternalLink, FlaskConical } from 'lucide-react';

type Key = 'android9-grant' | 'android9-deny' | 'android10-restricted' | 'no-modem';

const SCENARIOS: {
  key: Key;
  code: string;
  title: string;
  steps: string[];
  expect: string;
  tone: 'ok' | 'warn' | 'block' | 'none';
}[] = [
  {
    key: 'android9-grant',
    code: 'API 28',
    title: 'Android 9 — izin kabul',
    steps: ["'IMEI bilgisini oku' düğmesine tıklayın.", "'Telefon izni ver ve oku' düğmesine tıklayın."],
    expect: 'İzin verilmiş sayılır; örnek değer DEMO-IMEI-1 gösterilir. Gerçek işletim sistemi istemi açılmaz.',
    tone: 'ok',
  },
  {
    key: 'android9-deny',
    code: 'API 28',
    title: 'Android 9 — izin reddi',
    steps: ["'IMEI bilgisini oku' düğmesine tıklayın.", "'Telefon izni ver ve oku' düğmesine tıklayın."],
    expect: 'İzin reddedilmiş sayılır; IMEI gösterilmez, ret mesajı görünür.',
    tone: 'warn',
  },
  {
    key: 'android10-restricted',
    code: 'API 29+',
    title: 'Android 10+ — IMEI kısıtlı',
    steps: ["'IMEI bilgisini oku' düğmesine tıklayın."],
    expect: 'Android 10 ve sonrası üçüncü taraf uygulamalara IMEI vermez; kısıtlama açıklaması görünür.',
    tone: 'block',
  },
  {
    key: 'no-modem',
    code: 'Modem yok',
    title: 'Telefon modemi yok',
    steps: ["'IMEI bilgisini oku' düğmesine tıklayın."],
    expect: 'Cihazda telefon modemi olmadığı için IMEI bulunmadığı bildirilir.',
    tone: 'none',
  },
];

const toneDot: Record<string, string> = {
  ok: 'bg-[hsl(150_35%_36%)]',
  warn: 'bg-accent',
  block: 'bg-destructive',
  none: 'bg-muted-foreground',
};

export default function Viewer() {
  const [selected, setSelected] = useState<Key>('android10-restricted');
  const [nonce, setNonce] = useState(0);
  const [loading, setLoading] = useState(true);
  const src = import.meta.env.BASE_URL + 'flutter/index.html?scenario=' + selected;
  const current = SCENARIOS.find((s) => s.key === selected)!;

  const choose = (k: Key) => {
    setSelected(k);
    setNonce((n) => n + 1);
    setLoading(true);
  };
  const reset = () => {
    setNonce((n) => n + 1);
    setLoading(true);
  };

  return (
    <div className="min-h-[100dvh] flex flex-col">
      <div className="sim-tape sticky top-0 z-20 text-accent-foreground shadow-sm" data-testid="banner-simulation">
        <div className="mx-auto max-w-6xl px-4 py-2 flex flex-wrap items-center gap-x-4 gap-y-1">
          <span className="font-mono font-semibold tracking-wider text-sm bg-[hsl(40_40%_97%)] px-2 py-0.5 rounded-sm">
            SİMÜLASYON — örnek veriler
          </span>
          <span className="text-sm font-semibold">
            Gerçek Android emülatörü değildir; gerçek cihaz bilgisi veya IMEI okunmaz.
          </span>
        </div>
      </div>

      <main className="mx-auto w-full max-w-6xl flex-1 px-4 py-6 grid gap-6 md:grid-cols-[minmax(0,1fr)_400px]">
        <section className="space-y-5 order-2 md:order-1">
          <header>
            <p className="font-mono text-xs uppercase tracking-widest text-primary flex items-center gap-2">
              <FlaskConical className="h-3.5 w-3.5" /> Device Identity · izin davranışı
            </p>
            <h1 className="mt-2 text-3xl md:text-4xl font-extrabold leading-tight">
              Bir senaryo seçin, Flutter ekranında deneyin.
            </h1>
          </header>

          <div role="radiogroup" aria-label="Senaryo" className="grid sm:grid-cols-2 gap-2">
            {SCENARIOS.map((s) => {
              const active = s.key === selected;
              return (
                <button
                  key={s.key}
                  role="radio"
                  aria-checked={active}
                  data-testid={`button-scenario-${s.key}`}
                  onClick={() => choose(s.key)}
                  className={`text-left rounded-md border px-3 py-2.5 transition-all duration-200 active:scale-[0.98] ${
                    active
                      ? 'border-primary bg-primary text-primary-foreground shadow-md'
                      : 'bg-card hover:border-primary/50 hover:-translate-y-0.5'
                  }`}
                >
                  <span className="flex items-center gap-2 text-sm font-semibold">
                    <span className={`h-2 w-2 rounded-full ${toneDot[s.tone]}`} />
                    {s.title}
                  </span>
                  <span className={`font-mono text-[11px] ${active ? 'opacity-80' : 'text-muted-foreground'}`}>
                    {s.code} · {s.key}
                  </span>
                </button>
              );
            })}
          </div>

          <article key={selected} className="rise rounded-md border bg-card p-4" data-testid="panel-scenario-info">
            <h2 className="font-mono text-xs uppercase tracking-widest text-muted-foreground">Yapılacaklar</h2>
            <ol className="mt-2 space-y-1.5 text-sm">
              {current.steps.map((st, i) => (
                <li key={i} className="flex gap-2">
                  <span className="font-mono text-primary font-semibold">{i + 1}.</span>
                  {st}
                </li>
              ))}
            </ol>
            <h2 className="mt-4 font-mono text-xs uppercase tracking-widest text-muted-foreground">Beklenen sonuç</h2>
            <p className="mt-1 text-sm" data-testid="text-expected">{current.expect}</p>
          </article>

          <div className="flex flex-wrap gap-2">
            <button
              onClick={reset}
              data-testid="button-reset"
              className="group inline-flex items-center gap-2 rounded-md border bg-card px-3 py-2 text-sm font-semibold hover:border-primary transition-colors"
            >
              <RotateCcw className="h-4 w-4 transition-transform duration-300 group-hover:-rotate-180" />
              Senaryoyu sıfırla
            </button>
            <a
              href={src}
              target="_blank"
              rel="noopener noreferrer"
              data-testid="link-standalone"
              className="inline-flex items-center gap-2 rounded-md border bg-card px-3 py-2 text-sm font-semibold hover:border-primary transition-colors"
            >
              <ExternalLink className="h-4 w-4" />
              Ayrı sekmede aç
            </a>
          </div>
        </section>

        <section className="order-1 md:order-2 flex justify-center">
          <div className="relative self-start w-full max-w-[380px] rounded-[2rem] bg-foreground p-2.5 shadow-xl">
            <div className="absolute left-1/2 top-3 z-10 -translate-x-1/2 rounded-full bg-accent px-2 py-0.5 font-mono text-[10px] font-semibold text-accent-foreground">
              SİMÜLASYON
            </div>
            <div className="relative overflow-hidden rounded-[1.6rem] bg-background h-[640px] max-h-[78dvh]">
              {loading && (
                <div className="absolute inset-0 z-10 flex flex-col gap-3 p-6 pt-12 bg-background" data-testid="status-loading">
                  <div className="h-6 w-2/3 rounded bg-muted animate-pulse" />
                  <div className="h-4 w-full rounded bg-muted animate-pulse" />
                  <div className="h-4 w-5/6 rounded bg-muted animate-pulse" />
                  <div className="mt-6 h-11 w-full rounded-md bg-muted animate-pulse" />
                  <p className="mt-auto font-mono text-xs text-muted-foreground">Flutter ekranı yükleniyor…</p>
                  <div className="pointer-events-none absolute inset-x-0 top-0 h-1/4 bg-gradient-to-b from-transparent via-primary/10 to-transparent scanline" />
                </div>
              )}
              <iframe
                key={`${selected}-${nonce}`}
                src={src}
                title={`Device Identity — ${current.title} (simülasyon)`}
                onLoad={() => setLoading(false)}
                className="h-full w-full border-0"
                data-testid="iframe-flutter"
              />
            </div>
          </div>
        </section>
      </main>
    </div>
  );
}
