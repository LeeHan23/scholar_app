"use client";

import { useEffect, useState } from 'react';
import { Library, BookOpen, Scan, FolderKey, BarChart3, Globe, Smartphone, ArrowRight, Check } from 'lucide-react';
import { supabase } from '../lib/supabaseClient';

export default function LandingPage() {
  const [isLoggedIn, setIsLoggedIn] = useState(false);

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setIsLoggedIn(!!session?.user);
    });
  }, []);

  return (
    <div className="landing">
      {/* Nav */}
      <nav className="landing-nav">
        <div className="landing-nav-inner">
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
            <Library size={24} color="var(--text-accent)" />
            <span style={{ fontWeight: 700, fontSize: '1.2rem' }}>ScholarSync</span>
          </div>
          <div style={{ display: 'flex', gap: '12px' }}>
            {isLoggedIn ? (
              <a href="/dashboard" className="btn-primary" style={{ textDecoration: 'none', fontSize: '0.9rem', padding: '8px 20px' }}>
                Go to Dashboard <ArrowRight size={16} />
              </a>
            ) : (
              <>
                <a href="/login" className="btn-secondary" style={{ textDecoration: 'none', fontSize: '0.9rem', padding: '8px 20px' }}>Log In</a>
                <a href="/login" className="btn-primary" style={{ textDecoration: 'none', fontSize: '0.9rem', padding: '8px 20px' }}>
                  Get Started <ArrowRight size={16} />
                </a>
              </>
            )}
          </div>
        </div>
      </nav>

      {/* Hero */}
      <section className="landing-hero">
        <div className="landing-badge">Built for researchers, by researchers</div>
        <h1 className="landing-h1">
          Your scholarly reading queue,<br />
          <span style={{ color: 'var(--text-accent)' }}>finally organized.</span>
        </h1>
        <p className="landing-subheading">
          Scan paper barcodes, capture DOIs, and manage your reading queue across
          iOS, web, and browser extension. Export to BibTeX, RIS, or Zotero in one tap.
        </p>
        <div style={{ display: 'flex', gap: '16px', justifyContent: 'center', flexWrap: 'wrap' }}>
          <a href="/login" className="btn-primary" style={{ textDecoration: 'none', padding: '14px 32px', fontSize: '1rem' }}>
            Start Free <ArrowRight size={18} />
          </a>
          <a href="#pricing" className="btn-secondary" style={{ textDecoration: 'none', padding: '14px 32px', fontSize: '1rem' }}>
            View Pricing
          </a>
        </div>
      </section>

      {/* Features */}
      <section className="landing-section" id="features">
        <h2 className="landing-h2">Everything you need to manage your reading</h2>
        <div className="landing-features-grid">
          <div className="glass-panel landing-feature-card">
            <div className="landing-feature-icon"><Scan size={24} /></div>
            <h3>Barcode & DOI Scanning</h3>
            <p>Point your camera at a barcode or DOI. Metadata is fetched automatically from Crossref and Open Library.</p>
          </div>
          <div className="glass-panel landing-feature-card">
            <div className="landing-feature-icon"><FolderKey size={24} /></div>
            <h3>Project Organization</h3>
            <p>Group papers into projects — thesis chapters, literature reviews, or lab reading groups.</p>
          </div>
          <div className="glass-panel landing-feature-card">
            <div className="landing-feature-icon"><BookOpen size={24} /></div>
            <h3>Citation Export</h3>
            <p>Export your papers as BibTeX, RIS, or CSV. Sync directly to Zotero with one tap.</p>
          </div>
          <div className="glass-panel landing-feature-card">
            <div className="landing-feature-icon"><BarChart3 size={24} /></div>
            <h3>Reading Analytics</h3>
            <p>Track your reading velocity, queue depth, and completion rate with built-in analytics.</p>
          </div>
          <div className="glass-panel landing-feature-card">
            <div className="landing-feature-icon"><Globe size={24} /></div>
            <h3>Browser Extension</h3>
            <p>Save papers from arXiv, Nature, IEEE, and more with a single click in your browser.</p>
          </div>
          <div className="glass-panel landing-feature-card">
            <div className="landing-feature-icon"><Smartphone size={24} /></div>
            <h3>Cross-Platform Sync</h3>
            <p>iOS app, web dashboard, and browser extension all sync in real time via Supabase.</p>
          </div>
        </div>
      </section>

      {/* How it works */}
      <section className="landing-section">
        <h2 className="landing-h2">How it works</h2>
        <div className="landing-steps">
          <div className="landing-step">
            <div className="landing-step-num">1</div>
            <h3>Capture</h3>
            <p>Scan a barcode, type a DOI, or use the browser extension on any academic site.</p>
          </div>
          <div className="landing-step">
            <div className="landing-step-num">2</div>
            <h3>Organize</h3>
            <p>Papers are auto-tagged with metadata. Assign to projects, add tags, track your place.</p>
          </div>
          <div className="landing-step">
            <div className="landing-step-num">3</div>
            <h3>Export</h3>
            <p>When it is time to write, export your bibliography to BibTeX, RIS, CSV, or Zotero.</p>
          </div>
        </div>
      </section>

      {/* Pricing */}
      <section className="landing-section" id="pricing">
        <h2 className="landing-h2">Simple, researcher-friendly pricing</h2>
        <div className="landing-pricing-grid">
          <div className="glass-panel landing-pricing-card">
            <h3>Free</h3>
            <div className="landing-price">$0</div>
            <p className="landing-price-period">forever</p>
            <ul className="landing-pricing-list">
              <li><Check size={16} color="var(--success)" /> Up to 15 captures/month</li>
              <li><Check size={16} color="var(--success)" /> All scanning modes</li>
              <li><Check size={16} color="var(--success)" /> BibTeX & RIS export</li>
              <li><Check size={16} color="var(--success)" /> Browser extension</li>
              <li><Check size={16} color="var(--success)" /> 1 project</li>
            </ul>
            <a href="/login" className="btn-secondary" style={{ textDecoration: 'none', width: '100%', textAlign: 'center', display: 'block', padding: '12px' }}>
              Get Started
            </a>
          </div>
          <div className="glass-panel landing-pricing-card landing-pricing-featured">
            <div className="landing-pricing-badge">Most popular</div>
            <h3>Pro</h3>
            <div className="landing-price">$4.99</div>
            <p className="landing-price-period">per month &middot; or $39.99/year</p>
            <ul className="landing-pricing-list">
              <li><Check size={16} color="var(--text-accent)" /> Unlimited papers</li>
              <li><Check size={16} color="var(--text-accent)" /> PDF storage & viewer</li>
              <li><Check size={16} color="var(--text-accent)" /> Zotero sync</li>
              <li><Check size={16} color="var(--text-accent)" /> Reading analytics</li>
              <li><Check size={16} color="var(--text-accent)" /> Unlimited projects</li>
              <li><Check size={16} color="var(--text-accent)" /> Shared projects & collaboration</li>
            </ul>
            <a href="/login" className="btn-primary" style={{ textDecoration: 'none', width: '100%', textAlign: 'center', display: 'block', padding: '12px' }}>
              Start Free Trial
            </a>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="landing-footer">
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          <Library size={20} color="var(--text-accent)" />
          <span style={{ fontWeight: 600 }}>ScholarSync</span>
        </div>
        <p style={{ color: 'var(--text-secondary)', fontSize: '0.85rem' }}>
          &copy; {new Date().getFullYear()} ScholarSync. Built for the academic community.
        </p>
      </footer>
    </div>
  );
}
