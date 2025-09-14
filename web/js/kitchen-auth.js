/**
 * Kitchen Partner Authentication System
 * Replaces static access codes with secure JWT-based authentication
 */

// Firebase configuration for kitchen dashboard
const firebaseConfig = {
  apiKey: "AIzaSyCFeughLAfJ3THhLWVnxLqvvf2mjomkGxg",
  authDomain: "freshpunk-48db1.firebaseapp.com",
  projectId: "freshpunk-48db1",
  storageBucket: "freshpunk-48db1.firebasestorage.app",
  messagingSenderId: "433852717304",
  appId: "1:433852717304:web:318fdb802f7ff7f7c0c30d"
};

// Initialize Firebase
firebase.initializeApp(firebaseConfig);
const auth = firebase.auth();
const functions = firebase.functions('us-east4');

class KitchenAuth {
  constructor() {
    this.currentUser = null;
    this.kitchenData = null;
    this.authStateListener = null;
  }

  // Initialize authentication state
  init() {
    this.authStateListener = auth.onAuthStateChanged(async (user) => {
      if (user) {
        await this.verifyKitchenAccess(user);
      } else {
        this.handleSignOut();
      }
    });
  }

  // Sign in with kitchen partner credentials
  async signInWithKitchenCode(accessCode, partnerName, partnerEmail) {
    try {
      // Show loading
      this.showMessage('Verifying credentials...', 'info');

      // First, sign in anonymously to get auth context
      const userCredential = await auth.signInAnonymously();
      const user = userCredential.user;

      // Then call our Cloud Function to grant kitchen access
      const grantKitchenAccess = functions.httpsCallable('grantKitchenAccess');
      const result = await grantKitchenAccess({
        accessCode: accessCode,
        partnerName: partnerName,
        partnerEmail: partnerEmail
      });

      if (result.data.ok) {
        // Force token refresh to get new claims
        await user.getIdToken(true);
        
        this.showMessage('Access granted! Loading kitchen dashboard...', 'success');
        setTimeout(() => this.showDashboard(result.data.kitchen), 1000);
      }
    } catch (error) {
      console.error('Kitchen sign-in error:', error);
      let errorMessage = 'Authentication failed. Please check your credentials.';
      
      if (error.code === 'functions/permission-denied') {
        errorMessage = 'Invalid access code. Please contact support.';
      } else if (error.code === 'functions/resource-exhausted') {
        errorMessage = 'Too many attempts. Please wait before trying again.';
      }
      
      this.showMessage(errorMessage, 'error');
    }
  }

  // Verify user has kitchen access
  async verifyKitchenAccess(user) {
    try {
      const token = await user.getIdTokenResult();
      const claims = token.claims;

      if (claims.kitchen === true && claims.kitchenId) {
        this.currentUser = user;
        this.kitchenData = {
          id: claims.kitchenId,
          name: claims.kitchenName,
          partnerName: claims.partnerName,
          partnerEmail: claims.partnerEmail
        };
        
        this.showDashboard(this.kitchenData);
      } else {
        // User is signed in but doesn't have kitchen access
        this.showLoginForm();
      }
    } catch (error) {
      console.error('Error verifying kitchen access:', error);
      this.showLoginForm();
    }
  }

  // Sign out
  async signOut() {
    try {
      await auth.signOut();
    } catch (error) {
      console.error('Sign out error:', error);
    }
  }

  // Handle sign out
  handleSignOut() {
    this.currentUser = null;
    this.kitchenData = null;
    this.showLoginForm();
  }

  // Show login form
  showLoginForm() {
    const authContainer = document.getElementById('auth-container');
    const dashboardContainer = document.getElementById('dashboard-container');
    
    if (authContainer) authContainer.style.display = 'block';
    if (dashboardContainer) dashboardContainer.style.display = 'none';
  }

  // Show dashboard
  showDashboard(kitchenData) {
    const authContainer = document.getElementById('auth-container');
    const dashboardContainer = document.getElementById('dashboard-container');
    
    if (authContainer) authContainer.style.display = 'none';
    if (dashboardContainer) {
      dashboardContainer.style.display = 'block';
      this.updateDashboardHeader(kitchenData);
      this.loadKitchenData();
    }
  }

  // Update dashboard header with kitchen info
  updateDashboardHeader(kitchenData) {
    const kitchenNameEl = document.getElementById('kitchen-name');
    const partnerNameEl = document.getElementById('partner-name');
    
    if (kitchenNameEl) kitchenNameEl.textContent = kitchenData.name;
    if (partnerNameEl) partnerNameEl.textContent = `Welcome, ${kitchenData.partnerName}`;
  }

  // Load kitchen-specific data
  async loadKitchenData() {
    try {
      // Load orders for this kitchen
      await this.loadKitchenOrders();
    } catch (error) {
      console.error('Error loading kitchen data:', error);
      this.showMessage('Error loading kitchen data', 'error');
    }
  }

  // Load orders for the kitchen
  async loadKitchenOrders() {
    if (!this.currentUser || !this.kitchenData) return;

    try {
      const token = await this.currentUser.getIdToken();
      
      // Call our Cloud Function to get kitchen orders
      const getKitchenOrders = functions.httpsCallable('getKitchenOrders');
      const result = await getKitchenOrders({
        kitchenId: this.kitchenData.id
      });

      if (result.data.orders) {
        this.displayOrders(result.data.orders);
      }
    } catch (error) {
      console.error('Error loading kitchen orders:', error);
      this.showMessage('Error loading orders', 'error');
    }
  }

  // Display orders in the dashboard
  displayOrders(orders) {
    const ordersContainer = document.getElementById('orders-container');
    if (!ordersContainer) return;

    if (orders.length === 0) {
      ordersContainer.innerHTML = '<p class="no-orders">No orders found</p>';
      return;
    }

    const ordersHTML = orders.map(order => `
      <div class="order-card" data-order-id="${order.id}">
        <div class="order-header">
          <span class="order-id">#${order.id.substring(0, 8)}</span>
          <span class="order-status status-${order.status}">${order.status}</span>
        </div>
        <div class="order-details">
          <p><strong>Customer:</strong> ${order.customerName || 'N/A'}</p>
          <p><strong>Delivery Address:</strong> ${order.deliveryAddress}</p>
          <p><strong>Order Date:</strong> ${new Date(order.orderDate).toLocaleDateString()}</p>
          <p><strong>Items:</strong> ${order.meals?.length || 0} meals</p>
        </div>
        <div class="order-actions">
          <button onclick="kitchenAuth.updateOrderStatus('${order.id}', 'preparing')" 
                  ${order.status === 'preparing' ? 'disabled' : ''}>
            Mark Preparing
          </button>
          <button onclick="kitchenAuth.updateOrderStatus('${order.id}', 'ready')"
                  ${order.status === 'ready' ? 'disabled' : ''}>
            Mark Ready
          </button>
          <button onclick="kitchenAuth.updateOrderStatus('${order.id}', 'out_for_delivery')"
                  ${order.status === 'out_for_delivery' ? 'disabled' : ''}>
            Out for Delivery
          </button>
        </div>
      </div>
    `).join('');

    ordersContainer.innerHTML = ordersHTML;
  }

  // Update order status
  async updateOrderStatus(orderId, newStatus) {
    if (!this.currentUser) return;

    try {
      this.showMessage('Updating order status...', 'info');

      const updateOrderStatus = functions.httpsCallable('updateOrderStatus');
      const result = await updateOrderStatus({
        orderId: orderId,
        status: newStatus
      });

      if (result.data.ok) {
        this.showMessage('Order status updated successfully', 'success');
        // Reload orders to reflect changes
        await this.loadKitchenOrders();
      }
    } catch (error) {
      console.error('Error updating order status:', error);
      this.showMessage('Failed to update order status', 'error');
    }
  }

  // Show message to user
  showMessage(message, type = 'info') {
    // Remove existing messages
    const existingMessage = document.querySelector('.message-toast');
    if (existingMessage) {
      existingMessage.remove();
    }

    // Create new message
    const messageEl = document.createElement('div');
    messageEl.className = `message-toast message-${type}`;
    messageEl.textContent = message;

    document.body.appendChild(messageEl);

    // Auto-remove after 5 seconds
    setTimeout(() => {
      if (messageEl.parentNode) {
        messageEl.remove();
      }
    }, 5000);
  }

  // Cleanup
  destroy() {
    if (this.authStateListener) {
      this.authStateListener();
      this.authStateListener = null;
    }
  }
}

// Initialize kitchen authentication
const kitchenAuth = new KitchenAuth();

// Handle form submission
function handleKitchenLogin(event) {
  event.preventDefault();
  
  const accessCode = document.getElementById('access-code').value.trim();
  const partnerName = document.getElementById('partner-name-input').value.trim();
  const partnerEmail = document.getElementById('partner-email-input').value.trim();

  if (!accessCode || !partnerName || !partnerEmail) {
    kitchenAuth.showMessage('Please fill in all fields', 'error');
    return;
  }

  if (!isValidEmail(partnerEmail)) {
    kitchenAuth.showMessage('Please enter a valid email address', 'error');
    return;
  }

  kitchenAuth.signInWithKitchenCode(accessCode, partnerName, partnerEmail);
}

function isValidEmail(email) {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

// Initialize when page loads
document.addEventListener('DOMContentLoaded', () => {
  kitchenAuth.init();
});

// Cleanup when page unloads
window.addEventListener('beforeunload', () => {
  kitchenAuth.destroy();
});
