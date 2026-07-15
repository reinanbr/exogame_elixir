import type { Metadata } from "next";
import { Inter, Orbitron } from "next/font/google";
import "./globals.css";
import { GameProvider } from "@/contexts/GameContext";
import SpaceBackground from "@/components/space/SpaceBackground";

const inter = Inter({ subsets: ["latin"], variable: "--font-inter" });
const orbitron = Orbitron({
  subsets: ["latin"],
  variable: "--font-orbitron",
  weight: ["500", "700", "800"],
});

export const metadata: Metadata = {
  title: "ExoGame - Quiz em Tempo Real",
  description: "Jogo de perguntas e respostas estilo Kahoot entre exoplanetas",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="pt-BR">
      <body className={`${inter.variable} ${orbitron.variable} antialiased`}>
        <GameProvider>
          <SpaceBackground />
          {children}
        </GameProvider>
      </body>
    </html>
  );
}
