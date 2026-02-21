// content.js - Injected into scholarly sites to extract IDs

function extractPaperIdentifiers() {
    const identifiers = {
        doi: null,
        arxivId: null,
        title: null,
        authors: []
    };

    // 1. Try to find standard citation meta tags
    const doiMeta = document.querySelector('meta[name="citation_doi"]') ||
        document.querySelector('meta[name="dc.identifier"][content^="10."]') ||
        document.querySelector('meta[name="DOI"]');
    if (doiMeta) {
        identifiers.doi = doiMeta.getAttribute('content');
    }

    // 2. Try to find arXiv ID from meta tags or URL
    const arxivMeta = document.querySelector('meta[name="citation_arxiv_id"]');
    if (arxivMeta) {
        identifiers.arxivId = arxivMeta.getAttribute('content');
    } else if (window.location.hostname.includes('arxiv.org')) {
        // Extract from URL (e.g., https://arxiv.org/abs/2103.11111)
        const match = window.location.pathname.match(/\/abs\/([^/]+)/);
        if (match) {
            identifiers.arxivId = match[1];
        }
    }

    // 3. Extract Title
    const titleMeta = document.querySelector('meta[name="citation_title"]');
    if (titleMeta) {
        identifiers.title = titleMeta.getAttribute('content');
    } else {
        identifiers.title = document.title;
    }

    // 4. Extract Authors
    const authorMetas = document.querySelectorAll('meta[name="citation_author"]');
    authorMetas.forEach(meta => {
        identifiers.authors.push(meta.getAttribute('content'));
    });

    return identifiers;
}

// Send the extracted metadata to the popup or background script
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
    if (request.action === 'extract_metadata') {
        const data = extractPaperIdentifiers();
        sendResponse({ success: true, data: data });
    }
});
