// background.js for ScholarSync Safari Extension

chrome.runtime.onInstalled.addListener(() => {
    console.log("ScholarSync Extension Installed");
});

// We could add logic here for context menus (e.g., right click link to save paper).
