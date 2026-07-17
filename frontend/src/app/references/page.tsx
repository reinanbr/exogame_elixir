import type { Metadata } from 'next';
import fs from 'node:fs';
import path from 'node:path';
import { parseBibtex, formatBibliographyAbnt } from 'latex-cite-editor';
import ReferencesCrawl from '@/components/screens/ReferencesCrawl';

export const metadata: Metadata = {
  title: 'Referências - ExoGame',
  description: 'Referências bibliográficas do ExoGame, formatadas em ABNT NBR 6023',
};

// references.json actually holds raw BibTeX source, not JSON. The source of
// truth lives at the repo root; this is a committed build-time copy inside
// the frontend directory so it's present in the Docker build context (which
// only includes ./frontend, not the repo root) — see the note at the top of
// the file itself for how to keep it in sync.
function loadReferences() {
  const bibPath = path.join(process.cwd(), 'references.json');
  const source = fs.readFileSync(bibPath, 'utf-8');
  const entries = parseBibtex(source);
  return formatBibliographyAbnt(entries);
}

export default function ReferencesPage() {
  const references = loadReferences();
  return <ReferencesCrawl references={references} />;
}
