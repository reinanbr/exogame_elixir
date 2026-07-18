import Starfield from '../shared/Starfield';
import MarsRover from './MarsRover';

export default function AlienSurface() {
  return (
    <section className="relative w-full min-h-screen overflow-hidden">
      {/* sky: night fades out, day fades in, on a shared 26s cycle */}
      <div className="absolute inset-0 bg-gradient-to-b from-[#0a0b26] via-[#241242] to-[#3a0f3d] animate-surface-night" />
      <div className="absolute inset-0 bg-gradient-to-b from-[#ff8f6b] via-[#ffb08a] to-[#ffd9a0] animate-surface-day" />

      {/* nebulae / distant galaxies */}
      <div className="absolute inset-0 animate-surface-night">
        <div className="absolute top-6 left-[15%] w-72 h-72 bg-purple-500/25 rounded-full blur-3xl" />
        <div className="absolute top-16 right-[10%] w-64 h-64 bg-cyan-400/15 rounded-full blur-3xl" />
        <div className="absolute top-4 right-[35%] w-40 h-40 bg-pink-400/15 rounded-full blur-2xl rotate-12" />
      </div>

      {/* stars */}
      <div className="absolute inset-0 animate-surface-night">
        <Starfield count={70} topRange={[0, 55]} />
      </div>

      {/* giant ringless gas-giant looming near the horizon */}
      <div className="absolute -top-6 left-[6%] animate-surface-night">
        <div
          className="rounded-full"
          style={{
            width: 260,
            height: 260,
            background:
              'radial-gradient(circle at 35% 30%, #ffe1f1, #ff9dcd 40%, #d9508f 75%, #8f2f66 100%)',
            boxShadow: '0 0 90px 25px rgba(255, 130, 190, 0.35)',
          }}
        />
      </div>

      {/* the planet's moon, drifting slowly across the sky */}
      <div className="absolute top-20 right-[22%] animate-moon-drift">
        <div
          className="w-14 h-14 rounded-full animate-surface-night"
          style={{
            background: 'radial-gradient(circle at 35% 30%, #f1f1f4, #c7c9d4 60%, #8d8fa0 100%)',
            boxShadow: '0 0 24px 6px rgba(200, 200, 220, 0.3)',
          }}
        />
      </div>

      {/* twin suns: rise together on one side, arc across the sky, set on the other */}
      <div className="absolute bottom-[30%] flex items-end gap-8 animate-suns-arc">
        <div
          className="rounded-full"
          style={{
            width: 84,
            height: 84,
            background: 'radial-gradient(circle at 35% 30%, #fffbe6, #ffd166 55%, #ff9f43 100%)',
            boxShadow: '0 0 70px 22px rgba(255, 209, 102, 0.55)',
          }}
        />
        <div
          className="rounded-full"
          style={{
            width: 58,
            height: 58,
            background: 'radial-gradient(circle at 35% 30%, #ffe3d5, #ff8a65 55%, #e64a19 100%)',
            boxShadow: '0 0 54px 16px rgba(255, 138, 101, 0.45)',
          }}
        />
      </div>

      {/* rocky alien terrain, static, occluding whatever sits behind the horizon */}
      <svg
        viewBox="0 0 1200 320"
        preserveAspectRatio="none"
        className="absolute bottom-0 left-0 w-full h-[38vh] min-h-[280px] z-10"
      >
        <defs>
          <linearGradient id="rock-far" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#5b1c28" />
            <stop offset="100%" stopColor="#2c0b14" />
          </linearGradient>
          <linearGradient id="rock-near" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#7a2432" />
            <stop offset="100%" stopColor="#1c060b" />
          </linearGradient>
        </defs>
        <path
          d="M0,320 L0,190 L110,150 L200,185 L320,120 L410,175 L540,110 L640,180 L760,95 L880,160 L1000,110 L1100,175 L1200,140 L1200,320 Z"
          fill="url(#rock-far)"
          opacity="0.85"
        />
        <path
          d="M0,320 L0,240 L90,205 L190,250 L300,190 L400,245 L520,180 L610,235 L720,175 L840,240 L950,190 L1060,245 L1200,210 L1200,320 Z"
          fill="url(#rock-near)"
        />
      </svg>

      {/* rover and astronaut, crossing the ridge — in front of the content
          card so the traverse stays visible for its whole crossing */}
      <MarsRover className="bottom-[2vh] z-20" />

      {/* about content, standing on the alien ground */}
      <div className="relative z-20 flex items-end justify-center min-h-screen px-4 pb-16 pt-32">
        <div className="glass-panel rounded-3xl p-8 md:p-10 max-w-2xl text-white">
          <p className="text-white/50 italic text-sm mb-4 text-center">
            &ldquo;Em algum lugar, algo incrível está esperando para ser descoberto.&rdquo; - Carl Sagan
          </p>
          <h2 className="font-heading text-2xl md:text-3xl font-extrabold mb-4 bg-gradient-to-r from-cyan-300 via-purple-300 to-pink-300 bg-clip-text text-transparent text-center">
            Sobre o ExoGame
          </h2>
          <div className="space-y-4 text-white/80 leading-relaxed">
            <p>
              ExoGame é uma plataforma <em>web</em> gamificada de perguntas e respostas em tempo
              real, inspirada na mecânica do Kahoot!, criada para tornar o aprendizado de
              astronomia, em especial sobre exoplanetas, mais envolvente e acessível.
            </p>
            <p>
              A ideia nasceu de uma constatação simples: apesar dos milhares de exoplanetas já
              descobertos, o ensino de astronomia ainda ocupa pouco espaço nas salas de aula
              brasileiras. O ExoGame usa a gamificação com pontuação por tempo de resposta, avatares
              personalizáveis e placar em tempo real, para transformar esse conteúdo abstrato
              numa experiência coletiva e divertida.
            </p>
            <p>
              Por trás da cena, o jogo roda com <strong>Next.js</strong> no frontend e{' '}
              <strong>Phoenix (Elixir/BEAM)</strong> no backend, comunicando-se por WebSockets
              nativos via Phoenix Channels, que é a mesma base de concorrência usada por sistemas como
              o WhatsApp.
            </p>
            <p className="text-white/60 text-sm pt-2 border-t border-white/10">
              Desenvolvido por <strong className="text-white/80">Reinan Bezerra</strong> como
              Trabalho de Conclusão de Curso da Licenciatura em Física do Instituto Federal de
              Ciências e Tecnologia do Sertão Pernambucano (IF Sertão-PE), sob orientação do
              professor <strong className="text-white/80">Erivelton Façanha</strong>.
            </p>
          </div>
        </div>
      </div>
    </section>
  );
}
