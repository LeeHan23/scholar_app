export default function PrivacyPolicy() {
  return (
    <div style={{ maxWidth: '720px', margin: '0 auto', padding: '60px 24px', lineHeight: 1.8 }}>
      <h1 style={{ fontSize: '2rem', fontWeight: 700, marginBottom: '8px' }}>Privacy Policy</h1>
      <p style={{ color: 'var(--text-secondary)', marginBottom: '40px' }}>Last updated: March 13, 2026</p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '12px' }}>1. What We Collect</h2>
        <p style={{ color: 'var(--text-secondary)' }}>
          ScholarSync collects only the information necessary to provide the service:
        </p>
        <ul style={{ color: 'var(--text-secondary)', paddingLeft: '24px', marginTop: '8px' }}>
          <li>Email address (for authentication)</li>
          <li>Paper metadata you save (title, authors, DOI, journal, year, tags, location)</li>
          <li>PDF files you upload (stored in private Supabase Storage buckets)</li>
          <li>Device location (only when you explicitly tap the location button)</li>
        </ul>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '12px' }}>2. How We Use It</h2>
        <p style={{ color: 'var(--text-secondary)' }}>
          Your data is used solely to provide ScholarSync&apos;s features: storing your reading queue,
          syncing across devices, generating analytics, and enabling collaboration. We do not sell,
          rent, or share your data with third parties for advertising purposes.
        </p>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '12px' }}>3. Browser Extension</h2>
        <p style={{ color: 'var(--text-secondary)' }}>
          The ScholarSync browser extension reads page metadata (DOI, title, authors) only on academic
          publisher sites you visit (arxiv.org, nature.com, jstor.org, sciencedirect.com, doi.org, ieee.org).
          It does not track browsing history, inject ads, or collect data on non-academic sites.
          Authentication tokens are stored locally in <code>chrome.storage.local</code>.
        </p>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '12px' }}>4. Data Storage</h2>
        <p style={{ color: 'var(--text-secondary)' }}>
          All data is stored on Supabase (hosted on AWS) with Row Level Security (RLS) policies ensuring
          you can only access your own data. PDFs are stored in private storage buckets scoped to your user ID.
          Data is encrypted in transit (TLS) and at rest.
        </p>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '12px' }}>5. Third-Party Services</h2>
        <ul style={{ color: 'var(--text-secondary)', paddingLeft: '24px' }}>
          <li><strong>Supabase</strong> — database, authentication, file storage</li>
          <li><strong>CrossRef API</strong> — paper metadata lookup (only the DOI is sent)</li>
          <li><strong>Semantic Scholar API</strong> — related paper recommendations</li>
          <li><strong>Apple StoreKit</strong> — subscription management (iOS only)</li>
        </ul>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '12px' }}>6. Your Rights</h2>
        <p style={{ color: 'var(--text-secondary)' }}>
          You can export all your data at any time (BibTeX, RIS, CSV). You can delete your account
          and all associated data by contacting us. We will process deletion requests within 30 days.
        </p>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '12px' }}>7. Contact</h2>
        <p style={{ color: 'var(--text-secondary)' }}>
          For privacy questions or data deletion requests, email: <a href="mailto:privacy@scholarsync.app" style={{ color: 'var(--text-accent)' }}>privacy@scholarsync.app</a>
        </p>
      </section>
    </div>
  );
}
