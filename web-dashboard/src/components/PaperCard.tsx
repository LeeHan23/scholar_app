"use client";

import { FileText, MoreVertical } from 'lucide-react';

export interface Paper {
    id: string;
    title: string;
    authors: string;
    journal: string | null;
    year: number;
    doi: string | null;
    status: 'unread' | 'read';
}

export default function PaperCard({ paper }: { paper: Paper }) {
    const handleMoreOptions = () => {
        alert(`More options for: ${paper.title}`);
    };

    return (
        <div className="glass-panel paper-card">
            <div className="paper-meta">
                <span>{paper.year}</span>
                {paper.journal && (
                    <>
                        <span>•</span>
                        <span>{paper.journal}</span>
                    </>
                )}
            </div>

            <h3 className="paper-title">{paper.title}</h3>
            <p className="paper-authors">{paper.authors}</p>

            <div className="paper-footer">
                <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                    <FileText size={16} color="var(--text-secondary)" />
                    {paper.status === 'unread' ? (
                        <span className="badge unread">Unread</span>
                    ) : (
                        <span className="badge">Read</span>
                    )}
                </div>
                <button className="icon-btn" aria-label="More options" onClick={handleMoreOptions}>
                    <MoreVertical size={16} color="var(--text-secondary)" />
                </button>
            </div>
        </div>
    );
}
