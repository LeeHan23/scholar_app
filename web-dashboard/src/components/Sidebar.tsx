"use client";

import { useState } from 'react';
import { BookOpen, FolderKey, Settings, Star, TrendingUp, Clock, Library } from 'lucide-react';

export default function Sidebar() {
    const [activeTab, setActiveTab] = useState('Reading Queue');

    const handleNavClick = (e: React.MouseEvent, tabName: string) => {
        e.preventDefault();
        setActiveTab(tabName);
    };

    return (
        <div className="sidebar">
            <div className="nav-logo">
                <Library className="text-accent" size={28} color="var(--text-accent)" />
                ScholarSync
            </div>

            <div style={{ padding: '0 16px', marginBottom: '8px', marginTop: '16px' }}>
                <h3 className="subtitle">Menu</h3>
            </div>
            <a href="#" className={`nav-item ${activeTab === 'Reading Queue' ? 'active' : ''}`} onClick={(e) => handleNavClick(e, 'Reading Queue')}>
                <Clock size={20} />
                Reading Queue
            </a>
            <a href="#" className={`nav-item ${activeTab === 'All Papers' ? 'active' : ''}`} onClick={(e) => handleNavClick(e, 'All Papers')}>
                <BookOpen size={20} />
                All Papers
            </a>
            <a href="#" className={`nav-item ${activeTab === 'Favorites' ? 'active' : ''}`} onClick={(e) => handleNavClick(e, 'Favorites')}>
                <Star size={20} />
                Favorites
            </a>

            <div style={{ padding: '0 16px', marginBottom: '8px', marginTop: '24px' }}>
                <h3 className="subtitle">Folders</h3>
            </div>
            <a href="#" className={`nav-item ${activeTab === 'Thesis Chapter 1' ? 'active' : ''}`} onClick={(e) => handleNavClick(e, 'Thesis Chapter 1')}>
                <FolderKey size={20} />
                Thesis Chapter 1
            </a>
            <a href="#" className={`nav-item ${activeTab === 'Literature Review' ? 'active' : ''}`} onClick={(e) => handleNavClick(e, 'Literature Review')}>
                <FolderKey size={20} />
                Literature Review
            </a>

            <div style={{ marginTop: 'auto', marginBottom: '16px' }}>
                <a href="#" className={`nav-item ${activeTab === 'Settings' ? 'active' : ''}`} onClick={(e) => handleNavClick(e, 'Settings')}>
                    <Settings size={20} />
                    Settings
                </a>
            </div>
        </div>
    );
}
