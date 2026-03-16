// background.js — ScholarSync Safari/Chrome Extension

chrome.runtime.onInstalled.addListener(() => {
    console.log("ScholarSync Extension installed");
});

// Context menu: right-click a link to save it as a paper
chrome.runtime.onInstalled.addListener(() => {
    chrome.contextMenus.create({
        id: "save-paper-link",
        title: "Save to ScholarSync",
        contexts: ["link"],
        documentUrlPatterns: [
            "*://*.arxiv.org/*",
            "*://*.nature.com/*",
            "*://*.jstor.org/*",
            "*://*.sciencedirect.com/*",
            "*://*.doi.org/*",
            "*://*.ieee.org/*"
        ]
    });
});

chrome.contextMenus.onClicked.addListener(async (info) => {
    if (info.menuItemId !== "save-paper-link") return;

    const linkUrl = info.linkUrl;
    if (!linkUrl) return;

    // Try to extract a DOI from the link URL
    const doiMatch = linkUrl.match(/10\.\d{4,9}\/[^\s]+/);
    if (!doiMatch) return;

    const doi = decodeURIComponent(doiMatch[0]);

    // Check if user is authenticated
    const stored = await chrome.storage.local.get([
        'scholarsync_access_token',
        'scholarsync_user_id'
    ]);

    if (!stored.scholarsync_access_token) {
        // Open popup so user can sign in
        chrome.action.openPopup();
        return;
    }

    // Save paper with just the DOI — title/authors can be fetched later
    try {
        const response = await fetch(
            'https://qwucidgyppghygjvzlsg.supabase.co/rest/v1/papers',
            {
                method: 'POST',
                headers: {
                    'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF3dWNpZGd5cHBnaHlnanZ6bHNnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIyNjAxMjksImV4cCI6MjA4NzgzNjEyOX0.eUedSI9Bcncj5-3qgqjGBBzh8Tx0Mc0WrFiaciwU8ws',
                    'Authorization': `Bearer ${stored.scholarsync_access_token}`,
                    'Content-Type': 'application/json',
                    'Prefer': 'return=representation'
                },
                body: JSON.stringify({
                    title: `Paper (${doi})`,
                    authors: 'Unknown',
                    doi: doi,
                    status: 'unread',
                    user_id: stored.scholarsync_user_id,
                    year: new Date().getFullYear()
                })
            }
        );

        if (response.ok) {
            console.log('Paper saved via context menu:', doi);
        }
    } catch (err) {
        console.error('Context menu save failed:', err);
    }
});
