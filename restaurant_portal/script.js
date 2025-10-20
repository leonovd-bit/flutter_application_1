// Restaurant Portal JavaScript

// Firebase Configuration
const firebaseConfig = {
    apiKey: "AIzaSyBUYB1VJDT6pZKgAQKnk6fVacMqhzm4_ck",
    authDomain: "freshpunk-48db1.firebaseapp.com",
    projectId: "freshpunk-48db1",
    storageBucket: "freshpunk-48db1.appspot.com",
    messagingSenderId: "433852717304",
    appId: "1:433852717304:web:0e90d9b6d1a0a2c8c1f8e3"
};

// Initialize Firebase
firebase.initializeApp(firebaseConfig);

// Global State
let currentStep = 1;
let restaurantData = {};
let isConnected = false;

// Initialize App
document.addEventListener('DOMContentLoaded', function() {
    // Hide loading screen after 2 seconds
    setTimeout(() => {
        const loadingScreen = document.getElementById('loading-screen');
        loadingScreen.style.opacity = '0';
        setTimeout(() => {
            loadingScreen.style.display = 'none';
        }, 500);
    }, 2000);

    // Initialize navigation
    setupNavigation();
    
    // Show home section by default
    showSection('home');
});

// Navigation Functions
function setupNavigation() {
    const navLinks = document.querySelectorAll('.nav-link');
    navLinks.forEach(link => {
        link.addEventListener('click', (e) => {
            e.preventDefault();
            const sectionId = link.getAttribute('href').substring(1);
            showSection(sectionId);
            
            // Update active nav link
            navLinks.forEach(nl => nl.classList.remove('active'));
            link.classList.add('active');
        });
    });
}

function showSection(sectionId) {
    // Hide all sections
    const sections = document.querySelectorAll('.section');
    sections.forEach(section => section.classList.remove('active'));
    
    // Show target section
    const targetSection = document.getElementById(sectionId);
    if (targetSection) {
        targetSection.classList.add('active');
    }

    // Update navigation active state
    const navLinks = document.querySelectorAll('.nav-link');
    navLinks.forEach(link => {
        link.classList.remove('active');
        if (link.getAttribute('href') === `#${sectionId}`) {
            link.classList.add('active');
        }
    });
}

// Onboarding Steps
function nextStep(step) {
    if (step === 2 && !validateRestaurantForm()) {
        return;
    }

    currentStep = step;
    updateStepIndicator(step);
    showOnboardingStep(step);

    if (step === 3) {
        // Simulate menu sync
        simulateMenuSync();
    }
}

function prevStep(step) {
    currentStep = step;
    updateStepIndicator(step);
    showOnboardingStep(step);
}

function updateStepIndicator(activeStep) {
    const steps = document.querySelectorAll('.step');
    steps.forEach((step, index) => {
        const stepNumber = index + 1;
        if (stepNumber <= activeStep) {
            step.classList.add('active');
        } else {
            step.classList.remove('active');
        }
    });
}

function showOnboardingStep(step) {
    const steps = document.querySelectorAll('.onboard-step');
    steps.forEach(stepElement => stepElement.classList.remove('active'));
    
    const targetStep = document.getElementById(`step-${step}`);
    if (targetStep) {
        targetStep.classList.add('active');
    }
}

function validateRestaurantForm() {
    const form = document.getElementById('restaurant-form');
    const requiredFields = form.querySelectorAll('[required]');
    
    let isValid = true;
    requiredFields.forEach(field => {
        if (!field.value.trim()) {
            field.style.borderColor = 'var(--error-color)';
            isValid = false;
        } else {
            field.style.borderColor = 'var(--border-color)';
        }
    });

    if (isValid) {
        // Store restaurant data
        restaurantData = {
            name: document.getElementById('restaurant-name').value.trim(),
            email: document.getElementById('contact-email').value.trim(),
            phone: document.getElementById('contact-phone').value.trim(),
            address: document.getElementById('restaurant-address').value.trim(),
            cuisineType: document.getElementById('cuisine-type').value
        };
    } else {
        showNotification('Please fill in all required fields.', 'error');
    }

    return isValid;
}

// Square Integration
async function connectSquare() {
    if (!restaurantData.name) {
        showNotification('Please complete restaurant information first.', 'error');
        return;
    }

    try {
        // Show loading state
        const button = document.querySelector('.connect-square-button');
        const originalText = button.innerHTML;
        button.innerHTML = '<div class="spinner"></div> Connecting...';
        button.disabled = true;

        // Call Firebase function to initiate Square OAuth using HTTP request
        const response = await fetch('https://us-central1-freshpunk-48db1.cloudfunctions.net/initiateSquareOAuthHttp', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                restaurantName: restaurantData.name,
                contactEmail: restaurantData.email,
                contactPhone: restaurantData.phone || null
            })
        });

        const data = await response.json();
        if (data.success) {
            // Store application ID for later use
            restaurantData.applicationId = data.applicationId;
            
            // Open Square OAuth page
            const authWindow = window.open(data.oauthUrl, 'square-auth', 'width=600,height=700,scrollbars=yes,resizable=yes');
            
            // Monitor auth window
            const authInterval = setInterval(() => {
                if (authWindow.closed) {
                    clearInterval(authInterval);
                    // Simulate successful connection for demo
                    setTimeout(() => {
                        isConnected = true;
                        nextStep(3);
                    }, 1000);
                }
            }, 1000);

            showNotification('Square authorization window opened. Please complete the authorization.', 'success');
        } else {
            throw new Error(data.message || 'Failed to initiate Square connection');
        }
    } catch (error) {
        console.error('Square connection error:', error);
        showNotification('Failed to connect with Square. Please try again.', 'error');
    } finally {
        // Reset button
        const button = document.querySelector('.connect-square-button');
        button.innerHTML = '<i class="fab fa-square"></i> Connect with Square';
        button.disabled = false;
    }
}

function simulateMenuSync() {
    const syncStatus = document.getElementById('menu-sync-status');
    const menuPreview = document.getElementById('menu-preview');
    
    // Show syncing state
    syncStatus.style.display = 'block';
    menuPreview.style.display = 'none';

    // Simulate sync completion after 3 seconds
    setTimeout(() => {
        syncStatus.style.display = 'none';
        
        // Show menu items
        const menuItems = document.getElementById('menu-items');
        menuItems.innerHTML = `
            <div class="menu-item">
                <div class="menu-item-name">Quinoa Power Bowl</div>
                <div class="menu-item-price">$12.99</div>
            </div>
            <div class="menu-item">
                <div class="menu-item-name">Mediterranean Salad</div>
                <div class="menu-item-price">$10.99</div>
            </div>
            <div class="menu-item">
                <div class="menu-item-name">Green Goddess Smoothie</div>
                <div class="menu-item-price">$7.99</div>
            </div>
            <div class="menu-item">
                <div class="menu-item-name">Protein-Packed Wrap</div>
                <div class="menu-item-price">$9.99</div>
            </div>
        `;
        
        menuPreview.style.display = 'block';
    }, 3000);
}

// Dashboard Functions
function showDashboard() {
    showSection('dashboard');
    
    // Show dashboard link in navigation
    const dashboardLink = document.getElementById('dashboard-link');
    dashboardLink.style.display = 'block';
}

async function syncMenu() {
    try {
        showNotification('Syncing menu with Square...', 'info');
        
        // Call sync function
        const syncSquareMenu = firebase.functions().httpsCallable('syncSquareMenu');
        const result = await syncSquareMenu({
            restaurantId: restaurantData.applicationId
        });

        if (result.data.success) {
            showNotification('Menu synced successfully!', 'success');
        } else {
            throw new Error(result.data.message || 'Sync failed');
        }
    } catch (error) {
        console.error('Menu sync error:', error);
        showNotification('Failed to sync menu. Please try again.', 'error');
    }
}

async function viewOrders() {
    try {
        const getRestaurantOrders = firebase.functions().httpsCallable('getRestaurantOrders');
        const result = await getRestaurantOrders({
            restaurantId: restaurantData.applicationId,
            limit: 20
        });

        if (result.data.success) {
            displayOrders(result.data.notifications);
        } else {
            throw new Error(result.data.message || 'Failed to fetch orders');
        }
    } catch (error) {
        console.error('Orders fetch error:', error);
        showNotification('Failed to fetch orders. Please try again.', 'error');
    }
}

function displayOrders(orders) {
    if (orders.length === 0) {
        showNotification('No orders found.', 'info');
        return;
    }

    // Create modal or navigate to orders page
    const ordersList = orders.map(order => `
        <div class="order-summary">
            <div class="order-customer">${order.customerName}</div>
            <div class="order-items">${order.meals.map(m => m.name).join(', ')}</div>
            <div class="order-time">${new Date(order.deliveryDate).toLocaleString()}</div>
            <div class="order-total">$${order.totalAmount.toFixed(2)}</div>
        </div>
    `).join('');

    // Show orders in a simple alert for demo (in production, use a modal)
    alert(`Recent Orders:\n\n${orders.map(o => `${o.customerName}: ${o.meals.length} items - $${o.totalAmount.toFixed(2)}`).join('\n')}`);
}

function disconnect() {
    if (confirm('Are you sure you want to disconnect your restaurant from FreshPunk?')) {
        // Reset state
        isConnected = false;
        currentStep = 1;
        restaurantData = {};
        
        // Hide dashboard link
        const dashboardLink = document.getElementById('dashboard-link');
        dashboardLink.style.display = 'none';
        
        // Go back to home
        showSection('home');
        
        showNotification('Your restaurant has been disconnected.', 'info');
    }
}

// Utility Functions
function showNotification(message, type = 'info') {
    // Create notification element
    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    notification.innerHTML = `
        <div class="notification-content">
            <span>${message}</span>
            <button class="notification-close" onclick="this.parentElement.parentElement.remove()">×</button>
        </div>
    `;

    // Add to page
    document.body.appendChild(notification);

    // Auto remove after 5 seconds
    setTimeout(() => {
        if (notification.parentElement) {
            notification.remove();
        }
    }, 5000);
}

// Add notification styles
const notificationStyles = `
    .notification {
        position: fixed;
        top: 100px;
        right: 20px;
        max-width: 400px;
        padding: 1rem;
        border-radius: var(--border-radius);
        box-shadow: var(--shadow-lg);
        z-index: 1000;
        animation: slideIn 0.3s ease-out;
    }

    .notification-info {
        background: #E6FFFA;
        border-left: 4px solid #38B2AC;
        color: #234E52;
    }

    .notification-success {
        background: #F0FFF4;
        border-left: 4px solid #48BB78;
        color: #22543D;
    }

    .notification-error {
        background: #FED7D7;
        border-left: 4px solid #F56565;
        color: #742A2A;
    }

    .notification-content {
        display: flex;
        justify-content: space-between;
        align-items: center;
    }

    .notification-close {
        background: none;
        border: none;
        font-size: 1.25rem;
        cursor: pointer;
        color: inherit;
        opacity: 0.7;
    }

    .notification-close:hover {
        opacity: 1;
    }

    @keyframes slideIn {
        from {
            transform: translateX(100%);
            opacity: 0;
        }
        to {
            transform: translateX(0);
            opacity: 1;
        }
    }

    .menu-item {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 0.75rem;
        background: var(--background-light);
        border-radius: 8px;
        margin-bottom: 0.5rem;
    }

    .menu-item-name {
        font-weight: 500;
    }

    .menu-item-price {
        font-weight: 600;
        color: var(--secondary-color);
    }
`;

// Add styles to head
const styleSheet = document.createElement('style');
styleSheet.textContent = notificationStyles;
document.head.appendChild(styleSheet);

// Export functions for global access
window.showSection = showSection;
window.nextStep = nextStep;
window.prevStep = prevStep;
window.connectSquare = connectSquare;
window.showDashboard = showDashboard;
window.syncMenu = syncMenu;
window.viewOrders = viewOrders;
window.disconnect = disconnect;