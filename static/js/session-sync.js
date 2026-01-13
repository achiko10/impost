/**
 * Cross-tab session sync
 * Synchronizes login state across multiple browser tabs
 */

// Check for changes in other tabs
window.addEventListener('storage', function(e) {
    if (e.key === 'user_session') {
        if (e.newValue === null) {
            // User logged out in another tab
            window.location.href = '/login/?session_expired=true';
        } else if (!e.oldValue && e.newValue) {
            // User logged in another tab
            // Reload page to update UI
            window.location.href = '/dashboard/';
        }
    }
});

// Notify other tabs when logging in
function notifyLoginToOtherTabs() {
    try {
        localStorage.setItem('user_session', JSON.stringify({
            timestamp: new Date().getTime(),
            user: document.querySelector('[data-user-id]')?.dataset.userId
        }));
    } catch (e) {
        console.log('LocalStorage not available');
    }
}

// Notify other tabs when logging out
function notifyLogoutToOtherTabs() {
    try {
        localStorage.removeItem('user_session');
    } catch (e) {
        console.log('LocalStorage not available');
    }
}

// Call on page load if authenticated
document.addEventListener('DOMContentLoaded', function() {
    if (document.querySelector('[data-user-id]')) {
        notifyLoginToOtherTabs();
    }
});
