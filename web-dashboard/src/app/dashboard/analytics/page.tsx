"use client";

import { useState, useEffect, useMemo } from 'react';
import { supabase } from '../../../lib/supabaseClient';
import { ArrowLeft, BookOpen, Clock, TrendingUp, FolderKey } from 'lucide-react';
import type { Paper } from '../../../components/PaperCard';

export default function AnalyticsPage() {
  const [papers, setPapers] = useState<Paper[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (!session?.user) {
        window.location.href = '/login';
        return;
      }
      fetchPapers();
    });
  }, []);

  const fetchPapers = async () => {
    try {
      const { data, error } = await supabase
        .from('papers')
        .select('*')
        .order('created_at', { ascending: true });

      if (error) throw error;
      if (data) setPapers(data as Paper[]);
    } catch (error) {
      console.error('Error fetching papers:', error);
    } finally {
      setLoading(false);
    }
  };

  const stats = useMemo(() => {
    const total = papers.length;
    const read = papers.filter(p => p.status === 'read').length;
    const unread = total - read;
    const completionRate = total > 0 ? Math.round((read / total) * 100) : 0;

    // Papers added per week (last 12 weeks)
    const now = new Date();
    const weeklyAdded: { label: string; count: number }[] = [];
    const weeklyRead: { label: string; count: number }[] = [];

    for (let i = 11; i >= 0; i--) {
      const weekStart = new Date(now);
      weekStart.setDate(weekStart.getDate() - (i * 7 + weekStart.getDay()));
      weekStart.setHours(0, 0, 0, 0);
      const weekEnd = new Date(weekStart);
      weekEnd.setDate(weekEnd.getDate() + 7);

      const label = weekStart.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });

      const added = papers.filter(p => {
        const d = new Date(p.created_at);
        return d >= weekStart && d < weekEnd;
      }).length;

      const readCount = papers.filter(p => {
        if (!p.read_at) return false;
        const d = new Date(p.read_at);
        return d >= weekStart && d < weekEnd;
      }).length;

      weeklyAdded.push({ label, count: added });
      weeklyRead.push({ label, count: readCount });
    }

    // Papers by project
    const byProject: Record<string, number> = {};
    papers.forEach(p => {
      const key = p.project_id ? `Project ${p.project_id}` : 'No Project';
      byProject[key] = (byProject[key] || 0) + 1;
    });

    // Average days to read
    const readPapersWithTime = papers.filter(p => p.status === 'read' && p.read_at && p.created_at);
    let avgDaysToRead = 0;
    if (readPapersWithTime.length > 0) {
      const totalDays = readPapersWithTime.reduce((sum, p) => {
        const added = new Date(p.created_at).getTime();
        const readAt = new Date(p.read_at!).getTime();
        return sum + (readAt - added) / (1000 * 60 * 60 * 24);
      }, 0);
      avgDaysToRead = Math.round(totalDays / readPapersWithTime.length);
    }

    const maxWeekly = Math.max(...weeklyAdded.map(w => w.count), ...weeklyRead.map(w => w.count), 1);

    return { total, read, unread, completionRate, weeklyAdded, weeklyRead, byProject, avgDaysToRead, maxWeekly };
  }, [papers]);

  if (loading) {
    return (
      <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh', color: 'var(--text-secondary)' }}>
        Loading analytics...
      </div>
    );
  }

  return (
    <div style={{ maxWidth: '960px', margin: '0 auto', padding: '2rem' }}>
      <div style={{ marginBottom: '2rem' }}>
        <a href="/dashboard" style={{ color: 'var(--text-accent)', textDecoration: 'none', display: 'inline-flex', alignItems: 'center', gap: '6px', fontSize: '0.9rem', marginBottom: '8px' }}>
          <ArrowLeft size={16} /> Back to Dashboard
        </a>
        <h1 className="title">Reading Analytics</h1>
        <p className="subtitle">Track your research reading habits</p>
      </div>

      {/* Stat cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '16px', marginBottom: '2rem' }}>
        <div className="glass-panel" style={{ padding: '20px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '8px', color: 'var(--text-secondary)', fontSize: '0.85rem' }}>
            <BookOpen size={18} /> Total Papers
          </div>
          <div style={{ fontSize: '2rem', fontWeight: 700 }}>{stats.total}</div>
        </div>
        <div className="glass-panel" style={{ padding: '20px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '8px', color: 'var(--text-secondary)', fontSize: '0.85rem' }}>
            <TrendingUp size={18} /> Completion Rate
          </div>
          <div style={{ fontSize: '2rem', fontWeight: 700 }}>{stats.completionRate}%</div>
        </div>
        <div className="glass-panel" style={{ padding: '20px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '8px', color: 'var(--text-secondary)', fontSize: '0.85rem' }}>
            <Clock size={18} /> Avg. Days to Read
          </div>
          <div style={{ fontSize: '2rem', fontWeight: 700 }}>{stats.avgDaysToRead || '—'}</div>
        </div>
        <div className="glass-panel" style={{ padding: '20px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '8px', color: 'var(--text-secondary)', fontSize: '0.85rem' }}>
            <FolderKey size={18} /> Unread Queue
          </div>
          <div style={{ fontSize: '2rem', fontWeight: 700 }}>{stats.unread}</div>
        </div>
      </div>

      {/* Weekly activity chart (CSS-based bars) */}
      <div className="glass-panel" style={{ padding: '24px', marginBottom: '2rem' }}>
        <h3 style={{ marginBottom: '4px' }}>Weekly Activity</h3>
        <p style={{ fontSize: '0.8rem', color: 'var(--text-secondary)', marginBottom: '20px' }}>
          <span style={{ display: 'inline-block', width: '12px', height: '12px', backgroundColor: 'var(--accent-color)', borderRadius: '2px', marginRight: '4px', verticalAlign: 'middle' }}></span> Added
          <span style={{ display: 'inline-block', width: '12px', height: '12px', backgroundColor: 'var(--success)', borderRadius: '2px', marginLeft: '12px', marginRight: '4px', verticalAlign: 'middle' }}></span> Read
        </p>
        <div style={{ display: 'flex', alignItems: 'flex-end', gap: '6px', height: '160px' }}>
          {stats.weeklyAdded.map((week, i) => (
            <div key={week.label} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '4px', height: '100%', justifyContent: 'flex-end' }}>
              <div style={{ display: 'flex', gap: '2px', alignItems: 'flex-end', width: '100%', justifyContent: 'center', flex: 1 }}>
                <div
                  style={{
                    width: '40%',
                    height: `${Math.max((week.count / stats.maxWeekly) * 100, week.count > 0 ? 8 : 0)}%`,
                    backgroundColor: 'var(--accent-color)',
                    borderRadius: '3px 3px 0 0',
                    minHeight: week.count > 0 ? '4px' : '0',
                    transition: 'height 0.3s ease',
                  }}
                  title={`${week.count} added`}
                />
                <div
                  style={{
                    width: '40%',
                    height: `${Math.max((stats.weeklyRead[i].count / stats.maxWeekly) * 100, stats.weeklyRead[i].count > 0 ? 8 : 0)}%`,
                    backgroundColor: 'var(--success)',
                    borderRadius: '3px 3px 0 0',
                    minHeight: stats.weeklyRead[i].count > 0 ? '4px' : '0',
                    transition: 'height 0.3s ease',
                  }}
                  title={`${stats.weeklyRead[i].count} read`}
                />
              </div>
              <span style={{ fontSize: '0.6rem', color: 'var(--text-secondary)', whiteSpace: 'nowrap' }}>{week.label}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Read vs Unread donut */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
        <div className="glass-panel" style={{ padding: '24px' }}>
          <h3 style={{ marginBottom: '16px' }}>Read vs Unread</h3>
          <div style={{ display: 'flex', alignItems: 'center', gap: '24px' }}>
            <svg viewBox="0 0 36 36" style={{ width: '120px', height: '120px' }}>
              <circle cx="18" cy="18" r="15.9" fill="none" stroke="var(--bg-tertiary)" strokeWidth="3" />
              <circle
                cx="18" cy="18" r="15.9" fill="none"
                stroke="var(--success)"
                strokeWidth="3"
                strokeDasharray={`${stats.completionRate} ${100 - stats.completionRate}`}
                strokeDashoffset="25"
                strokeLinecap="round"
              />
              <text x="18" y="18" textAnchor="middle" dominantBaseline="central" fill="var(--text-primary)" fontSize="8" fontWeight="700">
                {stats.completionRate}%
              </text>
            </svg>
            <div>
              <div style={{ marginBottom: '8px' }}>
                <span style={{ display: 'inline-block', width: '10px', height: '10px', backgroundColor: 'var(--success)', borderRadius: '50%', marginRight: '8px' }}></span>
                <span style={{ fontSize: '0.9rem' }}>Read: {stats.read}</span>
              </div>
              <div>
                <span style={{ display: 'inline-block', width: '10px', height: '10px', backgroundColor: 'var(--bg-tertiary)', borderRadius: '50%', marginRight: '8px' }}></span>
                <span style={{ fontSize: '0.9rem' }}>Unread: {stats.unread}</span>
              </div>
            </div>
          </div>
        </div>

        <div className="glass-panel" style={{ padding: '24px' }}>
          <h3 style={{ marginBottom: '16px' }}>Papers by Project</h3>
          {Object.entries(stats.byProject).length === 0 ? (
            <p style={{ color: 'var(--text-secondary)', fontSize: '0.9rem' }}>No papers yet.</p>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
              {Object.entries(stats.byProject).map(([name, count]) => (
                <div key={name}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.85rem', marginBottom: '4px' }}>
                    <span>{name}</span>
                    <span style={{ color: 'var(--text-secondary)' }}>{count}</span>
                  </div>
                  <div style={{ height: '6px', backgroundColor: 'var(--bg-tertiary)', borderRadius: '3px', overflow: 'hidden' }}>
                    <div style={{
                      height: '100%',
                      width: `${(count / stats.total) * 100}%`,
                      backgroundColor: 'var(--accent-color)',
                      borderRadius: '3px',
                      transition: 'width 0.3s ease',
                    }} />
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
