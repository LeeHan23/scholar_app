export interface ExtractedMetadata {
  title?: string;
  authors?: string;
  journal?: string;
  year?: string;
  doi?: string;
  source: 'crossref' | 'pdf-text' | 'none';
}

/**
 * Read raw bytes from a PDF file as a latin1 string.
 */
async function extractRawText(file: File): Promise<string> {
  const buffer = await file.arrayBuffer();
  const bytes = new Uint8Array(buffer);

  let text = '';
  for (let i = 0; i < bytes.length; i++) {
    text += String.fromCharCode(bytes[i]);
  }

  return text;
}

/**
 * Extract PDF metadata fields (/Title, /Author, /Subject, /Creator).
 * PDFs store these as: /Title (The Paper Title) or /Title <hex>
 */
function extractPDFMetadata(raw: string): { title?: string; authors?: string } {
  const result: { title?: string; authors?: string } = {};

  // Match /Title (literal string)
  const titleMatch = raw.match(/\/Title\s*\(([^)]+)\)/);
  if (titleMatch) {
    const t = decodePDFString(titleMatch[1]);
    // Filter out generic/useless titles
    if (t.length > 3 && !/^untitled/i.test(t) && !/^microsoft/i.test(t) && t !== 'null') {
      result.title = t;
    }
  }

  // Match /Title <hex string>
  if (!result.title) {
    const titleHexMatch = raw.match(/\/Title\s*<([0-9A-Fa-f]+)>/);
    if (titleHexMatch) {
      const t = decodeHexString(titleHexMatch[1]);
      if (t.length > 3 && !/^untitled/i.test(t)) {
        result.title = t;
      }
    }
  }

  // Match /Author (literal string)
  const authorMatch = raw.match(/\/Author\s*\(([^)]+)\)/);
  if (authorMatch) {
    const a = decodePDFString(authorMatch[1]);
    if (a.length > 1 && a !== 'null') {
      result.authors = a;
    }
  }

  // Match /Author <hex string>
  if (!result.authors) {
    const authorHexMatch = raw.match(/\/Author\s*<([0-9A-Fa-f]+)>/);
    if (authorHexMatch) {
      const a = decodeHexString(authorHexMatch[1]);
      if (a.length > 1) {
        result.authors = a;
      }
    }
  }

  return result;
}

/**
 * Decode PDF escaped strings: \n, \r, \t, octal escapes, etc.
 */
function decodePDFString(s: string): string {
  return s
    .replace(/\\n/g, '\n')
    .replace(/\\r/g, '\r')
    .replace(/\\t/g, '\t')
    .replace(/\\\(/g, '(')
    .replace(/\\\)/g, ')')
    .replace(/\\\\/g, '\\')
    .replace(/\\(\d{1,3})/g, (_, oct) => String.fromCharCode(parseInt(oct, 8)))
    .trim();
}

/**
 * Decode hex-encoded PDF string (UTF-16BE or ASCII).
 */
function decodeHexString(hex: string): string {
  // Check for UTF-16BE BOM (FEFF)
  if (hex.startsWith('FEFF') || hex.startsWith('feff')) {
    let result = '';
    for (let i = 4; i < hex.length; i += 4) {
      const code = parseInt(hex.substring(i, i + 4), 16);
      if (code > 0) result += String.fromCharCode(code);
    }
    return result.trim();
  }

  // Plain ASCII hex
  let result = '';
  for (let i = 0; i < hex.length; i += 2) {
    const code = parseInt(hex.substring(i, i + 2), 16);
    if (code > 31) result += String.fromCharCode(code);
  }
  return result.trim();
}

/**
 * Extract readable text strings from PDF content streams.
 * Looks for text between parentheses in BT...ET blocks and Tj/TJ operators.
 */
function extractContentStrings(raw: string): string[] {
  const strings: string[] = [];

  // Match all literal strings used with text operators: (text) Tj or [(text)] TJ
  const textPattern = /\(([^)]{3,})\)\s*(?:Tj|TJ|'|")/g;
  let match;
  while ((match = textPattern.exec(raw)) !== null) {
    const decoded = decodePDFString(match[1]);
    if (decoded.length > 3 && /[a-zA-Z]/.test(decoded)) {
      strings.push(decoded);
    }
  }

  // Also grab longer literal strings that might be title/author even without operators
  const literalPattern = /\(([^)]{10,200})\)/g;
  while ((match = literalPattern.exec(raw)) !== null) {
    const decoded = decodePDFString(match[1]);
    if (decoded.length > 10 && /[a-zA-Z]{3,}/.test(decoded) && !/^[\d\s.]+$/.test(decoded)) {
      if (!strings.includes(decoded)) {
        strings.push(decoded);
      }
    }
  }

  return strings;
}

/**
 * Heuristic: try to identify the title from extracted text strings.
 * The title is usually one of the first substantial strings, often the longest.
 */
function guessTitle(strings: string[]): string | undefined {
  // Filter to candidate title strings
  const candidates = strings
    .slice(0, 30) // Look in the first 30 strings only (title is near the top)
    .filter(s =>
      s.length > 10 &&
      s.length < 300 &&
      !/^(abstract|introduction|references|acknowledgment|copyright|doi|arxiv|http|www\.|vol\.|issue|page|received|accepted|published|©)/i.test(s) &&
      !/^\d+$/.test(s) &&
      /[A-Za-z]{4,}/.test(s) // Must have actual words
    );

  if (candidates.length === 0) return undefined;

  // The title is often the longest string among the first few candidates
  const topCandidates = candidates.slice(0, 5);
  return topCandidates.reduce((a, b) => a.length >= b.length ? a : b);
}

/**
 * Heuristic: try to identify authors from extracted text strings.
 * Authors usually appear right after the title, contain commas/semicolons/and.
 */
function guessAuthors(strings: string[], title?: string): string | undefined {
  const titleIndex = title ? strings.findIndex(s => s === title) : -1;
  const searchStart = titleIndex >= 0 ? titleIndex + 1 : 0;
  const searchStrings = strings.slice(searchStart, searchStart + 15);

  for (const s of searchStrings) {
    // Skip if it looks like the title or a section header
    if (s === title) continue;
    if (/^(abstract|introduction|keywords|doi|http|©)/i.test(s)) continue;

    // Authors often have patterns like "Last, First" or "First Last" with commas/and
    const hasNamePattern = /[A-Z][a-z]+/.test(s);
    const hasSeparator = /[,;]|(\band\b)/.test(s);
    const notTooLong = s.length < 500;
    const notAllCaps = s !== s.toUpperCase();
    const hasMultipleWords = s.split(/\s+/).length >= 2;

    if (hasNamePattern && hasSeparator && notTooLong && notAllCaps && hasMultipleWords) {
      // Extra validation: should have at least 2 capitalized words
      const capWords = s.match(/[A-Z][a-z]+/g);
      if (capWords && capWords.length >= 2) {
        return s;
      }
    }
  }

  return undefined;
}

// --- Identifier finders ---

function findDOI(text: string): string | null {
  const doiPatterns = [
    /doi\.org\/(10\.\d{4,9}\/[^\s,;)}\]>"']+)/i,
    /doi[:\s]+\s*(10\.\d{4,9}\/[^\s,;)}\]>"']+)/i,
    /\b(10\.\d{4,9}\/[^\s,;)}\]>"']+)/i,
  ];

  for (const pattern of doiPatterns) {
    const match = text.match(pattern);
    if (match) {
      return match[1].replace(/[.)}\]>]+$/, '');
    }
  }
  return null;
}

function findArxivId(text: string): string | null {
  const patterns = [
    /arXiv[:\s]*(\d{4}\.\d{4,5}(?:v\d+)?)/i,
    /arxiv\.org\/abs\/(\d{4}\.\d{4,5}(?:v\d+)?)/i,
    /arxiv\.org\/pdf\/(\d{4}\.\d{4,5}(?:v\d+)?)/i,
  ];

  for (const pattern of patterns) {
    const match = text.match(pattern);
    if (match) return match[1];
  }
  return null;
}

function findISBN(text: string): string | null {
  const match = text.match(/(?:ISBN[:\s-]*)?(\d{3}[\s-]?\d[\s-]?\d{3}[\s-]?\d{5}[\s-]?\d)/i);
  if (match) return match[1].replace(/[\s-]/g, '');

  const match10 = text.match(/(?:ISBN[:\s-]*)?(\d[\s-]?\d{3}[\s-]?\d{5}[\s-]?[\dXx])/i);
  if (match10) return match10[1].replace(/[\s-]/g, '');

  return null;
}

function findYear(text: string): string | undefined {
  const currentYear = new Date().getFullYear();
  const yearMatch = text.match(/\b(19[5-9]\d|20[0-2]\d)\b/);
  if (yearMatch && parseInt(yearMatch[1]) <= currentYear + 1) {
    return yearMatch[1];
  }
  return undefined;
}

// --- API lookups ---

async function fetchFromCrossRef(doi: string): Promise<ExtractedMetadata | null> {
  try {
    const res = await fetch(
      `https://api.crossref.org/works/${encodeURIComponent(doi)}`,
      {
        headers: {
          'User-Agent': 'ScholarSync/1.0 (mailto:support@scholarsync.app)',
        },
      }
    );
    if (!res.ok) return null;

    const json = await res.json();
    const work = json.message;

    const authors = work.author
      ?.map((a: any) => `${a.family}${a.given ? ', ' + a.given : ''}`)
      .join('; ');

    const year = work.published?.['date-parts']?.[0]?.[0]
      || work['published-print']?.['date-parts']?.[0]?.[0]
      || work['published-online']?.['date-parts']?.[0]?.[0];

    const journal = work['container-title']?.[0]
      || work['short-container-title']?.[0];

    const title = work.title?.[0];

    return {
      title: title || undefined,
      authors: authors || undefined,
      journal: journal || undefined,
      year: year?.toString() || undefined,
      doi,
      source: 'crossref',
    };
  } catch {
    return null;
  }
}

async function fetchFromOpenLibrary(isbn: string): Promise<ExtractedMetadata | null> {
  try {
    const res = await fetch(`https://openlibrary.org/isbn/${isbn}.json`);
    if (!res.ok) return null;

    const data = await res.json();

    return {
      title: data.title || undefined,
      year: data.publish_date ? data.publish_date.match(/\d{4}/)?.[0] : undefined,
      source: 'crossref',
    };
  } catch {
    return null;
  }
}

// --- Main pipeline ---

/**
 * Extract metadata from a PDF:
 * 1. Read raw bytes
 * 2. Try DOI → CrossRef (best quality)
 * 3. Try arXiv ID → CrossRef
 * 4. Try ISBN → Open Library
 * 5. Fall back to PDF /Title + /Author metadata fields
 * 6. Fall back to heuristic text extraction from content streams
 */
export async function extractMetadataFromPDF(file: File): Promise<ExtractedMetadata> {
  try {
    const raw = await extractRawText(file);

    // --- Try API lookups first (highest quality) ---

    const doi = findDOI(raw);
    if (doi) {
      const data = await fetchFromCrossRef(doi);
      if (data && data.title) return data;
    }

    const arxivId = findArxivId(raw);
    if (arxivId) {
      const arxivDoi = `10.48550/arXiv.${arxivId}`;
      const data = await fetchFromCrossRef(arxivDoi);
      if (data && data.title) return data;
    }

    const isbn = findISBN(raw);
    if (isbn) {
      const data = await fetchFromOpenLibrary(isbn);
      if (data && data.title) return data;
    }

    // --- Fall back to local PDF extraction ---

    // 1. Try PDF metadata fields (/Title, /Author)
    const metadata = extractPDFMetadata(raw);

    // 2. Try content stream text extraction
    const contentStrings = extractContentStrings(raw);
    const guessedTitle = guessTitle(contentStrings);
    const guessedAuthors = guessAuthors(contentStrings, guessedTitle);
    const year = findYear(raw);

    // Merge: prefer metadata fields, fall back to heuristic guesses
    const title = metadata.title || guessedTitle;
    const authors = metadata.authors || guessedAuthors;

    const hasAnything = title || authors || doi || arxivId;

    return {
      title,
      authors,
      year,
      doi: doi || (arxivId ? `10.48550/arXiv.${arxivId}` : undefined),
      source: hasAnything ? 'pdf-text' : 'none',
    };
  } catch (err) {
    console.error('PDF extraction failed:', err);
    return { source: 'none' };
  }
}
