"use client";

import { useState } from 'react';
import Sidebar from '../components/Sidebar';
import PaperCard, { Paper } from '../components/PaperCard';
import { Search, Plus } from 'lucide-react';

// Mock data for the UI
const initialQueue: Paper[] = [
  {
    id: '1',
    title: 'Attention Is All You Need',
    authors: 'Vaswani, A. et al.',
    journal: 'NIPS',
    year: 2017,
    doi: '10.48550/arXiv.1706.03762',
    status: 'unread'
  },
  {
    id: '2',
    title: 'BERT: Pre-training of Deep Bidirectional Transformers',
    authors: 'Devlin, J. et al.',
    journal: 'NAACL',
    year: 2019,
    doi: '10.48550/arXiv.1810.04805',
    status: 'unread'
  },
  {
    id: '3',
    title: 'Language Models are Few-Shot Learners',
    authors: 'Brown, T. et al.',
    journal: 'NeurIPS',
    year: 2020,
    doi: '10.48550/arXiv.2005.14165',
    status: 'unread'
  }
];

export default function Home() {
  const [queue, setQueue] = useState<Paper[]>(initialQueue);

  const handleAddPaper = () => {
    const newPaper: Paper = {
      id: Date.now().toString(),
      title: 'New Research Paper',
      authors: 'Author, A.',
      journal: 'Journal of Science',
      year: new Date().getFullYear(),
      doi: '10.0000/new-paper',
      status: 'unread'
    };
    setQueue([newPaper, ...queue]);
  };

  return (
    <div className="app-container">
      <Sidebar />
      <main className="main-content">
        <header className="header-actions">
          <div>
            <h1 className="title">Reading Queue</h1>
            <p className="subtitle">Papers synced from your iOS device</p>
          </div>
          <div style={{ display: 'flex', gap: '16px', alignItems: 'center' }}>
            <div className="search-container">
              <Search className="search-icon" size={18} />
              <input type="text" className="search-bar" placeholder="Search papers, DOIs, authors..." />
            </div>
            <button className="btn-primary" onClick={handleAddPaper}>
              <Plus size={18} />
              Add Paper
            </button>
          </div>
        </header>

        <div className="grid">
          {queue.map(paper => (
            <PaperCard key={paper.id} paper={paper} />
          ))}
        </div>
      </main>
    </div>
  );
}
