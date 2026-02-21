document.addEventListener('DOMContentLoaded', () => {
    const loadingDiv = document.getElementById('loading');
    const contentDiv = document.getElementById('content');
    const errorDiv = document.getElementById('error');

    const titleEl = document.getElementById('paper-title');
    const idEl = document.getElementById('paper-id');
    const saveBtn = document.getElementById('save-btn');

    let paperData = null;

    // Ask content.js for paper metadata
    chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
        chrome.tabs.sendMessage(tabs[0].id, { action: "extract_metadata" }, (response) => {
            loadingDiv.style.display = 'none';

            if (chrome.runtime.lastError || !response || !response.success) {
                // No content script or error
                errorDiv.style.display = 'block';
                return;
            }

            const data = response.data;
            const primaryId = data.doi ? `DOI: ${data.doi}` : (data.arxivId ? `arXiv: ${data.arxivId}` : null);

            if (!primaryId) {
                errorDiv.style.display = 'block';
                return;
            }

            paperData = data;
            contentDiv.style.display = 'block';
            titleEl.textContent = data.title || 'Unknown Title';
            idEl.textContent = primaryId;
        });
    });

    saveBtn.addEventListener('click', async () => {
        if (!paperData) return;

        saveBtn.disabled = true;
        saveBtn.textContent = 'Saving...';

        try {
            // In a real implementation we would:
            // 1. Get user auth token
            // 2. Call Supabase API / Supabase edge function to save to reading queue

            // Mock network request
            await new Promise(resolve => setTimeout(resolve, 800));

            saveBtn.textContent = 'Saved to Queue!';
            saveBtn.style.backgroundColor = '#10b981'; // Success green

            setTimeout(() => {
                window.close();
            }, 1500);

        } catch (error) {
            saveBtn.disabled = false;
            saveBtn.textContent = 'Error Saving (Try Again)';
            saveBtn.style.backgroundColor = '#ef4444'; // Error red
        }
    });
});
