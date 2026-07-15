'use client';

import { useGame } from '@/contexts/GameContext';
import ExoplanetTransit from './ExoplanetTransit';
import HabitableZoneDiagram from './HabitableZoneDiagram';
import SizeComparisonDiagram from './SizeComparisonDiagram';
import InfoHover from '../shared/InfoHover';
import Starfield from '../shared/Starfield';

export default function SpaceBackground() {
  // The informative simulations (transit method, size comparison, habitable
  // zone, etc.) are only shown on the home screen, before a game exists —
  // once inside a lobby or match, they'd just be distracting clutter.
  const { game } = useGame();

  return (
    <div className="fixed inset-0 z-0 overflow-hidden bg-[#05061a]">
      {/* base nebula gradient */}
      <div className="absolute inset-0 bg-gradient-to-br from-[#0b0c2a] via-[#1a1145] to-[#2d0b4e]" />

      {/* nebula glow blobs */}
      <div className="absolute -top-32 -left-32 w-96 h-96 bg-purple-600/30 rounded-full blur-3xl" />
      <div className="absolute top-1/3 -right-40 w-[28rem] h-[28rem] bg-blue-600/20 rounded-full blur-3xl" />
      <div className="absolute bottom-0 left-1/4 w-80 h-80 bg-pink-600/20 rounded-full blur-3xl" />
      <div className="absolute bottom-1/4 right-1/4 w-72 h-72 bg-cyan-500/10 rounded-full blur-3xl" />

      {/* stars */}
      <Starfield count={140} topRange={[0, 100]} />

      {/* informative simulations — home screen only */}
      {!game && (
        <>
          {/* exoplanet transit-method diagrams: a planet dimming its star, plotted as a light curve */}
          <InfoHover
            className="absolute top-10 left-[5%] opacity-60 animate-float-slow"
            tooltipClassName="top-full left-0 mt-3"
            text="Método do trânsito: quando um planeta passa à frente da sua estrela, o brilho dela cai por instantes. Foi assim que telescópios como Kepler e TESS descobriram milhares de exoplanetas."
          >
            <ExoplanetTransit size={88} duration={9} delay={0} />
          </InfoHover>
          <InfoHover
            className="absolute bottom-16 right-[6%] opacity-60"
            tooltipClassName="bottom-full right-0 mb-3"
            text="TOI-1452 b é um exoplaneta ~70% maior que a Terra, possivelmente coberto por um oceano global — descoberto justamente por um trânsito como este."
          >
            <SizeComparisonDiagram size={100} />
          </InfoHover>

          {/* other decorations */}
          <InfoHover
            className="absolute top-1/2 right-[16%]"
            tooltipClassName="right-full top-1/2 -translate-y-1/2 mr-3"
            text="Exocometas — núcleos de gelo e poeira — já foram detectados ao redor de outras estrelas, revelando pistas sobre a formação de sistemas planetários."
          >
            <span className="block text-3xl opacity-50 animate-float-slow select-none">☄️</span>
          </InfoHover>
          <InfoHover
            className="absolute top-16 right-[26%] opacity-70 animate-float"
            tooltipClassName="top-full right-0 mt-3"
            text="Zona habitável: a faixa ao redor de uma estrela onde a temperatura permite água líquida — nem tão quente, nem tão fria, o lugar certo para a vida como conhecemos."
          >
            <HabitableZoneDiagram size={130} />
          </InfoHover>
          <InfoHover
            className="absolute bottom-1/3 left-[12%]"
            tooltipClassName="bottom-full left-0 mb-3"
            text="Sondas espaciais orbitam continuamente observando estrelas distantes, à procura da próxima Terra."
          >
            <span className="block text-3xl opacity-40 animate-spin-slow select-none">🛰️</span>
          </InfoHover>
        </>
      )}
    </div>
  );
}
