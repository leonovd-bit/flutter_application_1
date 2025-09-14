# 📝 Update Twilio Phone Number

## 🔧 **Manual Update Required:**

Once you get your Twilio phone number, you need to update it in the code:

### **File:** `functions/src/index.ts`

### **Find and replace these lines:**

**Line ~1760:**
```typescript
'From': '+18336470630', // Replace with your Twilio number
```

**Line ~1921:**
```typescript  
'From': '+18336470630', // Replace with your Twilio number
```

### **Replace with your actual number:**
```typescript
'From': '+1XXXXXXXXXX', // Your actual Twilio phone number
```

---

## ✅ **After updating, deploy functions:**

```bash
firebase deploy --only functions
```

**Then test SMS functionality!** 🚀
