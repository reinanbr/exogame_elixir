import SplashTransit from './SplashTransit';

interface SplashScreenProps {
  message?: string;
  /** When true, the animation accelerates to finish its current lap instead of looping forever. */
  finish?: boolean;
  /** Fires once the accelerated lap naturally completes — safe moment to reveal the app. */
  onFinish?: () => void;
}

export default function SplashScreen({
  message = 'Sincronizando com a estação...',
  finish = false,
  onFinish,
}: SplashScreenProps) {
  return (
    <div className="relative z-10 min-h-screen flex flex-col items-center justify-center gap-6 pointer-events-none">
      <SplashTransit size={180} finish={finish} onFinish={onFinish} />
      <div className="text-center">
        <h1 className="font-heading text-3xl font-extrabold mb-2 bg-gradient-to-r from-cyan-300 via-purple-300 to-pink-300 bg-clip-text text-transparent tracking-wide">
          ExoGame
        </h1>
        <p className="text-white/60 text-sm">{message}</p>
      </div>
    </div>
  );
}
