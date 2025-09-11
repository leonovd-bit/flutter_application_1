// Load environment variables
require('dotenv').config();

// Import required packages
const express = require('express');
const OpenAI = require('openai');
const cors = require('cors');

const MealOptimizer = require('./mealOptimizer');
// Create Express app
const app = express();
const port = process.env.PORT || 3000;

// Initialize OpenAI
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static('public')); // Serve static files

// In-memory storage (replace with database later)
const userProfiles = {};
const conversations = {};
const userCarts = {};

// Mock food database
const mockFoods = [
  {
    id: 'f1',
    name: 'Quinoa Power Bowl',
    restaurant: 'GreenEats',
    description: 'Quinoa, roasted vegetables, chickpeas, tahini dressing',
    calories: 450,
    protein: 18,
    carbs: 65,
    fat: 12,
    fiber: 8,
    price: 14.99,
    dietary: ['vegetarian', 'vegan', 'gluten_free'],
    allergens: ['sesame'],
    mealType: ['lunch', 'dinner']
  },
  {
    id: 'f2',
    name: 'Grilled Chicken & Sweet Potato',
    restaurant: 'FitFuel',
    description: 'Herb-grilled chicken breast, roasted sweet potato, steamed broccoli',
    calories: 380,
    protein: 35,
    carbs: 28,
    fat: 8,
    fiber: 6,
    price: 16.99,
    dietary: ['high_protein', 'paleo'],
    allergens: [],
    mealType: ['lunch', 'dinner']
  },
  {
    id: 'f3',
    name: 'Overnight Oats Bowl',
    restaurant: 'Morning Fresh',
    description: 'Steel-cut oats, berries, almond butter, chia seeds',
    calories: 320,
    protein: 12,
    carbs: 45,
    fat: 11,
    fiber: 9,
    price: 9.99,
    dietary: ['vegetarian', 'high_fiber'],
    allergens: ['nuts'],
    mealType: ['breakfast']
  },
  {
    id: 'f4',
    name: 'Salmon & Avocado Salad',
    restaurant: 'Ocean Fresh',
    description: 'Wild-caught salmon, mixed greens, avocado, olive oil dressing',
    calories: 420,
    protein: 32,
    carbs: 12,
    fat: 28,
    fiber: 7,
    price: 18.99,
    dietary: ['keto', 'high_protein', 'omega3'],
    allergens: ['fish'],
    mealType: ['lunch', 'dinner']
  },
  {
    id: 'f5',
    name: 'Greek Yogurt Parfait',
    restaurant: 'Morning Fresh',
    description: 'Greek yogurt, granola, fresh berries, honey drizzle',
    calories: 280,
    protein: 20,
    carbs: 35,
    fat: 6,
    fiber: 4,
    price: 8.99,
    dietary: ['vegetarian', 'high_protein'],
    allergens: ['dairy', 'gluten'],
    mealType: ['breakfast']
  }
];

// Helper Functions
function calculateBMR(age, weight, height, gender) {
  if (gender === 'male') {
    return 10 * weight + 6.25 * height - 5 * age + 5;
  } else {
    return 10 * weight + 6.25 * height - 5 * age - 161;
  }
}

function calculateTDEE(bmr, activityLevel) {
  const multipliers = {
    'sedentary': 1.2,
    'light': 1.375,
    'moderate': 1.55,
    'high': 1.725,
    'athlete': 1.9
  };
  return bmr * (multipliers[activityLevel] || 1.5);
}

function calculateTargetCalories(tdee, goal) {
  switch(goal) {
    case 'lose_weight': return tdee * 0.8;
    case 'gain_weight': return tdee * 1.2;
    case 'muscle_gain': return tdee * 1.1;
    default: return tdee;
  }
}

function isCompatibleFood(food, profile) {
  // Check allergies
  if (profile.allergies && profile.allergies.some(allergy => 
    food.allergens.includes(allergy))) {
    return false;
  }
  
  // Check dietary restrictions
  if (profile.dietary_restrictions) {
    if (profile.dietary_restrictions.includes('vegetarian') && 
        !food.dietary.includes('vegetarian') && 
        !food.dietary.includes('vegan')) {
      return false;
    }
    if (profile.dietary_restrictions.includes('vegan') && 
        !food.dietary.includes('vegan')) {
      return false;
    }
    if (profile.dietary_restrictions.includes('keto') && 
        food.carbs > 10) {
      return false;
    }
  }
  
  return true;
}

function generateMealPlan(profile) {
  if (!profile.weight || !profile.height || !profile.age) {
    return null;
  }

  const bmr = calculateBMR(profile.age, profile.weight, profile.height, profile.gender);
  const tdee = calculateTDEE(bmr, profile.activity_level);
  let targetCalories = calculateTargetCalories(tdee, profile.goal);
  
  // Use user-specified targets if available
  if (profile.target_calories) {
    targetCalories = profile.target_calories;
  }
  
  const mealsPerDay = profile.meals_per_day || 3;
  
  // Calculate macro targets
  let proteinTarget, carbsTarget, fatTarget;
  
  if (profile.target_protein) {
    proteinTarget = profile.target_protein;
  } else {
    // Default protein calculation based on goal
    if (profile.goal === 'muscle_gain') {
      proteinTarget = profile.weight * 2.2; // 2.2g per kg for muscle gain
    } else if (profile.goal === 'lose_weight') {
      proteinTarget = profile.weight * 1.8; // Higher protein for weight loss
    } else {
      proteinTarget = profile.weight * 1.6; // Standard recommendation
    }
  }
  
  // Set carbs and fat targets based on dietary restrictions
  if (profile.dietary_restrictions && profile.dietary_restrictions.includes('keto')) {
    carbsTarget = targetCalories * 0.05 / 4; // 5% carbs for keto
    fatTarget = (targetCalories - (proteinTarget * 4) - (carbsTarget * 4)) / 9;
  } else {
    carbsTarget = targetCalories * 0.45 / 4; // 45% carbs
    fatTarget = targetCalories * 0.30 / 9; // 30% fat
  }
  
  try {
    // Initialize optimizer with current food database
    const optimizer = new MealOptimizer(mockFoods);
    
    const constraints = {
      targetCalories: targetCalories,
      targetProtein: proteinTarget,
      targetCarbs: carbsTarget,
      targetFat: fatTarget,
      mealsPerDay: mealsPerDay,
      maxBudget: profile.budget_per_meal ? profile.budget_per_meal * mealsPerDay : 100
    };
    
    // Use optimization algorithm instead of simple selection
    const optimizedPlan = optimizer.optimizeMealPlan(profile, constraints);
    
    return {
      dailyPlan: optimizedPlan.dailyPlan,
      targetCalories: Math.round(targetCalories),
      mealsPerDay: mealsPerDay,
      nutritionGoals: {
        protein: Math.round(proteinTarget),
        carbs: Math.round(carbsTarget),
        fat: Math.round(fatTarget)
      },
      actualNutrition: optimizedPlan.actualNutrition,
      optimizationScore: optimizedPlan.optimizationScore
    };
    
  } catch (error) {
    console.error('Optimization failed:', error.message);
    // Fallback to simple meal planning if optimization fails
    return generateSimpleMealPlan(profile, targetCalories, proteinTarget, mealsPerDay);
  }
}

// Fallback function for when optimization fails
function generateSimpleMealPlan(profile, targetCalories, proteinTarget, mealsPerDay) {
  const compatibleFoods = mockFoods.filter(food => isCompatibleFood(food, profile));
  
  if (compatibleFoods.length === 0) {
    return null;
  }
  
  const caloriesPerMeal = targetCalories / mealsPerDay;
  const plan = {};
  const mealTypes = ['breakfast', 'lunch', 'dinner'].slice(0, mealsPerDay);
  
  mealTypes.forEach(mealType => {
    const mealFoods = compatibleFoods.filter(food => 
      food.mealType.includes(mealType)
    );
    
    if (mealFoods.length > 0) {
      // Simple scoring by calorie proximity
      const scoredFoods = mealFoods.map(food => ({
        ...food,
        score: 1 - Math.abs(food.calories - caloriesPerMeal) / caloriesPerMeal
      }));
      
      plan[mealType] = scoredFoods
        .sort((a, b) => b.score - a.score)
        .slice(0, 2); // Take top 2 options
    }
  });
  
  const actualNutrition = calculateActualNutritionFromPlan({ dailyPlan: plan });
  
  return {
    dailyPlan: plan,
    targetCalories: Math.round(targetCalories),
    mealsPerDay: mealsPerDay,
    nutritionGoals: {
      protein: Math.round(proteinTarget),
      carbs: Math.round(targetCalories * 0.45 / 4),
      fat: Math.round(targetCalories * 0.30 / 9)
    },
    actualNutrition: actualNutrition
  };
}

function calculateProfileCompleteness(profile) {
  const essentialFields = ['age', 'weight', 'height', 'gender', 'activity_level', 'goal', 'meals_per_day'];
  const completed = essentialFields.filter(field => profile[field] !== undefined && profile[field] !== null);
  return completed.length / essentialFields.length;
}

// API Routes

// Main chat endpoint
app.post('/api/chat', async (req, res) => {
  try {
    const { userId, message } = req.body;
    
    if (!userId || !message) {
      return res.status(400).json({ error: 'Missing userId or message' });
    }
    
    // Initialize user profile if doesn't exist
    if (!userProfiles[userId]) {
      userProfiles[userId] = { userId };
      conversations[userId] = [];
    }
    
    // Add user message to conversation
    conversations[userId].push({ role: 'user', content: message });
    
    // Extract information using AI - ALWAYS do this, even if profile is "complete"
    const extractionPrompt = `
    Extract meal planning information from this user message and return ONLY valid JSON. 
    Include only the fields where you're confident about the information.
    If the user is asking to modify existing preferences (like "make it 2000 calories instead" or "reduce protein"), 
    update those specific fields.
    
    Possible fields and their valid values:
    - age: number
    - weight: number (in kg, convert pounds if needed: pounds * 0.453592)
    - height: number (in cm, convert feet/inches if needed: feet*30.48 + inches*2.54)
    - gender: "male" or "female"
    - activity_level: "sedentary", "light", "moderate", "high", or "athlete"
    - dietary_restrictions: array from ["vegetarian", "vegan", "keto", "paleo", "gluten_free"]
    - goal: "maintain", "lose_weight", "gain_weight", or "muscle_gain"
    - meals_per_day: 1, 2, or 3
    - target_calories: number (if user specifies calorie target)
    - target_protein: number (if user specifies protein target)
    - allergies: array of strings
    - preferred_cuisines: array of strings
    - modification_request: true (if user is asking to change existing plan)
    
    User message: "${message}"
    Current profile: ${JSON.stringify(userProfiles[userId])}
    
    Return only JSON:`;
    
    const extractionResponse = await openai.chat.completions.create({
      model: "gpt-4",
      messages: [{ role: "user", content: extractionPrompt }],
      temperature: 0.1,
      max_tokens: 300
    });
    
    let extractedInfo = {};
    try {
      const extractedText = extractionResponse.choices[0].message.content.trim();
      const cleanedText = extractedText.replace(/^```json\s*/, '').replace(/\s*```$/, '');
      extractedInfo = JSON.parse(cleanedText);
    } catch (e) {
      console.log('Could not parse extracted info:', e.message);
    }
    
    // Update user profile with new information
    Object.keys(extractedInfo).forEach(key => {
      if (extractedInfo[key] !== null && extractedInfo[key] !== undefined && key !== 'modification_request') {
        userProfiles[userId][key] = extractedInfo[key];
      }
    });
    
    const profile = userProfiles[userId];
    const completeness = calculateProfileCompleteness(profile);
    
    let aiResponse;
    let mealPlan = null;
    let showMealPlan = false;
    
    // Check if user is requesting modifications or if we should generate a new plan
    const isModificationRequest = extractedInfo.modification_request || 
                                completeness >= 0.8 && 
                                conversations[userId].length > 2;
    
    if (completeness >= 0.8) {
      // Generate meal plan (new or updated)
      mealPlan = generateMealPlan(profile);
      
      if (mealPlan) {
        showMealPlan = true;
        
        // Calculate ACTUAL nutrition totals from selected foods
        const actualNutrition = calculateActualNutritionFromPlan(mealPlan);
        
        const planExplanationPrompt = `
        The user has requested a meal plan. ${isModificationRequest ? 'They may be asking to modify a previous plan.' : ''}
        
        User Profile: ${JSON.stringify(profile)}
        Target Calories: ${profile.target_calories || mealPlan.targetCalories}
        Target Protein: ${profile.target_protein || mealPlan.nutritionGoals.protein}g
        
        ACTUAL nutrition from selected foods:
        - Calories: ${actualNutrition.calories}
        - Protein: ${actualNutrition.protein}g
        - Carbs: ${actualNutrition.carbs}g
        - Fat: ${actualNutrition.fat}g
        
        ${isModificationRequest ? 
          'Acknowledge their modification request and explain how this updated plan addresses their new requirements.' :
          'Explain how this plan helps their specific goal and what to expect.'
        }
        
        Be honest about the actual nutrition numbers. If they don't match targets perfectly, explain why and suggest adjustments.
        Keep it conversational and under 150 words:`;
        
        const explanationResponse = await openai.chat.completions.create({
          model: "gpt-4",
          messages: [{ role: "user", content: planExplanationPrompt }],
          temperature: 0.7,
          max_tokens: 200
        });
        
        aiResponse = explanationResponse.choices[0].message.content;
        
        // Update meal plan with actual nutrition
        mealPlan.actualNutrition = actualNutrition;
      } else {
        aiResponse = "I have your preferences, but I couldn't find compatible meals in our current selection. Let me know if you'd like to adjust any dietary restrictions!";
      }
    } else {
      // Generate follow-up questions for incomplete profiles
      const missingInfo = ['age', 'weight', 'height', 'gender', 'activity_level', 'goal', 'meals_per_day']
        .filter(field => !profile[field]);
      
      const followUpPrompt = `
      User said: "${message}"
      Current profile: ${JSON.stringify(profile)}
      Missing info: ${missingInfo.join(', ')}
      Profile completeness: ${Math.round(completeness * 100)}%
      
      Generate a friendly, conversational response that:
      1. Acknowledges what they shared
      2. Asks for 1-2 of the most important missing pieces
      3. Explains why you need this info
      4. Keeps it under 100 words
      
      Be encouraging and natural:`;
      
      const followUpResponse = await openai.chat.completions.create({
        model: "gpt-4",
        messages: [{ role: "user", content: followUpPrompt }],
        temperature: 0.7,
        max_tokens: 150
      });
      
      aiResponse = followUpResponse.choices[0].message.content;
    }
    
    // Add AI response to conversation
    conversations[userId].push({ role: 'assistant', content: aiResponse });
    
    res.json({
      message: aiResponse,
      mealPlan: mealPlan,
      showMealPlan: showMealPlan,
      profileCompleteness: Math.round(completeness * 100),
      profile: profile
    });
    
  } catch (error) {
    console.error('Error in chat endpoint:', error);
    res.status(500).json({ 
      error: 'Something went wrong. Please try again.',
      message: "I'm having trouble processing that. Could you rephrase your message?"
    });
  }
});

// Add this new function to calculate actual nutrition from meal plan
function calculateActualNutritionFromPlan(mealPlan) {
  let totalCalories = 0;
  let totalProtein = 0;
  let totalCarbs = 0;
  let totalFat = 0;
  
  if (mealPlan.dailyPlan) {
    Object.values(mealPlan.dailyPlan).forEach(meals => {
      meals.forEach(food => {
        totalCalories += food.calories;
        totalProtein += food.protein;
        totalCarbs += food.carbs;
        totalFat += food.fat;
      });
    });
  }
  
  return {
    calories: Math.round(totalCalories),
    protein: Math.round(totalProtein),
    carbs: Math.round(totalCarbs),
    fat: Math.round(totalFat)
  };
}

// Add item to cart
app.post('/api/add-to-cart', (req, res) => {
  try {
    const { userId, foodId } = req.body;
    
    if (!userCarts[userId]) {
      userCarts[userId] = [];
    }
    
    const food = mockFoods.find(f => f.id === foodId);
    if (!food) {
      return res.status(404).json({ error: 'Food item not found' });
    }
    
    userCarts[userId].push(food);
    
    res.json({ 
      success: true, 
      cartSize: userCarts[userId].length,
      message: `${food.name} added to cart!`
    });
  } catch (error) {
    console.error('Error adding to cart:', error);
    res.status(500).json({ error: 'Failed to add item to cart' });
  }
});

// Get cart
app.get('/api/cart/:userId', (req, res) => {
  try {
    const { userId } = req.params;
    const cart = userCarts[userId] || [];
    const total = cart.reduce((sum, item) => sum + item.price, 0);
    
    res.json({ cart, total: total.toFixed(2) });
  } catch (error) {
    console.error('Error getting cart:', error);
    res.status(500).json({ error: 'Failed to get cart' });
  }
});

// Checkout
app.post('/api/checkout', (req, res) => {
  try {
    const { userId } = req.body;
    const cart = userCarts[userId] || [];
    
    if (cart.length === 0) {
      return res.status(400).json({ error: 'Cart is empty' });
    }
    
    const total = cart.reduce((sum, item) => sum + item.price, 0);
    const orderId = 'order_' + Date.now();
    
    // Clear cart
    userCarts[userId] = [];
    
    res.json({ 
      orderId, 
      total: total.toFixed(2), 
      message: 'Order placed successfully! Delivery in 30-45 minutes.',
      items: cart.length
    });
  } catch (error) {
    console.error('Error during checkout:', error);
    res.status(500).json({ error: 'Checkout failed' });
  }
});

// Health check
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    users: Object.keys(userProfiles).length
  });
});

// Add this new function to calculate actual nutrition from meal plan
function calculateActualNutritionFromPlan(mealPlan) {
  let totalCalories = 0;
  let totalProtein = 0;
  let totalCarbs = 0;
  let totalFat = 0;
  
  if (mealPlan.dailyPlan) {
    Object.values(mealPlan.dailyPlan).forEach(meals => {
      meals.forEach(food => {
        totalCalories += food.calories;
        totalProtein += food.protein;
        totalCarbs += food.carbs;
        totalFat += food.fat;
      });
    });
  }
  
  return {
    calories: Math.round(totalCalories),
    protein: Math.round(totalProtein),
    carbs: Math.round(totalCarbs),
    fat: Math.round(totalFat)
  };
}
// Start server
app.listen(port, () => {
  console.log(`🚀 Meal Planner API running on http://localhost:${port}`);
  console.log(`📊 Health check: http://localhost:${port}/api/health`);
});