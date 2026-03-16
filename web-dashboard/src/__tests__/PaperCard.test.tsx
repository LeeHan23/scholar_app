import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import PaperCard, { Paper } from '../components/PaperCard';

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

describe('PaperCard', () => {
  it('renders paper title, authors, year, and journal', () => {
    render(<PaperCard paper={makePaper()} />);

    expect(screen.getByText('Attention Is All You Need')).toBeInTheDocument();
    expect(screen.getByText('Vaswani, A. et al.')).toBeInTheDocument();
    expect(screen.getByText('2017')).toBeInTheDocument();
    expect(screen.getByText('NeurIPS')).toBeInTheDocument();
  });

  it('shows Unread badge for unread papers', () => {
    render(<PaperCard paper={makePaper({ status: 'unread' })} />);
    expect(screen.getByText('Unread')).toBeInTheDocument();
  });

  it('shows Read badge for read papers', () => {
    render(<PaperCard paper={makePaper({ status: 'read' })} />);
    expect(screen.getByText('Read')).toBeInTheDocument();
  });

  it('displays tags when present', () => {
    render(<PaperCard paper={makePaper({ tags: 'nlp, transformers' })} />);
    expect(screen.getByText('nlp')).toBeInTheDocument();
    expect(screen.getByText('transformers')).toBeInTheDocument();
  });

  it('displays location when present', () => {
    render(<PaperCard paper={makePaper({ location_name: 'MIT Library' })} />);
    expect(screen.getByText('MIT Library')).toBeInTheDocument();
  });

  it('hides location when not present', () => {
    render(<PaperCard paper={makePaper({ location_name: null })} />);
    expect(screen.queryByText('MIT Library')).not.toBeInTheDocument();
  });

  it('calls onEdit when edit button is clicked', () => {
    const onEdit = vi.fn();
    const paper = makePaper();
    render(<PaperCard paper={paper} onEdit={onEdit} />);

    fireEvent.click(screen.getByLabelText('Edit paper'));
    expect(onEdit).toHaveBeenCalledWith(paper);
  });

  it('calls onDelete when delete button is clicked', () => {
    const onDelete = vi.fn();
    const paper = makePaper();
    render(<PaperCard paper={paper} onDelete={onDelete} />);

    fireEvent.click(screen.getByLabelText('Delete paper'));
    expect(onDelete).toHaveBeenCalledWith(paper);
  });

  it('calls onToggleStatus when status badge is clicked', () => {
    const onToggleStatus = vi.fn();
    const paper = makePaper({ status: 'unread' });
    render(<PaperCard paper={paper} onToggleStatus={onToggleStatus} />);

    fireEvent.click(screen.getByLabelText('Mark as read'));
    expect(onToggleStatus).toHaveBeenCalledWith(paper);
  });
});
