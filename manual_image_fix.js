// Run this in your browser console on Firebase Console Firestore page
// Go to: https://console.firebase.google.com/project/freshpunk-48db1/firestore/data/meals

// Copy and paste this entire script into browser console:

const imageMappings = {
  'avocado-toast': 'avocado-toast',
  'bbq-pulled-pork': 'bbq-pulled-pork', 
  'beef-burger': 'beef-burger',
  'beef-burrito': 'beef-burrito',
  'beef-stew': 'beef-stew',
  'beef-stir-fry': 'beef-stir-fry', 
  'beef-tacos': 'beef-tacos',
  'chicken-alfredo': 'chicken-alfredo',
  'chicken-caesar-wrap': 'chicken-caesar-wrap',
  'chicken-curry': 'chicken-curry',
  'chicken-fajita-pasta': 'chicken-fajita-pasta',
  'chicken-fajitas': 'chicken-fajitas',
  'chicken-fried-rice': 'chicken-fried-rice',
  'chicken-noodle-soup': 'chicken-noodle-soup',
  'chicken-parmesan': 'chicken-parmesan', 
  'chicken-pot-pie': 'chicken-pot-pie',
  'chicken-quesadilla': 'chicken-quesadilla',
  'chicken-tikka-masala': 'chicken-tikka-masala',
  'egg-salad-sandwich': 'egg-salad-sandwich',
  'eggplant-parmesan': 'eggplant-parmesan',
  'eggs-benedict': 'eggs-benedict',
  'fish-and-chips': 'fish-and-chips',
  'french-toast': 'french-toast',
  'fruit-salad': 'fruit-salad',
  'greek-yogurt-parfait': 'greek-yogurt-parfait', 
  'grilled-cheese': 'grilled-cheese',
  'grilled-chicken-salad': 'grilled-chicken-salad',
  'ham-and-cheese-omelette': 'ham-and-cheese-omelette',
  'lentil-soup': 'lentil-soup',
  'mushroom-risotto': 'mushroom-risotto',
  'pancakes-with-berries': 'pancakes-with-berries',
  'pasta-primavera': 'pasta-primavera',
  'pesto-pasta': 'pesto-pasta',
  'quinoa-bowl': 'quinoa-bowl',
  'roast-beef-dinner': 'roast-beef-dinner',
  'salmon-sushi': 'salmon-sushi',
  'salmon-with-quinoa': 'salmon-with-quinoa',
  'shrimp-scampi': 'shrimp-scampi',
  'shrimp-tacos': 'shrimp-tacos', 
  'spinach-omelette': 'spinach-omelette',
  'steak-fajitas': 'steak-fajitas',
  'tofu-stir-fry': 'tofu-stir-fry',
  'turkey-chili': 'turkey-chili',
  'turkey-sandwich': 'turkey-sandwich',
  'vegan-cream-cheese-veggie-wraps': 'vegan-cream-cheese-veggie-wraps',
  'vegetable-curry': 'vegetable-curry',
  'vegetable-lasagna': 'vegetable-lasagna',
  'vegetable-stir-fry': 'vegetable-stir-fry',
  'vegetarian-pasta': 'vegetarian-pasta',
  'veggie-burger': 'veggie-burger',
  'veggie-pizza': 'veggie-pizza',
  'veggie-wrap': 'veggie-wrap'
};

// Show mapping plan
console.log('=== MEAL IMAGE MAPPING PLAN ===');
for (const [slug, image] of Object.entries(imageMappings)) {
  console.log(`${slug} → assets/images/meals/${image}.jpg`);
}

console.log('\n=== INSTRUCTIONS ===');
console.log('1. The mappings above show what each meal should use');
console.log('2. In Firebase Console, click on each meal document');
console.log('3. Edit the "imageUrl" field to match the mapping');
console.log('4. Save each change');
console.log('\nAlternatively, use the pink "Auto-Fix Image Mappings" button in your app!');
