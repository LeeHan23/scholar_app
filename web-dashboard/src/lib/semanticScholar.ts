/**
 * Semantic Scholar API client with in-memory caching.
 *
 * Free tier, no API key required.  Rate limit ≈ 100 req / 5 min, so we cache
 * aggressively and only fetch once per DOI per browser session.
 */

export interface SemanticPaper {
  paperId: string;
  title: string;
  authors: { authorId: string | null; name: string }[];
  year: number | null;
  externalIds: { DOI?: string; ArXiv?: string } | null;
  abstract: string | null;
}

export interface RecommendedPaper {
  id: string; // Semantic Scholar paperId
  title: string;
  authors: string;
  year: number | null;
  doi: string | null;
  abstract: string | null;
  sourceDoi: string; // the queue DOI that led to this recommendation
  relation: 'reference' | 'citation';
}

// ---------------------------------------------------------------------------
// In-memory cache keyed by DOI → relation
// ---------------------------------------------------------------------------
const cache = new Map<string, RecommendedPaper[]>();

function cacheKey(doi: string, relation: 'reference' | 'citation'): string {
  return `${doi}::${relation}`;
}

// ---------------------------------------------------------------------------
// Fetch helpers
// ---------------------------------------------------------------------------

async function fetchRelated(
  doi: string,
  relation: 'reference' | 'citation',
  limit: number = 5,
): Promise<RecommendedPaper[]> {
  const key = cacheKey(doi, relation);
  const cached = cache.get(key);
  if (cached) return cached;

  const endpoint =
    relation === 'reference' ? 'references' : 'citations';

  const url =
    `https://api.semanticscholar.org/graph/v1/paper/DOI:${encodeURIComponent(doi)}` +
    `/${endpoint}?fields=title,authors,year,externalIds,abstract&limit=${limit}`;

  try {
    const res = await fetch(url);
    if (!res.ok) {
      // 404 = paper not found on S2, 429 = rate‑limited
      console.warn(`Semantic Scholar ${res.status} for DOI ${doi}`);
      cache.set(key, []);
      return [];
    }

    const json = await res.json();
    // The API wraps each entry in { citedPaper } or { citingPaper }
    const field = relation === 'reference' ? 'citedPaper' : 'citingPaper';

    const papers: RecommendedPaper[] = (json.data ?? [])
      .map((entry: Record<string, SemanticPaper | null>) => entry[field])
      .filter(
        (p: SemanticPaper | null): p is SemanticPaper =>
          p !== null && p.title !== null && p.title.length > 0,
      )
      .map((p: SemanticPaper) => ({
        id: p.paperId,
        title: p.title,
        authors: p.authors?.map(a => a.name).join(', ') ?? '',
        year: p.year,
        doi: p.externalIds?.DOI ?? null,
        abstract: p.abstract,
        sourceDoi: doi,
        relation,
      }));

    cache.set(key, papers);
    return papers;
  } catch (err) {
    console.error(`Semantic Scholar fetch failed for ${doi}:`, err);
    cache.set(key, []);
    return [];
  }
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Given an array of DOIs from the user's queue, return de‑duplicated
 * recommendations (references + citations), excluding papers already
 * in the queue.
 *
 * Fetches are parallelised per DOI, with a small stagger to be polite
 * to the rate limiter.
 */
export async function getRecommendations(
  queueDois: string[],
  opts: { perDoi?: number; maxTotal?: number } = {},
): Promise<RecommendedPaper[]> {
  const { perDoi = 3, maxTotal = 30 } = opts;

  // De-duplicate queue DOIs (lowercased)
  const uniqueDois = [...new Set(queueDois.map(d => d.toLowerCase()))];

  // Only process first 10 DOIs to stay within rate limits
  const doisToFetch = uniqueDois.slice(0, 10);

  // Fetch references + citations for each DOI in parallel batches
  const allPromises: Promise<RecommendedPaper[]>[] = [];
  for (const doi of doisToFetch) {
    allPromises.push(fetchRelated(doi, 'reference', perDoi));
    allPromises.push(fetchRelated(doi, 'citation', perDoi));
  }

  const results = await Promise.all(allPromises);
  const flat = results.flat();

  // De-duplicate by Semantic Scholar paperId
  const seen = new Set<string>();
  const queueDoiSet = new Set(uniqueDois);
  const deduped: RecommendedPaper[] = [];

  for (const paper of flat) {
    if (seen.has(paper.id)) continue;
    seen.add(paper.id);

    // Skip papers already in the queue
    if (paper.doi && queueDoiSet.has(paper.doi.toLowerCase())) continue;

    deduped.push(paper);
    if (deduped.length >= maxTotal) break;
  }

  return deduped;
}

/**
 * Clear the cache (useful if the user wants to refresh recommendations).
 */
export function clearRecommendationCache(): void {
  cache.clear();
}
