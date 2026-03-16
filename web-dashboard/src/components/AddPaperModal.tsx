import React, { useState, useEffect, useRef } from 'react';
import { X, Paperclip, Loader } from 'lucide-react';
import { extractMetadataFromPDF, ExtractedMetadata } from '../lib/pdfExtractor';

interface AddPaperModalProps {
    isOpen: boolean;
    onClose: () => void;
    onSave: (paperData: any, pdfFile?: File) => Promise<void>;
    initialData?: any;
}

export default function AddPaperModal({ isOpen, onClose, onSave, initialData }: AddPaperModalProps) {
    const [title, setTitle] = useState('');
    const [authors, setAuthors] = useState('');
    const [journal, setJournal] = useState('');
    const [year, setYear] = useState(new Date().getFullYear().toString());
    const [doi, setDoi] = useState('');
    const [pdfFile, setPdfFile] = useState<File | null>(null);
    const [isSubmitting, setIsSubmitting] = useState(false);
    const [isExtracting, setIsExtracting] = useState(false);
    const [extractionSource, setExtractionSource] = useState<string | null>(null);
    const [autoFilledFields, setAutoFilledFields] = useState<Set<string>>(new Set());
    const fileInputRef = useRef<HTMLInputElement>(null);

    useEffect(() => {
        if (isOpen) {
            if (initialData) {
                setTitle(initialData.title || '');
                setAuthors(initialData.authors || '');
                setJournal(initialData.journal || '');
                setYear(initialData.year?.toString() || new Date().getFullYear().toString());
                setDoi(initialData.doi || '');
            } else {
                setTitle('');
                setAuthors('');
                setJournal('');
                setYear(new Date().getFullYear().toString());
                setDoi('');
            }
            setPdfFile(null);
            setExtractionSource(null);
            setAutoFilledFields(new Set());
        }
    }, [isOpen, initialData]);

    const handlePdfSelect = async (file: File) => {
        setPdfFile(file);
        setIsExtracting(true);
        setExtractionSource(null);
        setAutoFilledFields(new Set());

        try {
            const metadata = await extractMetadataFromPDF(file);
            const filled = new Set<string>();

            // Only auto-fill empty fields (don't overwrite user input)
            if (metadata.title && !title) {
                setTitle(metadata.title);
                filled.add('title');
            }
            if (metadata.authors && !authors) {
                setAuthors(metadata.authors);
                filled.add('authors');
            }
            if (metadata.journal && !journal) {
                setJournal(metadata.journal);
                filled.add('journal');
            }
            if (metadata.year && (!year || year === new Date().getFullYear().toString())) {
                setYear(metadata.year);
                filled.add('year');
            }
            if (metadata.doi && !doi) {
                setDoi(metadata.doi);
                filled.add('doi');
            }

            setAutoFilledFields(filled);

            if (metadata.source === 'crossref') {
                setExtractionSource('Auto-filled from CrossRef via DOI');
            } else if (metadata.source === 'pdf-text' && filled.size > 0) {
                setExtractionSource('Extracted from PDF text — please verify');
            } else if (filled.size === 0) {
                setExtractionSource('Could not extract metadata — please fill in manually');
            }
        } catch {
            setExtractionSource('Extraction failed — please fill in manually');
        } finally {
            setIsExtracting(false);
        }
    };

    if (!isOpen) return null;

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!title || !authors) {
            alert("Title and Authors are required");
            return;
        }

        setIsSubmitting(true);

        const paperData = {
            title,
            authors,
            journal: journal || null,
            year: parseInt(year) || new Date().getFullYear(),
            doi: doi || null,
            status: 'unread'
        };

        try {
            await onSave(paperData, pdfFile || undefined);
            onClose();
        } catch (error) {
            console.error(error);
        } finally {
            setIsSubmitting(false);
        }
    };

    const fieldStyle = (fieldName: string): React.CSSProperties =>
        autoFilledFields.has(fieldName)
            ? { borderColor: 'var(--success)', boxShadow: '0 0 0 1px var(--success)' }
            : {};

    return (
        <div className="modal-overlay" onClick={onClose}>
            <div className="modal-content" onClick={(e) => e.stopPropagation()}>
                <div className="modal-header">
                    <h2 className="modal-title">{initialData ? 'Edit Paper' : 'Add Paper'}</h2>
                    <button className="close-btn" onClick={onClose} aria-label="Close modal">
                        <X size={20} />
                    </button>
                </div>

                <form onSubmit={handleSubmit}>
                    {/* PDF upload — shown first to encourage upload-first flow */}
                    <div className="form-group">
                        <label className="form-label">
                            Upload PDF {!initialData && <span style={{ color: 'var(--text-secondary)', fontWeight: 400 }}>— auto-fills details</span>}
                        </label>
                        <div
                            onClick={() => !isExtracting && fileInputRef.current?.click()}
                            style={{
                                border: '2px dashed var(--border-color)',
                                borderRadius: 'var(--radius-md)',
                                padding: '16px',
                                textAlign: 'center',
                                cursor: isExtracting ? 'wait' : 'pointer',
                                transition: 'border-color 0.2s ease',
                                background: pdfFile ? 'rgba(16, 185, 129, 0.08)' : 'transparent',
                                borderColor: pdfFile ? 'var(--success)' : 'var(--border-color)',
                            }}
                        >
                            {isExtracting ? (
                                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px' }}>
                                    <Loader size={18} color="var(--text-accent)" className="spin" />
                                    <span style={{ fontSize: '0.85rem', color: 'var(--text-accent)' }}>Extracting metadata...</span>
                                </div>
                            ) : pdfFile ? (
                                <div>
                                    <Paperclip size={18} color="var(--success)" style={{ marginBottom: '4px' }} />
                                    <div style={{ fontSize: '0.85rem', color: 'var(--success)', fontWeight: 500 }}>
                                        {pdfFile.name}
                                    </div>
                                    <div style={{ fontSize: '0.75rem', color: 'var(--text-secondary)', marginTop: '2px' }}>
                                        {(pdfFile.size / 1024 / 1024).toFixed(1)} MB — click to change
                                    </div>
                                </div>
                            ) : (
                                <div>
                                    <Paperclip size={18} color="var(--text-secondary)" style={{ marginBottom: '4px' }} />
                                    <div style={{ fontSize: '0.85rem', color: 'var(--text-secondary)' }}>
                                        Click to select a PDF — details will be auto-filled
                                    </div>
                                </div>
                            )}
                            <input
                                ref={fileInputRef}
                                type="file"
                                accept=".pdf"
                                style={{ display: 'none' }}
                                onChange={(e) => {
                                    const file = e.target.files?.[0];
                                    if (file) handlePdfSelect(file);
                                }}
                            />
                        </div>
                        {extractionSource && (
                            <div style={{
                                fontSize: '0.75rem',
                                marginTop: '6px',
                                padding: '6px 10px',
                                borderRadius: '6px',
                                background: extractionSource.includes('CrossRef')
                                    ? 'rgba(16, 185, 129, 0.1)'
                                    : extractionSource.includes('verify')
                                        ? 'rgba(245, 158, 11, 0.1)'
                                        : 'rgba(239, 68, 68, 0.1)',
                                color: extractionSource.includes('CrossRef')
                                    ? 'var(--success)'
                                    : extractionSource.includes('verify')
                                        ? 'var(--warning)'
                                        : '#f87171',
                            }}>
                                {extractionSource}
                            </div>
                        )}
                    </div>

                    <div className="form-group">
                        <label className="form-label" htmlFor="title">Paper Title *</label>
                        <input
                            id="title"
                            type="text"
                            className="form-input"
                            value={title}
                            onChange={(e) => { setTitle(e.target.value); setAutoFilledFields(prev => { const n = new Set(prev); n.delete('title'); return n; }); }}
                            placeholder="e.g. Attention Is All You Need"
                            style={fieldStyle('title')}
                            required
                        />
                    </div>

                    <div className="form-group">
                        <label className="form-label" htmlFor="authors">Authors *</label>
                        <input
                            id="authors"
                            type="text"
                            className="form-input"
                            value={authors}
                            onChange={(e) => { setAuthors(e.target.value); setAutoFilledFields(prev => { const n = new Set(prev); n.delete('authors'); return n; }); }}
                            placeholder="e.g. Vaswani, A. et al."
                            style={fieldStyle('authors')}
                            required
                        />
                    </div>

                    <div className="form-group">
                        <label className="form-label" htmlFor="journal">Journal / Conference</label>
                        <input
                            id="journal"
                            type="text"
                            className="form-input"
                            value={journal}
                            onChange={(e) => { setJournal(e.target.value); setAutoFilledFields(prev => { const n = new Set(prev); n.delete('journal'); return n; }); }}
                            placeholder="e.g. NeurIPS"
                            style={fieldStyle('journal')}
                        />
                    </div>

                    <div className="form-group" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                        <div>
                            <label className="form-label" htmlFor="year">Year</label>
                            <input
                                id="year"
                                type="number"
                                className="form-input"
                                value={year}
                                onChange={(e) => { setYear(e.target.value); setAutoFilledFields(prev => { const n = new Set(prev); n.delete('year'); return n; }); }}
                                style={fieldStyle('year')}
                            />
                        </div>
                        <div>
                            <label className="form-label" htmlFor="doi">DOI / arXiv ID</label>
                            <input
                                id="doi"
                                type="text"
                                className="form-input"
                                value={doi}
                                onChange={(e) => { setDoi(e.target.value); setAutoFilledFields(prev => { const n = new Set(prev); n.delete('doi'); return n; }); }}
                                placeholder="e.g. 10.48550/arXiv.1706.03762"
                                style={fieldStyle('doi')}
                            />
                        </div>
                    </div>

                    <div className="modal-footer">
                        <button type="button" className="btn-secondary" onClick={onClose} disabled={isSubmitting || isExtracting}>
                            Cancel
                        </button>
                        <button type="submit" className="btn-primary" disabled={isSubmitting || isExtracting}>
                            {isSubmitting ? 'Saving...' : (initialData ? 'Save Changes' : 'Save Paper')}
                        </button>
                    </div>
                </form>
            </div>
        </div>
    );
}
