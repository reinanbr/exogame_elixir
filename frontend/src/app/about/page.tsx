import type { Metadata } from 'next';
import Link from 'next/link';
import AlienSurface from '@/components/space/AlienSurface';

export const metadata: Metadata = {
  title: 'Sobre - ExoGame',
  description: 'A ideia e a criação por trás do ExoGame',
};

export default function AboutPage() {
  return (
    <div className="relative z-10 min-h-screen">
      <Link
        href="/"
        className="absolute left-4 top-4 z-30 text-white/50 hover:text-white text-sm transition-colors"
      >
        ← Início
      </Link>
      <AlienSurface />
    </div>
  );
}
