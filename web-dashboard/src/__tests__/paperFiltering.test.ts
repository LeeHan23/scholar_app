import { describe, it, expect } from 'vitest';
import type { Paper } from '../components/PaperCard';

// Extract the filtering logic used in page.tsx so it can be tested independently
function filterPapers(
  papers: Paper[],
  activeFilter: string,
  searchQuery: string
): Paper[] {
  let result = papers;

  if (activeFilter === 'unread') {
    result = result.filter(p => p.status === 'unread');
  } else if (activeFilter === 'read') {
    result = result.filter(p => p.status === 'read');
  } else if (activeFilter.startsWith('project-')) {
    const projectId = parseInt(activeFilter.replace('project-', ''), 10);
    result = result.filter(p => p.project_id === projectId);
  }

  if (searchQuery.trim()) {
    const q = searchQuery.toLowerCase();
    result = result.filter(p =>
      p.title.toLowerCase().includes(q) ||
      p.authors.toLowerCase().includes(q) ||
      (p.journal && p.journal.toLowerCase().includes(q)) ||
      (p.doi && p.doi.toLowerCase().includes(q)) ||
      (p.tags && p.tags.toLowerCase().includes(q))
    );
  }

  return result;
}

function makePaper(overrides: Partial<Paper> = {}): Paper {
  return {
    id: '1',
    title: 'Attention Is All You Need',
    authors: 'Vaswani, A. et al.',
    journal: 'NeurIPS',
    year: 2017,
    doi: '10.48550/arXiv.1706.03762',
    abstract: null,
    status: 'unread',
    user_id: 'user-1',
    project_id: null,
    tags: null,
    location_name: null,
    latitude: null,
    longitude: null,
    page_number: null,
    pdf_url: null,
    read_at: null,
    created_at: '2024-01-01T00:00:00Z',
    ...overrides,
  };
}

const papers: Paper[] = [
  makePaper({ id: '1', title: 'Attention Is All You Need', authors: 'Vaswani', status: 'unread', project_id: 1, journal: 'NeurIPS' }),
  makePaper({ id: '2', title: 'BERT: Pre-training of Deep Bidirectional Transformers', authors: 'Devlin, J.', status: 'read', project_id: 1, tags: 'nlp, transformers', journal: 'ACL' }),
  makePaper({ id: '3', title: 'ImageNet Classification with Deep CNNs', authors: 'Krizhevsky', journal: 'NeurIPS', status: 'unread', project_id: 2 }),
  makePaper({ id: '4', title: 'Generative Adversarial Networks', authors: 'Goodfellow', status: 'read', doi: '10.1145/3422622', journal: 'NIPS' }),
];

describe('Paper filtering', () => {
  describe('Status filters', () => {
    it('filters unread papers (Reading Queue)', () => {
      const result = filterPapers(papers, 'unread', '');
      expect(result).toHaveLength(2);
      expect(result.every(p => p.status === 'unread')).toBe(true);
    });

    it('filters read papers', () => {
      const result = filterPapers(papers, 'read', '');
      expect(result).toHaveLength(2);
      expect(result.every(p => p.status === 'read')).toBe(true);
    });

    it('shows all papers with "all" filter', () => {
      const result = filterPapers(papers, 'all', '');
      expect(result).toHaveLength(4);
    });
  });

  describe('Project filters', () => {
    it('filters by project ID', () => {
      const result = filterPapers(papers, 'project-1', '');
      expect(result).toHaveLength(2);
      expect(result.every(p => p.project_id === 1)).toBe(true);
    });

    it('returns empty for non-existent project', () => {
      const result = filterPapers(papers, 'project-999', '');
      expect(result).toHaveLength(0);
    });
  });

  describe('Search', () => {
    it('searches by title', () => {
      const result = filterPapers(papers, 'all', 'attention');
      expect(result).toHaveLength(1);
      expect(result[0].id).toBe('1');
    });

    it('searches by author', () => {
      const result = filterPapers(papers, 'all', 'goodfellow');
      expect(result).toHaveLength(1);
      expect(result[0].id).toBe('4');
    });

    it('searches by journal', () => {
      const result = filterPapers(papers, 'all', 'neurips');
      expect(result).toHaveLength(2);
    });

    it('searches by DOI', () => {
      const result = filterPapers(papers, 'all', '10.1145');
      expect(result).toHaveLength(1);
      expect(result[0].id).toBe('4');
    });

    it('searches by tags', () => {
      const result = filterPapers(papers, 'all', 'transformers');
      expect(result).toHaveLength(1);
      expect(result[0].id).toBe('2');
    });

    it('is case insensitive', () => {
      const result = filterPapers(papers, 'all', 'BERT');
      expect(result).toHaveLength(1);
    });

    it('returns empty for no matches', () => {
      const result = filterPapers(papers, 'all', 'quantum computing');
      expect(result).toHaveLength(0);
    });
  });

  describe('Combined filter + search', () => {
    it('applies status filter then search', () => {
      const result = filterPapers(papers, 'unread', 'krizhevsky');
      expect(result).toHaveLength(1);
      expect(result[0].title).toContain('ImageNet');
    });

    it('applies project filter then search', () => {
      const result = filterPapers(papers, 'project-1', 'BERT');
      expect(result).toHaveLength(1);
      expect(result[0].id).toBe('2');
    });
  });
});
