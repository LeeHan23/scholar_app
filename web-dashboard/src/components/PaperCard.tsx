"use client";

import { useRef } from 'react';
import { FileText, Edit, Trash2, MapPin, Tag, Paperclip, Eye } from 'lucide-react';

export interface Paper {
    id: string;
    title: string;
    authors: string;
    journal: string | null;
    year: number;
    doi: string | null;
    abstract: string | null;
    status: 'unread' | 'read';
    user_id: string;
    project_id: number | null;
    tags: string | null;
    location_name: string | null;
    latitude: number | null;
    longitude: number | null;
    page_number: number | null;
    pdf_url: string | null;
    read_at: string | null;
    created_at: string;
}

interface PaperCardProps {
    paper: Paper;
    onEdit?: (paper: Paper) => void;
    onDelete?: (paper: Paper) => void;
    onToggleStatus?: (paper: Paper) => void;
    onPdfUpload?: (paper: Paper, file: File) => void;
    onPdfView?: (paper: Paper) => void;
}

export default function PaperCard({ paper, onEdit, onDelete, onToggleStatus, onPdfUpload, onPdfView }: PaperCardProps) {
    const fileInputRef = useRef<HTMLInputElement>(null);
    const tagsList = paper.tags
        ? paper.tags.split(',').map(t => t.trim()).filter(Boolean)
        : [];

    return (
        <div className="glass-panel paper-card">
            <div className="paper-meta">
                <span>{paper.year}</span>
                {paper.journal && (
                    <>
                        <span>·</span>
                        <span>{paper.journal}</span>
                    </>
                )}
                {paper.doi && (
                    <>
                        <span>·</span>
                        <span style={{ fontSize: '0.65rem', opacity: 0.7 }}>{paper.doi}</span>
                    </>
                )}
            </div>

            <h3 className="paper-title">{paper.title}</h3>
            <p className="paper-authors">{paper.authors}</p>

            {tagsList.length > 0 && (
                <div style={{ display: 'flex', gap: '6px', flexWrap: 'wrap', alignItems: 'center' }}>
                    <Tag size={12} color="var(--text-secondary)" />
                    {tagsList.map(tag => (
                        <span key={tag} className="badge" style={{ fontSize: '0.65rem' }}>{tag}</span>
                    ))}
                </div>
            )}

            {paper.location_name && (
                <div style={{ display: 'flex', gap: '6px', alignItems: 'center', fontSize: '0.75rem', color: 'var(--text-secondary)' }}>
                    <MapPin size={12} />
                    {paper.location_name}
                </div>
            )}

            <div className="paper-footer">
                <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                    <FileText size={16} color="var(--text-secondary)" />
                    <button
                        className={`badge ${paper.status === 'unread' ? 'unread' : ''}`}
                        onClick={() => onToggleStatus?.(paper)}
                        style={{ cursor: 'pointer', border: 'none' }}
                        aria-label={`Mark as ${paper.status === 'unread' ? 'read' : 'unread'}`}
                    >
                        {paper.status === 'unread' ? 'Unread' : 'Read'}
                    </button>
                </div>
                <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                    {paper.pdf_url ? (
                        <button className="icon-btn" aria-label="View PDF" onClick={() => onPdfView?.(paper)} title="View PDF">
                            <Eye size={16} color="var(--success)" />
                        </button>
                    ) : null}
                    <button
                        className="icon-btn"
                        aria-label={paper.pdf_url ? "Replace PDF" : "Attach PDF"}
                        onClick={() => fileInputRef.current?.click()}
                        title={paper.pdf_url ? "Replace PDF" : "Attach PDF"}
                    >
                        <Paperclip size={16} color={paper.pdf_url ? "var(--success)" : "var(--text-secondary)"} />
                    </button>
                    <input
                        ref={fileInputRef}
                        type="file"
                        accept=".pdf"
                        style={{ display: 'none' }}
                        onChange={(e) => {
                            const file = e.target.files?.[0];
                            if (file) onPdfUpload?.(paper, file);
                            e.target.value = '';
                        }}
                    />
                    <button className="icon-btn" aria-label="Edit paper" onClick={() => onEdit?.(paper)}>
                        <Edit size={16} color="var(--text-secondary)" />
                    </button>
                    <button className="icon-btn" aria-label="Delete paper" onClick={() => onDelete?.(paper)}>
                        <Trash2 size={16} color="var(--text-secondary)" />
                    </button>
                </div>
            </div>
        </div>
    );
}
