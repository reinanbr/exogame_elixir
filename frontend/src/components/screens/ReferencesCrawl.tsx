'use client';

import { useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import Starfield from '@/components/shared/Starfield';
import type { AbntReference } from 'latex-cite-editor';

interface ReferencesCrawlProps {
  references: AbntReference[];
}

// Roughly how many pixels the crawl travels per second — tuned so a ~100-entry
// list still finishes in a few minutes instead of taking forever, while
// keeping the unhurried "opening crawl" feel.
const PX_PER_SECOND = 60;

export default function ReferencesCrawl({ references }: ReferencesCrawlProps) {
  const trackRef = useRef<HTMLDivElement>(null);
  const [crawlStyle, setCrawlStyle] = useState<Record<string, string>>({});
  const [replayKey, setReplayKey] = useState(0);
  const [staticView, setStaticView] = useState(false);

  useEffect(() => {
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      setStaticView(true);
    }
  }, []);

  useEffect(() => {
    if (staticView) return;
    const el = trackRef.current;
    if (!el) return;
    // The track starts entirely below the viewport (top: 100%) and needs to
    // travel far enough to clear its own height plus the viewport it started
    // below, however long the reference list turns out to be.
    const distance = el.scrollHeight + window.innerHeight;
    const duration = Math.max(45, distance / PX_PER_SECOND);
    setCrawlStyle({
      '--sw-distance': `${distance}px`,
      '--sw-duration': `${duration}s`,
    });
  }, [replayKey, staticView]);

  const intro = (
    <div className="text-center mb-16">
      <p className="font-heading text-cyan-300/80 text-lg md:text-xl tracking-[0.35em] mb-4">
        EXOGAME
      </p>
      <h1 className="font-heading text-yellow-400 text-3xl md:text-5xl font-extrabold leading-tight mb-10">
        REFERÊNCIAS
        <br />
        BIBLIOGRÁFICAS
      </h1>
      <p className="text-yellow-300/90 text-lg md:text-xl leading-relaxed">
        Toda jornada rumo a exoplanetas distantes começa com o conhecimento de quem observou o
        céu antes de nós. As obras a seguir sustentam cada pergunta deste jogo, listadas em
        ordem alfabética conforme a norma ABNT NBR 6023.
      </p>
    </div>
  );

  return (
    <div className="fixed inset-0 z-0 bg-black">
      <Starfield count={200} />

      <Link
        href="/"
        className="absolute left-4 top-4 z-30 text-white/50 hover:text-white text-sm transition-colors"
      >
        ← Início
      </Link>

      <div className="absolute right-4 top-4 z-30 flex gap-4 text-sm">
        {!staticView && (
          <button
            type="button"
            onClick={() => setReplayKey((k) => k + 1)}
            className="text-white/50 hover:text-white transition-colors"
          >
            ↻ Reiniciar
          </button>
        )}
        <button
          type="button"
          onClick={() => setStaticView((v) => !v)}
          className="text-white/50 hover:text-white transition-colors"
        >
          {staticView ? 'Ver crawl' : 'Ver lista simples'}
        </button>
      </div>

      {staticView ? (
        <div className="relative z-10 h-full overflow-y-auto px-4 pt-24 pb-16">
          <div className="mx-auto w-full max-w-2xl">
            {intro}
            <ol className="space-y-6 text-yellow-100 text-base leading-relaxed text-justify list-none">
              {references.map((ref) => (
                <li key={ref.key} dangerouslySetInnerHTML={{ __html: ref.html }} />
              ))}
            </ol>
          </div>
        </div>
      ) : (
        <div className="sw-crawl-viewport sw-crawl-fade relative z-10 h-full overflow-hidden">
          <div className="absolute left-1/2 -translate-x-1/2 h-full w-[90%] max-w-3xl">
            <div key={replayKey} ref={trackRef} className="sw-crawl-track" style={crawlStyle}>
              {intro}
              <ol className="space-y-6 text-yellow-300 text-base md:text-xl leading-relaxed text-justify list-none">
                {references.map((ref) => (
                  <li key={ref.key} dangerouslySetInnerHTML={{ __html: ref.html }} />
                ))}
              </ol>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
