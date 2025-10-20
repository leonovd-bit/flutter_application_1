# Restaurant Partner Portal

A dedicated web portal for restaurants to onboard and manage their FreshPunk partnership.

## Features

### 🏠 Professional Landing Page
- Hero section with compelling value proposition
- Key statistics and benefits
- Seamless navigation

### 📋 Step-by-Step Onboarding
1. **Restaurant Information** - Basic details and contact info
2. **Square Integration** - OAuth connection with Square POS
3. **Menu Synchronization** - Automatic sync of menu items
4. **Go Live** - Ready to receive orders

### 📊 Restaurant Dashboard
- Order statistics and revenue tracking
- Menu management and sync controls
- Connection status monitoring
- Easy disconnect option

### 🎨 Professional Design
- Modern, responsive design
- Smooth animations and transitions
- Mobile-friendly interface
- Professional branding

## Technical Implementation

### Frontend
- **Pure HTML/CSS/JavaScript** - No framework dependencies
- **Responsive Design** - Works on all devices
- **Firebase Integration** - Direct connection to Cloud Functions
- **Real-time Updates** - Live order and menu sync

### Backend Integration
- **Square OAuth Flow** - Secure restaurant authentication
- **Firebase Cloud Functions** - All backend processing
- **Menu Synchronization** - Real-time Square menu sync
- **Order Management** - Seamless order forwarding

## File Structure

```
restaurant_portal/
├── index.html          # Main portal page
├── styles.css          # Professional styling
├── script.js           # JavaScript functionality
└── README.md          # This file
```

## Usage

1. **Deploy to Firebase Hosting** or any web server
2. **Configure Firebase** with your project credentials
3. **Set up Square API** credentials in Cloud Functions
4. **Share portal link** with restaurant partners

## Onboarding Flow

### For Restaurants:
1. Visit the portal URL
2. Fill out restaurant information
3. Connect Square POS account (OAuth)
4. Review synchronized menu items
5. Go live and start receiving orders

### For You:
1. Restaurant completes onboarding
2. Orders automatically appear in their Square POS
3. They manage orders through their existing Square workflow
4. You receive your commission automatically

## Benefits of Separate Portal

✅ **Professional Branding** - Dedicated restaurant experience
✅ **Clean Separation** - Customer app stays focused on customers
✅ **Better SEO** - Restaurant-specific landing page
✅ **Scalability** - Easy to customize for restaurant needs
✅ **Trust Building** - Professional onboarding process

## Next Steps

1. Deploy this portal to your hosting platform
2. Configure Firebase and Square API credentials
3. Test the complete onboarding flow
4. Share with restaurant partners

The portal is production-ready and integrates with all the Square Cloud Functions we built!