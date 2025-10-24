# Known Bugs & Issues

## 🔴 High Priority

### 1. Desktop Account Deletion Hangs
- **Issue:** `reauthenticateWithCredential()` hangs indefinitely on Windows desktop
- **Cause:** Firebase Auth SDK networking limitation on desktop platforms
- **Workaround:** Use web version at https://freshpunk-48db1.web.app for account deletion
- **Status:** 10-second timeout implemented with helpful error message
- **File:** `lib/app_v3/pages/settings_page_v3.dart`

### 2. Large Meal Images Slow Initial Load
- **Issue:** High-resolution meal images cause slow first load and memory spikes
- **Impact:** Poor UX on low-end devices or slow networks
- **Mitigation:** Tree-shaking implemented, but needs lazy loading or image optimization
- **Next Step:** Implement `CachedNetworkImage` with progressive loading

---

## 🟡 Medium Priority

### 3. Admin Seed Functions Hidden
- **Issue:** Admin meal seeding UI is commented out in production
- **Impact:** Can't easily populate test data or new meals
- **Location:** Admin panel or CLI scripts
- **Next Step:** Expose in admin dashboard or create Firebase Function

### 4. Cloud Functions Cold Start Latency
- **Issue:** First Stripe API call takes 3-5 seconds after idle period
- **Cause:** Cloud Functions v2 cold starts
- **Mitigation:** Consider min-instances for critical functions
- **Cost Impact:** Min-instances = ~$6/month per function

---

## 🟢 Low Priority

### 5. No Unit Test Coverage
- **Issue:** Zero automated tests (unit, widget, integration)
- **Impact:** Manual testing required for all changes
- **Risk:** Regression bugs
- **Next Step:** Start with critical path tests (auth, checkout, orders)

### 6. 362 Linter Warnings
- **Issue:** Code analysis shows 362 warnings (prefer_const, unused imports, etc.)
- **Impact:** None - all non-blocking
- **Next Step:** Clean up gradually during refactoring

---

## 🐛 Bug Tracking

**Where to report new bugs:**
- Create GitHub Issues: https://github.com/leonovd-bit/flutter_application_1/issues
- Use labels: `bug`, `enhancement`, `high-priority`, `low-priority`

**Testing checklist before deployment:**
- [ ] Auth flow (sign up, sign in, password reset, sign out)
- [ ] Account deletion (use web version)
- [ ] Meal browsing and filtering
- [ ] Cart add/remove
- [ ] Checkout flow
- [ ] Stripe payment (test mode)
- [ ] Order placement
- [ ] Order history
- [ ] Admin functions (if exposed)

---

# Test Data

## 📊 Sample Meals (from TEST_DATA.json)

```json
{
  "id": "meal_001",
  "name": "Chicken Caesar Salad",
  "description": "Grilled chicken breast over crisp romaine lettuce with parmesan cheese and caesar dressing",
  "category": "salads",
  "price": 12.99,
  "nutrition": {
    "calories": 420,
    "protein": 32,
    "carbs": 18,
    "fat": 24,
    "fiber": 4
  },
  "allergens": ["dairy", "eggs"],
  "dietary": ["high-protein", "gluten-free-option"]
}
```

**5 meals available:**
1. Chicken Caesar Salad - 420 cal, $12.99
2. Grilled Salmon with Asparagus - 520 cal, $16.99
3. Vegan Buddha Bowl - 385 cal, $11.99
4. Turkey Meatballs Marinara - 340 cal, $13.99
5. Greek Yogurt Parfait - 285 cal, $8.99

---

## 💳 Meal Plans

| Plan | Price | Meals/Day | Calories | Status |
|------|-------|-----------|----------|--------|
| **NutritiousJr** | $199.99/mo | 2 | 1,500-1,800 | Active |
| **Diet Knight** | $299.99/mo | 3 | 2,000-2,500 | Most Popular |
| **Lean Freak** | $449.99/mo | 4 | 2,500-3,000 | Premium |

**Stripe Price IDs:**
- NutritiousJr: `price_nutritious_jr_monthly`
- Diet Knight: `price_diet_knight_monthly`
- Lean Freak: `price_lean_freak_monthly`

---

## 👥 Test Accounts

### Admin Account
```
Email: admin@freshpunk.com
Password: [YOU NEED TO PROVIDE]
Firebase UID: zXY2a1OsecVQmg3ghiyJBGSfuOM2
Role: admin
Permissions: Full access to admin panel, meal management, user management
```

### Regular User
```
Email: test@example.com
Password: [YOU NEED TO PROVIDE]
Role: user
Has: Active subscription (Diet Knight), order history, saved addresses
```

### Restaurant Account
```
Email: restaurant@freshpunk.com
Password: [YOU NEED TO PROVIDE]
Role: restaurant
Permissions: View orders, update order status, manage restaurant profile
```

---

## 🧪 Test Scenarios

### 1. New User Sign-Up Flow
```
1. Go to /signup
2. Enter: newtestuser@example.com / TestPass123!
3. Verify email sent (check Firebase Console)
4. Complete profile setup
5. Browse meals → Add to cart → Checkout
6. Use Stripe test card: 4242 4242 4242 4242, any future date, any CVC
7. Verify order appears in Firestore and user receives confirmation
```

### 2. Subscription Purchase
```
1. Sign in as test@example.com
2. Go to /meal-plans
3. Select "Diet Knight" plan
4. Use Stripe test card: 4242 4242 4242 4242
5. Verify subscription active in Stripe Dashboard
6. Check Firestore: users/{uid}/subscriptions collection
7. Verify webhook fired and subscription document updated
```

### 3. Account Deletion (Web Only)
```
1. Go to https://freshpunk-48db1.web.app/settings
2. Scroll to "Delete Account" section
3. Click "Delete Account" button
4. Enter password in dialog
5. Confirm deletion
6. Verify user removed from Firebase Auth
7. Verify user data anonymized/deleted in Firestore
```

---

## 🔐 Stripe Test Cards

**Success:**
- `4242 4242 4242 4242` - Visa (always succeeds)
- `5555 5555 5555 4444` - Mastercard (always succeeds)

**Failure:**
- `4000 0000 0000 0002` - Card declined
- `4000 0000 0000 9995` - Insufficient funds

**3D Secure (requires authentication):**
- `4000 0025 0000 3155` - 3D Secure required

**More:** https://stripe.com/docs/testing#cards

---

## 📁 Where to Find More Test Data

1. **Firestore Collections** (Firebase Console):
   - `users` - User profiles and settings
   - `meals` - Available meals with nutrition
   - `orders` - Order history
   - `subscriptions` - Active subscriptions
   - `mealPlans` - Available subscription plans

2. **TEST_DATA.json** (in repo root):
   - Complete sample data structures
   - Copy/paste for seeding new environments

3. **Stripe Dashboard** (Test Mode):
   - Products and prices
   - Test customers
   - Subscription plans
   - Webhook events

---

## 🚀 How to Seed Test Data

### Option 1: Use Admin Panel (if exposed)
```dart
// Navigate to admin panel and use seed functions
// Currently commented out - needs to be re-enabled
```

### Option 2: Firebase Console Manual Entry
```
1. Go to Firestore in Firebase Console
2. Navigate to `meals` collection
3. Add documents using TEST_DATA.json structure
4. Repeat for `mealPlans` collection
```

### Option 3: Run Seed Script (TODO)
```bash
# Future improvement - create seed script
dart run tools/seed_data.dart
```

---

## 📞 Questions?

- Check `HANDOFF_PACKAGE.md` for detailed docs
- Create GitHub issue for bugs
- Review `TEST_DATA.json` for complete sample data structures
