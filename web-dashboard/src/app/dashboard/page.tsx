"use client";

import { useState, useEffect, useMemo } from 'react';
import Sidebar, { Project } from '../../components/Sidebar';
import PaperCard, { Paper } from '../../components/PaperCard';
import RecommendationsPanel from '../../components/RecommendationsPanel';
import ProjectShareModal from '../../components/ProjectShareModal';
import PendingInvitations from '../../components/PendingInvitations';
import { Search, Plus, Share2 } from 'lucide-react';
import { supabase } from '../../lib/supabaseClient';
import AddPaperModal from '../../components/AddPaperModal';

export default function Home() {
  const [queue, setQueue] = useState<Paper[]>([]);
  const [projects, setProjects] = useState<Project[]>([]);
  const [loading, setLoading] = useState(true);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingPaper, setEditingPaper] = useState<Paper | null>(null);
  const [user, setUser] = useState<any>(null);
  const [accessToken, setAccessToken] = useState<string>('');
  const [searchQuery, setSearchQuery] = useState('');
  const [activeFilter, setActiveFilter] = useState('unread');
  const [shareModalProject, setShareModalProject] = useState<{ id: number; name: string } | null>(null);
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL ?? '';

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setUser(session?.user ?? null);
      setAccessToken(session?.access_token ?? '');
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
    } catch (error: any) {
      const msg = error?.message || JSON.stringify(error);
      console.error('Error fetching papers:', msg);
      setErrorMsg(`Papers: ${msg}`);
    } finally {
      setLoading(false);
    }
  };

  const fetchProjects = async () => {
    try {
      const { data, error } = await supabase
        .from('projects')
        .select('id, name, user_id')
        .order('name', { ascending: true });

      if (error) throw error;
      if (data) setProjects(data as Project[]);
    } catch (error) {
      console.error('Error fetching projects:', error);
    }
  };

  // Filter and search papers
  const filteredPapers = useMemo(() => {
    let papers = queue;

    // Apply status / project filter
    if (activeFilter === 'unread') {
      papers = papers.filter(p => p.status === 'unread');
    } else if (activeFilter === 'read') {
      papers = papers.filter(p => p.status === 'read');
    } else if (activeFilter.startsWith('project-')) {
      const projectId = parseInt(activeFilter.replace('project-', ''), 10);
      papers = papers.filter(p => p.project_id === projectId);
    }
    // 'all' — no filter

    // Apply search query
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      papers = papers.filter(p =>
        p.title.toLowerCase().includes(q) ||
        p.authors.toLowerCase().includes(q) ||
        (p.journal && p.journal.toLowerCase().includes(q)) ||
        (p.doi && p.doi.toLowerCase().includes(q)) ||
        (p.tags && p.tags.toLowerCase().includes(q))
      );
    }

    return papers;
  }, [queue, activeFilter, searchQuery]);

  const handleAddPaperClick = () => {
    setEditingPaper(null);
    setIsModalOpen(true);
  };

  const handleEditClick = (paper: Paper) => {
    setEditingPaper(paper);
    setIsModalOpen(true);
  };

  const handleDeleteClick = async (paper: Paper) => {
    if (!confirm(`Are you sure you want to delete "${paper.title}"?`)) return;

    try {
      const { error } = await supabase.from('papers').delete().eq('id', paper.id);
      if (error) throw error;
      setQueue(queue.filter(p => p.id !== paper.id));
    } catch (err) {
      console.error(err);
      alert('Failed to delete paper');
    }
  };

  const handleToggleStatus = async (paper: Paper) => {
    const newStatus = paper.status === 'unread' ? 'read' : 'unread';
    const updateData: Record<string, unknown> = { status: newStatus };
    if (newStatus === 'read') {
      updateData.read_at = new Date().toISOString();
    } else {
      updateData.read_at = null;
    }

    try {
      const { error } = await supabase
        .from('papers')
        .update(updateData)
        .eq('id', paper.id);

      if (error) throw error;
      setQueue(queue.map(p => p.id === paper.id
        ? { ...p, status: newStatus, read_at: updateData.read_at as string | null }
        : p
      ));
    } catch (err) {
      console.error(err);
    }
  };

  const handlePdfUpload = async (paper: Paper, file: File) => {
    const userId = user?.id;
    if (!userId) return;

    const storagePath = `${userId}/${paper.id}.pdf`;

    try {
      const { error: uploadError } = await supabase.storage
        .from('papers')
        .upload(storagePath, file, { upsert: true, contentType: 'application/pdf' });

      if (uploadError) throw uploadError;

      const { error: updateError } = await supabase
        .from('papers')
        .update({ pdf_url: storagePath })
        .eq('id', paper.id);

      if (updateError) throw updateError;

      setQueue(prev => prev.map(p => p.id === paper.id ? { ...p, pdf_url: storagePath } : p));
    } catch (err) {
      console.error('PDF upload failed:', err);
      alert('Failed to upload PDF.');
    }
  };

  const handlePdfView = async (paper: Paper) => {
    if (!paper.pdf_url) return;

    try {
      const { data, error } = await supabase.storage
        .from('papers')
        .createSignedUrl(paper.pdf_url, 3600);

      if (error) throw error;
      if (data?.signedUrl) {
        window.open(data.signedUrl, '_blank');
      }
    } catch (err) {
      console.error('Failed to get PDF URL:', err);
      alert('Failed to open PDF.');
    }
  };

  const handleLogout = async () => {
    await supabase.auth.signOut();
  };

  const sanitizeText = (val: unknown): unknown => {
    if (typeof val === 'string') {
      return val
        .replace(/\\u[0-9a-fA-F]{4}/g, '') // remove \uXXXX escape sequences
        .replace(/[\x00-\x08\x0B\x0C\x0E-\x1F]/g, '') // remove control chars (keep \n \r \t)
        .trim();
    }
    return val;
  };

  const sanitizePaperData = (data: Record<string, unknown>) => {
    const clean: Record<string, unknown> = {};
    for (const [key, val] of Object.entries(data)) {
      clean[key] = sanitizeText(val);
    }
    return clean;
  };

  const handleSavePaper = async (paperData: any, pdfFile?: File) => {
    const cleanData = sanitizePaperData(paperData);

    // Step 1: Save the paper
    let savedPaper: Paper;
    try {
      if (editingPaper) {
        const { data, error } = await supabase
          .from('papers')
          .update(cleanData)
          .eq('id', editingPaper.id)
          .select();

        if (error) throw error;
        savedPaper = data![0] as Paper;
        setQueue(prev => prev.map(p => p.id === editingPaper.id ? savedPaper : p));
      } else {
        const { data, error } = await supabase
          .from('papers')
          .insert([{ ...cleanData, user_id: user.id }])
          .select();

        if (error) throw error;
        savedPaper = data![0] as Paper;
        setQueue(prev => [savedPaper, ...prev]);
      }
    } catch (error: any) {
      const msg = error?.message || error?.error_description || JSON.stringify(error);
      alert(`Failed to save paper: ${msg}`);
      throw error;
    }

    // Step 2: Upload PDF if provided (non-blocking — paper is already saved)
    if (pdfFile && savedPaper.id && user?.id) {
      try {
        const storagePath = `${user.id}/${savedPaper.id}.pdf`;
        const { error: uploadError } = await supabase.storage
          .from('papers')
          .upload(storagePath, pdfFile, { upsert: true, contentType: 'application/pdf' });

        if (uploadError) {
          alert(`Paper saved, but PDF upload failed: ${uploadError.message}`);
          return;
        }

        const { error: updateError } = await supabase
          .from('papers')
          .update({ pdf_url: storagePath })
          .eq('id', savedPaper.id);

        if (updateError) {
          alert(`PDF uploaded, but linking failed: ${updateError.message}`);
          return;
        }

        setQueue(prev => prev.map(p => p.id === savedPaper.id ? { ...p, pdf_url: storagePath } : p));
      } catch (pdfErr: any) {
        alert(`Paper saved, but PDF upload failed: ${pdfErr?.message || 'network error'}`);
      }
    }
  };

  const filterLabel = activeFilter === 'unread'
    ? 'Reading Queue'
    : activeFilter === 'read'
      ? 'Read Papers'
      : activeFilter === 'all'
        ? 'All Papers'
        : activeFilter.startsWith('project-')
          ? projects.find(p => p.id === parseInt(activeFilter.replace('project-', ''), 10))?.name ?? 'Project'
          : 'Papers';

  return (
    <div className="app-container">
      <Sidebar
        activeFilter={activeFilter}
        onFilterChange={setActiveFilter}
        projects={projects}
        onShareProject={setShareModalProject}
        currentUserId={user?.id}
      />
      <main className="main-content">
        <header className="header-actions">
          <div>
            <h1 className="title">{filterLabel}</h1>
            <p className="subtitle">
              {filteredPapers.length} paper{filteredPapers.length !== 1 ? 's' : ''}
              {searchQuery && ` matching "${searchQuery}"`}
            </p>
          </div>
          <div style={{ display: 'flex', gap: '16px', alignItems: 'center' }}>
            <div className="search-container">
              <Search className="search-icon" size={18} />
              <input
                type="text"
                className="search-bar"
                placeholder="Search papers, DOIs, authors..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
              />
            </div>
            <button className="btn-primary" onClick={handleAddPaperClick}>
              <Plus size={18} />
              Add Paper
            </button>
            <button className="btn-secondary" onClick={handleLogout} style={{ padding: '8px 16px', background: 'transparent', color: 'var(--text-secondary)', border: '1px solid var(--border-color)', borderRadius: '6px', cursor: 'pointer' }}>
              Logout
            </button>
          </div>
        </header>

        {/* Pending group invitations banner */}
        {user?.email && (
          <PendingInvitations
            userId={user.id}
            userEmail={user.email}
            onAccepted={fetchProjects}
          />
        )}

        {errorMsg && (
          <div style={{ padding: '12px 16px', marginBottom: '16px', background: 'rgba(239,68,68,0.15)', border: '1px solid rgba(239,68,68,0.3)', borderRadius: '8px', color: '#f87171', fontSize: '0.85rem' }}>
            {errorMsg}
          </div>
        )}

        {loading ? (
          <div style={{ textAlign: 'center', marginTop: '40px', color: 'var(--text-secondary)' }}>
            Loading papers from Supabase...
          </div>
        ) : filteredPapers.length === 0 ? (
          <div style={{ textAlign: 'center', marginTop: '40px', color: 'var(--text-secondary)' }}>
            {queue.length === 0
              ? 'No papers found. Add one to get started!'
              : 'No papers match your current filter.'}
          </div>
        ) : (
          <div className="grid">
            {filteredPapers.map(paper => (
              <PaperCard
                key={paper.id}
                paper={paper}
                onEdit={handleEditClick}
                onDelete={handleDeleteClick}
                onToggleStatus={handleToggleStatus}
                onPdfUpload={handlePdfUpload}
                onPdfView={handlePdfView}
              />
            ))}
          </div>
        )}

        {user && (
          <RecommendationsPanel
            queue={queue}
            userId={user.id}
            onPaperAdded={(paper) => setQueue(prev => [paper, ...prev])}
          />
        )}

        <AddPaperModal
          isOpen={isModalOpen}
          onClose={() => setIsModalOpen(false)}
          onSave={handleSavePaper}
          initialData={editingPaper}
        />

        {/* Project share modal */}
        {shareModalProject && user && (
          <ProjectShareModal
            project={shareModalProject}
            currentUserId={user.id}
            currentUserEmail={user.email ?? ''}
            supabaseUrl={supabaseUrl}
            accessToken={accessToken}
            onClose={() => setShareModalProject(null)}
          />
        )}
      </main>
    </div>
  );
}
