"use client";

import { BookOpen, FolderKey, Settings, Clock, Library, Eye, BarChart3, Lightbulb } from 'lucide-react';

export interface Project {
    id: number;
    name: string;
}

interface SidebarProps {
    activeFilter: string;
    onFilterChange: (filter: string) => void;
    projects: Project[];
}

export default function Sidebar({ activeFilter, onFilterChange, projects }: SidebarProps) {
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
                        <button
                            key={project.id}
                            className={`nav-item ${activeFilter === `project-${project.id}` ? 'active' : ''}`}
                            onClick={() => onFilterChange(`project-${project.id}`)}
                        >
                            <FolderKey size={20} />
                            {project.name}
                        </button>
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
