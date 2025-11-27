// SAARTHI Admin Panel - JavaScript

// Auto-refresh dashboard every 30 seconds
setInterval(function() {
    if (window.location.pathname.includes('index.php')) {
        location.reload();
    }
}, 30000);

// Real-time updates for live data
document.addEventListener('DOMContentLoaded', function() {
    // Add any initialization code here
    console.log('SAARTHI Admin Panel loaded');
});
