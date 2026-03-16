// ScholarSync Browser Extension — Real Supabase Integration
//
// The anon key is a public key by design — security is enforced by
// Row Level Security (RLS) policies on the Supabase tables, not by
// keeping this key secret. This is the standard pattern per Supabase docs.
const SUPABASE_URL = 'https://qwucidgyppghygjvzlsg.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF3dWNpZGd5cHBnaHlnanZ6bHNnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIyNjAxMjksImV4cCI6MjA4NzgzNjEyOX0.eUedSI9Bcncj5-3qgqjGBBzh8Tx0Mc0WrFiaciwU8ws';

const STORAGE_KEYS = {
    accessToken: 'scholarsync_access_token',
    refreshToken: 'scholarsync_refresh_token',
    userId: 'scholarsync_user_id',
    email: 'scholarsync_email'
};

let paperData = null;
let authState = { accessToken: null, refreshToken: null, userId: null, email: null };

document.addEventListener('DOMContentLoaded', async () => {
    // Load stored auth state
    const stored = await chrome.storage.local.get(Object.values(STORAGE_KEYS));
    if (stored[STORAGE_KEYS.accessToken]) {
        authState = {
            accessToken: stored[STORAGE_KEYS.accessToken],
            refreshToken: stored[STORAGE_KEYS.refreshToken],
            userId: stored[STORAGE_KEYS.userId],
            email: stored[STORAGE_KEYS.email]
        };
        showAuthenticatedUI();
    } else {
        showLoginUI();
    }

    // Bind login form
    document.getElementById('login-form').addEventListener('submit', async (e) => {
        e.preventDefault();
        await handleLogin();
    });

    // Bind save button
    document.getElementById('save-btn').addEventListener('click', async () => {
        await handleSave();
    });

    // Bind logout
    document.getElementById('logout-btn').addEventListener('click', async () => {
        await handleLogout();
    });
});

// --- UI State Management ---

function showLoginUI() {
    document.getElementById('login').style.display = 'block';
    document.getElementById('loading').style.display = 'none';
    document.getElementById('content').style.display = 'none';
    document.getElementById('error').style.display = 'none';
    document.getElementById('user-bar').style.display = 'none';
}

function showAuthenticatedUI() {
    document.getElementById('login').style.display = 'none';
    document.getElementById('user-bar').style.display = 'flex';
    document.getElementById('user-email').textContent = authState.email || 'Signed in';
    document.getElementById('loading').style.display = 'block';

    // Extract paper metadata from current tab
    extractPaperFromTab();
}

function extractPaperFromTab() {
    chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
        if (!tabs[0]?.id) {
            showNoPaper();
            return;
        }

        chrome.tabs.sendMessage(tabs[0].id, { action: "extract_metadata" }, (response) => {
            document.getElementById('loading').style.display = 'none';

            if (chrome.runtime.lastError || !response || !response.success) {
                showNoPaper();
                return;
            }

            const data = response.data;
            const primaryId = data.doi
                ? `DOI: ${data.doi}`
                : (data.arxivId ? `arXiv: ${data.arxivId}` : null);

            if (!primaryId) {
                showNoPaper();
                return;
            }

            paperData = data;
            document.getElementById('content').style.display = 'block';
            document.getElementById('paper-title').textContent = data.title || 'Unknown Title';
            document.getElementById('paper-id').textContent = primaryId;

            if (data.authors && data.authors.length > 0) {
                document.getElementById('paper-authors').textContent = data.authors.join(', ');
                document.getElementById('paper-authors-box').style.display = 'block';
            }
        });
    });
}

function showNoPaper() {
    document.getElementById('loading').style.display = 'none';
    document.getElementById('error').style.display = 'block';
}

// --- Auth ---

async function handleLogin() {
    const email = document.getElementById('email').value.trim();
    const password = document.getElementById('password').value;
    const loginBtn = document.getElementById('login-btn');
    const loginError = document.getElementById('login-error');

    if (!email || !password) return;

    loginBtn.disabled = true;
    loginBtn.textContent = 'Signing in...';
    loginError.style.display = 'none';

    try {
        const response = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
            method: 'POST',
            headers: {
                'apikey': SUPABASE_ANON_KEY,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ email, password })
        });

        if (!response.ok) {
            const errData = await response.json().catch(() => ({}));
            throw new Error(errData.error_description || errData.msg || 'Invalid email or password');
        }

        const data = await response.json();
        authState = {
            accessToken: data.access_token,
            refreshToken: data.refresh_token,
            userId: data.user.id,
            email: data.user.email
        };

        await chrome.storage.local.set({
            [STORAGE_KEYS.accessToken]: data.access_token,
            [STORAGE_KEYS.refreshToken]: data.refresh_token,
            [STORAGE_KEYS.userId]: data.user.id,
            [STORAGE_KEYS.email]: data.user.email
        });

        showAuthenticatedUI();
    } catch (err) {
        loginError.textContent = err.message;
        loginError.style.display = 'block';
        loginBtn.disabled = false;
        loginBtn.textContent = 'Sign In';
    }
}

async function handleLogout() {
    await chrome.storage.local.remove(Object.values(STORAGE_KEYS));
    authState = { accessToken: null, refreshToken: null, userId: null, email: null };
    showLoginUI();
}

// --- Save Paper ---

async function handleSave() {
    if (!paperData) return;

    const saveBtn = document.getElementById('save-btn');
    saveBtn.disabled = true;
    saveBtn.textContent = 'Saving...';

    try {
        const paperPayload = {
            title: paperData.title || 'Unknown Title',
            authors: (paperData.authors && paperData.authors.length > 0)
                ? paperData.authors.join(', ')
                : 'Unknown',
            doi: paperData.doi || null,
            status: 'unread',
            user_id: authState.userId,
            year: new Date().getFullYear()
        };

        const response = await fetch(`${SUPABASE_URL}/rest/v1/papers`, {
            method: 'POST',
            headers: {
                'apikey': SUPABASE_ANON_KEY,
                'Authorization': `Bearer ${authState.accessToken}`,
                'Content-Type': 'application/json',
                'Prefer': 'return=representation'
            },
            body: JSON.stringify(paperPayload)
        });

        if (response.status === 401) {
            // Token expired — try refreshing
            const refreshed = await refreshAccessToken();
            if (refreshed) {
                // Retry save with new token
                saveBtn.textContent = 'Retrying...';
                return handleSave();
            }
            // Refresh failed — need to re-login
            await handleLogout();
            return;
        }

        if (!response.ok) {
            throw new Error(`Save failed (${response.status})`);
        }

        saveBtn.textContent = 'Saved to Queue!';
        saveBtn.style.backgroundColor = '#10b981';

        setTimeout(() => window.close(), 1200);
    } catch (err) {
        console.error('Save error:', err);
        saveBtn.disabled = false;
        saveBtn.textContent = 'Error — Try Again';
        saveBtn.style.backgroundColor = '#ef4444';

        setTimeout(() => {
            saveBtn.style.backgroundColor = '#3b82f6';
            saveBtn.textContent = 'Save to Reading Queue';
        }, 2000);
    }
}

// --- Token Refresh ---

async function refreshAccessToken() {
    if (!authState.refreshToken) return false;

    try {
        const response = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=refresh_token`, {
            method: 'POST',
            headers: {
                'apikey': SUPABASE_ANON_KEY,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ refresh_token: authState.refreshToken })
        });

        if (!response.ok) return false;

        const data = await response.json();
        authState.accessToken = data.access_token;
        authState.refreshToken = data.refresh_token;

        await chrome.storage.local.set({
            [STORAGE_KEYS.accessToken]: data.access_token,
            [STORAGE_KEYS.refreshToken]: data.refresh_token
        });

        return true;
    } catch {
        return false;
    }
}
