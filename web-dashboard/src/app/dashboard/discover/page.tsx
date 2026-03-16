"use client";

import { useState, useEffect } from 'react';
import Sidebar, { Project } from '../../../components/Sidebar';
import RecommendationsPanel from '../../../components/RecommendationsPanel';
import { supabase } from '../../../lib/supabaseClient';
import type { Paper } from '../../../components/PaperCard';
import { Lightbulb } from 'lucide-react';

export default function DiscoverPage() {
  const [queue, setQueue] = useState<Paper[]>([]);
  const [projects, setProjects] = useState<Project[]>([]);
  const [loading, setLoading] = useState(true);
  const [user, setUser] = useState<any>(null);

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setUser(session?.user ?? null);
      if (session?.user) {
        fetchPapers();
        fetchProjects();
      } else {
        window.location.href = '/login';
      }
    });

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      setUser(session?.user ?? null);
      if (!session?.user) {
        window.location.href = '/login';
      }
    });

    return () => subscription.unsubscribe();
  }, []);

  const fetchPapers = async () => {
    try {
      const { data, error } = await supabase
        .from('papers')
        .select('*')
        .order('id', { ascending: false });

      if (error) throw error;
      if (data) setQueue(data as Paper[]);
    } catch (error) {
      console.error('Error fetching papers:', error);
    } finally {
      setLoading(false);
    }
  };

  const fetchProjects = async () => {
    try {
      const { data, error } = await supabase
        .from('projects')
        .select('id, name')
        .order('name', { ascending: true });

      if (error) throw error;
      if (data) setProjects(data as Project[]);
    } catch (error) {
      console.error('Error fetching projects:', error);
    }
  };

  const handlePaperAdded = (paper: Paper) => {
    setQueue(prev => [paper, ...prev]);
  };

  const doisInQueue = queue
    .filter(p => p.doi)
    .length;

  return (
    <div className="app-container">
      <Sidebar
        activeFilter="discover"
        onFilterChange={(filter) => {
          if (filter === 'discover') return;
          window.location.href = '/dashboard';
        }}
        projects={projects}
      />
      <main className="main-content">
        <div className="discover-header">
          <div>
            <h1 className="title" style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
              <Lightbulb size={28} color="var(--warning)" />
              Discover Related Papers
            </h1>
            <p className="subtitle" style={{ marginTop: '4px' }}>
              Based on {doisInQueue} paper{doisInQueue !== 1 ? 's' : ''} with DOIs in your queue
            </p>
          </div>
        </div>

        <p className="discover-description">
          Recommendations are powered by the Semantic Scholar API. We look at both
          references (papers your queue papers cite) and citations (papers that cite
          your queue papers) to surface relevant reading material.
        </p>

        {loading ? (
          <div style={{ textAlign: 'center', marginTop: '40px', color: 'var(--text-secondary)' }}>
            Loading your queue...
          </div>
        ) : !user ? null : doisInQueue === 0 ? (
          <div style={{
            textAlign: 'center',
            marginTop: '60px',
            color: 'var(--text-secondary)',
            lineHeight: 1.8,
          }}>
            <Lightbulb size={48} color="var(--text-secondary)" style={{ opacity: 0.3, marginBottom: '16px' }} />
            <p style={{ fontSize: '1.05rem', fontWeight: 500, color: 'var(--text-primary)' }}>
              No papers with DOIs in your queue yet
            </p>
            <p style={{ maxWidth: '400px', margin: '8px auto 0' }}>
              Add papers with DOIs to your reading queue and come back here
              to discover related work.
            </p>
          </div>
        ) : (
          <RecommendationsPanel
            queue={queue}
            userId={user.id}
            onPaperAdded={handlePaperAdded}
          />
        )}
      </main>
    </div>
  );
}
