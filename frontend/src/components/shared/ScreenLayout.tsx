interface ScreenLayoutProps {
  children: React.ReactNode;
  /** Tailwind max-width class(es) for the inner card, e.g. "max-w-2xl". */
  maxWidth?: string;
  /** Adds top padding to clear the fixed PlayerHeader bar. */
  showHeaderOffset?: boolean;
  /** QuestionView-style flex-col layout (no vertical centering via items-center). */
  column?: boolean;
}

export default function ScreenLayout({
  children,
  maxWidth = 'max-w-2xl',
  showHeaderOffset = false,
  column = false,
}: ScreenLayoutProps) {
  return (
    <div
      className={`relative z-10 min-h-screen flex ${
        column ? 'flex-col justify-center' : 'items-center justify-center'
      } p-4 ${showHeaderOffset ? 'pt-20' : ''} pointer-events-none`}
    >
      <div className={`glass-panel rounded-3xl p-8 w-full ${maxWidth} text-white pointer-events-auto`}>
        {children}
      </div>
    </div>
  );
}
