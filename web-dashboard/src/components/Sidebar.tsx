"use client";

import { BookOpen, FolderKey, Settings, Clock, Library, Eye, BarChart3, Lightbulb, Share2 } from 'lucide-react';

export interface Project {
    id: number;
    name: string;
    user_id?: string;
}

interface SidebarProps {
    activeFilter: string;
    onFilterChange: (filter: string) => void;
    projects: Project[];
    onShareProject?: (project: { id: number; name: string }) => void;
    currentUserId?: string;
}

export default function Sidebar({ activeFilter, onFilterChange, projects, onShareProject, currentUserId }: SidebarProps) {
    return (
        <div className="sidebar">
            <div className="nav-logo">
                <Library className="text-accent" size={28} color="var(--text-accent)" />
                ScholarSync
            </div>

            <div style={{ padding: '0 16px', marginBottom: '8px', marginTop: '16px' }}>
                <h3 className="subtitle">Menu</h3>
            </div>
            <button
                className={`nav-item ${activeFilter === 'unread' ? 'active' : ''}`}
                onClick={() => onFilterChange('unread')}
            >
                <Clock size={20} />
                Reading Queue
            </button>
            <button
                className={`nav-item ${activeFilter === 'all' ? 'active' : ''}`}
                onClick={() => onFilterChange('all')}
            >
                <BookOpen size={20} />
                All Papers
            </button>
            <button
                className={`nav-item ${activeFilter === 'read' ? 'active' : ''}`}
                onClick={() => onFilterChange('read')}
            >
                <Eye size={20} />
                Read
            </button>
            <a
                href="/dashboard/discover"
                className={`nav-item ${activeFilter === 'discover' ? 'active' : ''}`}
                style={{ textDecoration: 'none' }}
            >
                <Lightbulb size={20} />
                Discover
            </a>

            {projects.length > 0 && (
                <>
                    <div style={{ padding: '0 16px', marginBottom: '8px', marginTop: '24px' }}>
                        <h3 className="subtitle">Projects</h3>
                    </div>
                    {projects.map(project => (
                        <div key={project.id} style={{ display: 'flex', alignItems: 'center' }}>
                            <button
                                className={`nav-item ${activeFilter === `project-${project.id}` ? 'active' : ''}`}
                                onClick={() => onFilterChange(`project-${project.id}`)}
                                style={{ flex: 1 }}
                            >
                                <FolderKey size={20} />
                                {project.name}
                            </button>
                            {onShareProject && project.user_id === currentUserId && (
                                <button
                                    onClick={e => { e.stopPropagation(); onShareProject({ id: project.id, name: project.name }); }}
                                    title="Share project"
                                    style={{ background: 'none', border: 'none', cursor: 'pointer', padding: '4px 8px', color: 'var(--text-secondary)', borderRadius: '4px', display: 'flex', alignItems: 'center' }}
                                    onMouseOver={e => (e.currentTarget.style.color = 'var(--text-primary)')}
                                    onMouseOut={e => (e.currentTarget.style.color = 'var(--text-secondary)')}
                                >
                                    <Share2 size={14} />
                                </button>
                            )}
                        </div>
                    ))}
                </>
            )}

            <div style={{ marginTop: 'auto', marginBottom: '16px', display: 'flex', flexDirection: 'column' }}>
                <a href="/dashboard/analytics" className="nav-item" style={{ textDecoration: 'none' }}>
                    <BarChart3 size={20} />
                    Analytics
                </a>
                <button
                    className={`nav-item ${activeFilter === 'settings' ? 'active' : ''}`}
                    onClick={() => onFilterChange('settings')}
                >
                    <Settings size={20} />
                    Settings
                </button>
            </div>
        </div>
    );
}
