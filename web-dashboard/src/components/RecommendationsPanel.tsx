"use client";

import { useState, useEffect, useCallback, useRef } from 'react';
import {
  Lightbulb,
  ChevronDown,
  ChevronUp,
  Plus,
  RefreshCw,
  ExternalLink,
  Loader,
  AlertCircle,
} from 'lucide-react';
import {
  getRecommendations,
  clearRecommendationCache,
  type RecommendedPaper,
} from '../lib/semanticScholar';
import type { Paper } from './PaperCard';

interface RecommendationsPanelProps {
  /** Papers currently in the user's queue (used to extract DOIs & filter). */
  queue: Paper[];
  /** Supabase user id — needed when inserting new papers. */
  userId: string;
  /** Called after a recommendation is successfully added to the queue. */
  onPaperAdded: (paper: Paper) => void;
}

export default function RecommendationsPanel({
  queue,
  userId,
  onPaperAdded,
}: RecommendationsPanelProps) {
  const [recommendations, setRecommendations] = useState<RecommendedPaper[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [expanded, setExpanded] = useState(true);
  const [addingIds, setAddingIds] = useState<Set<string>>(new Set());
  const [addedIds, setAddedIds] = useState<Set<string>>(new Set());
  const [expandedAbstracts, setExpandedAbstracts] = useState<Set<string>>(new Set());

  // Track whether we've already fetched for the current set of queue DOIs so
  // we don't re-fetch on every render.
  const fetchedForRef = useRef<string>('');

  const queueDois = queue
    .map(p => p.doi)
    .filter((d): d is string => d !== null && d.length > 0);

  const doiFingerprint = queueDois.sort().join(',');

  const fetchRecommendations = useCallback(
    async (force = false) => {
      if (queueDois.length === 0) {
        setRecommendations([]);
        return;
      }

      // Skip if we already fetched for this exact set of DOIs (unless forced)
      if (!force && fetchedForRef.current === doiFingerprint) return;

      setLoading(true);
      setError(null);

      try {
        if (force) clearRecommendationCache();
        const results = await getRecommendations(queueDois);
        setRecommendations(results);
        fetchedForRef.current = doiFingerprint;
      } catch {
        setError('Failed to fetch recommendations. Please try again later.');
      } finally {
        setLoading(false);
      }
    },
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [doiFingerprint],
  );

  useEffect(() => {
    fetchRecommendations();
  }, [fetchRecommendations]);

  // ------- Add to queue handler -------
  const handleAdd = async (rec: RecommendedPaper) => {
    setAddingIds(prev => new Set(prev).add(rec.id));

    try {
      // Dynamic import to avoid pulling supabase into the component at module level
      const { supabase } = await import('../lib/supabaseClient');

      const newPaper = {
        title: rec.title,
        authors: rec.authors,
        year: rec.year ?? new Date().getFullYear(),
        doi: rec.doi,
        abstract: rec.abstract,
        status: 'unread' as const,
        user_id: userId,
      };

      const { data, error: insertError } = await supabase
        .from('papers')
        .insert([newPaper])
        .select();

      if (insertError) throw insertError;

      const saved = data![0] as Paper;
      onPaperAdded(saved);
      setAddedIds(prev => new Set(prev).add(rec.id));
    } catch (err) {
      console.error('Failed to add recommended paper:', err);
      alert('Failed to add paper to queue.');
    } finally {
      setAddingIds(prev => {
        const next = new Set(prev);
        next.delete(rec.id);
        return next;
      });
    }
  };

  const toggleAbstract = (id: string) => {
    setExpandedAbstracts(prev => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  // Don't render anything if the user has no DOIs in their queue
  if (queueDois.length === 0) return null;

  return (
    <section className="recommendations-section">
      {/* Header / toggle */}
      <button
        className="recommendations-header"
        onClick={() => setExpanded(e => !e)}
        aria-expanded={expanded}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          <Lightbulb size={20} color="var(--warning)" />
          <span className="recommendations-title">Recommended Papers</span>
          <span className="recommendations-count">
            {recommendations.length}
          </span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          {!loading && (
            <span
              className="icon-btn"
              role="button"
              aria-label="Refresh recommendations"
              onClick={e => {
                e.stopPropagation();
                fetchRecommendations(true);
              }}
            >
              <RefreshCw size={16} color="var(--text-secondary)" />
            </span>
          )}
          {expanded ? (
            <ChevronUp size={18} color="var(--text-secondary)" />
          ) : (
            <ChevronDown size={18} color="var(--text-secondary)" />
          )}
        </div>
      </button>

      {/* Body */}
      {expanded && (
        <div className="recommendations-body">
          {loading && (
            <div className="recommendations-loading">
              <Loader size={20} className="spin" color="var(--text-accent)" />
              <span>Fetching recommendations from Semantic Scholar...</span>
            </div>
          )}

          {error && (
            <div className="recommendations-error">
              <AlertCircle size={16} />
              {error}
            </div>
          )}

          {!loading && !error && recommendations.length === 0 && (
            <div className="recommendations-empty">
              No recommendations found. Add papers with DOIs to your queue to
              get suggestions.
            </div>
          )}

          {!loading && recommendations.length > 0 && (
            <div className="recommendations-grid">
              {recommendations.map(rec => (
                <div key={rec.id} className="glass-panel recommendation-card">
                  <div className="paper-meta">
                    {rec.year && <span>{rec.year}</span>}
                    <span className="badge" style={{ fontSize: '0.65rem' }}>
                      {rec.relation === 'reference' ? 'Referenced by' : 'Cites'}{' '}
                      your paper
                    </span>
                  </div>

                  <h4 className="paper-title" style={{ fontSize: '1rem' }}>
                    {rec.title}
                  </h4>

                  <p className="paper-authors" style={{ fontSize: '0.8rem' }}>
                    {rec.authors || 'Unknown authors'}
                  </p>

                  {rec.abstract && (
                    <div>
                      <button
                        className="recommendation-abstract-toggle"
                        onClick={() => toggleAbstract(rec.id)}
                      >
                        {expandedAbstracts.has(rec.id) ? 'Hide' : 'Show'} abstract
                      </button>
                      {expandedAbstracts.has(rec.id) && (
                        <p className="recommendation-abstract">{rec.abstract}</p>
                      )}
                    </div>
                  )}

                  <div className="recommendation-actions">
                    {rec.doi && (
                      <a
                        href={`https://doi.org/${rec.doi}`}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="icon-btn"
                        title="Open on publisher site"
                        style={{ color: 'var(--text-secondary)' }}
                      >
                        <ExternalLink size={15} />
                      </a>
                    )}

                    {addedIds.has(rec.id) ? (
                      <span
                        style={{
                          fontSize: '0.8rem',
                          color: 'var(--success)',
                          fontWeight: 500,
                        }}
                      >
                        Added
                      </span>
                    ) : (
                      <button
                        className="btn-add-recommendation"
                        onClick={() => handleAdd(rec)}
                        disabled={addingIds.has(rec.id)}
                        title="Add to reading queue"
                      >
                        {addingIds.has(rec.id) ? (
                          <Loader size={14} className="spin" />
                        ) : (
                          <Plus size={14} />
                        )}
                        Add to Queue
                      </button>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </section>
  );
}
