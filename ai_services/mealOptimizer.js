class MealOptimizer {
    constructor(foodDatabase) {
        this.foodDatabase = foodDatabase;
    }

    // Main optimization function that actually hits calorie/protein targets
    optimizeMealPlan(profile, constraints) {
        const {
            targetCalories,
            targetProtein,
            targetCarbs,
            targetFat,
            mealsPerDay,
            maxBudget = 100
        } = constraints;

        // Filter compatible foods first
        const compatibleFoods = this.filterCompatibleFoods(profile);
        
        if (compatibleFoods.length < 3) {
            throw new Error('Not enough compatible foods available');
        }

        // Use simple genetic algorithm to find optimal combination
        const solution = this.runSimpleOptimization(
            compatibleFoods,
            targetCalories,
            targetProtein,
            targetCarbs,
            targetFat,
            mealsPerDay,
            maxBudget
        );

        return this.formatMealPlan(solution, mealsPerDay, compatibleFoods);
    }

    filterCompatibleFoods(profile) {
        return this.foodDatabase.filter(food => {
            // Check allergies
            if (profile.allergies && profile.allergies.some(allergy => 
                food.allergens.includes(allergy))) {
                return false;
            }

            // Check dietary restrictions
            if (profile.dietary_restrictions) {
                // Vegetarian check
                if (profile.dietary_restrictions.includes('vegetarian') && 
                    !food.dietary.includes('vegetarian') && 
                    !food.dietary.includes('vegan')) {
                    return false;
                }
                
                // Vegan check
                if (profile.dietary_restrictions.includes('vegan') && 
                    !food.dietary.includes('vegan')) {
                    return false;
                }
                
                // Keto check
                if (profile.dietary_restrictions.includes('keto') && 
                    food.carbs > 10) {
                    return false;
                }
                
                // Gluten-free check
                if (profile.dietary_restrictions.includes('gluten_free') && 
                    !food.dietary.includes('gluten_free')) {
                    return false;
                }
            }

            return true;
        });
    }

    runSimpleOptimization(foods, targetCalories, targetProtein, targetCarbs, targetFat, mealsPerDay, maxBudget) {
        const populationSize = 50;
        const generations = 100;
        const mutationRate = 0.1;
        
        // Create initial population
        let population = [];
        for (let i = 0; i < populationSize; i++) {
            population.push(this.generateRandomMealCombination(foods, mealsPerDay));
        }

        let bestSolution = null;
        let bestFitness = -Infinity;

        // Evolution loop
        for (let gen = 0; gen < generations; gen++) {
            // Evaluate fitness for each individual
            const fitnessScores = population.map(individual => 
                this.calculateFitness(individual, foods, targetCalories, targetProtein, targetCarbs, targetFat, maxBudget)
            );

            // Track best solution
            const currentBestIndex = this.getMaxIndex(fitnessScores);
            if (fitnessScores[currentBestIndex] > bestFitness) {
                bestFitness = fitnessScores[currentBestIndex];
                bestSolution = this.deepCopy(population[currentBestIndex]);
            }

            // Create new generation
            const newPopulation = [];
            
            // Keep best 20% (elitism)
            const sortedIndices = this.getSortedIndices(fitnessScores);
            const eliteCount = Math.floor(populationSize * 0.2);
            
            for (let i = 0; i < eliteCount; i++) {
                newPopulation.push(this.deepCopy(population[sortedIndices[i]]));
            }

            // Generate rest through crossover and mutation
            while (newPopulation.length < populationSize) {
                const parent1 = this.selectParent(population, fitnessScores);
                const parent2 = this.selectParent(population, fitnessScores);
                
                let child = this.crossover(parent1, parent2);
                child = this.mutate(child, foods, mutationRate);
                
                newPopulation.push(child);
            }

            population = newPopulation;
        }

        return bestSolution;
    }

    generateRandomMealCombination(foods, mealsPerDay) {
        const combination = [];
        
        for (let meal = 0; meal < mealsPerDay; meal++) {
            const mealFoods = [];
            const numFoodsThisMeal = Math.floor(Math.random() * 3) + 1; // 1-3 foods per meal
            
            for (let i = 0; i < numFoodsThisMeal; i++) {
                const randomFoodIndex = Math.floor(Math.random() * foods.length);
                mealFoods.push(randomFoodIndex);
            }
            
            combination.push(mealFoods);
        }
        
        return combination;
    }

    calculateFitness(individual, foods, targetCalories, targetProtein, targetCarbs, targetFat, maxBudget) {
        const nutrition = this.calculateNutritionFromIndividual(individual, foods);
        
        // Calculate how far off we are from targets (as percentages)
        const calorieError = Math.abs(nutrition.calories - targetCalories) / targetCalories;
        const proteinError = Math.max(0, (targetProtein - nutrition.protein) / targetProtein); // Only penalize if under
        const carbsError = Math.abs(nutrition.carbs - targetCarbs) / targetCarbs;
        const fatError = Math.abs(nutrition.fat - targetFat) / targetFat;
        const budgetError = Math.max(0, (nutrition.cost - maxBudget) / maxBudget);

        // Variety bonus
        const uniqueFoods = new Set(individual.flat()).size;
        const varietyBonus = uniqueFoods / foods.length;

        // Fitness score (higher is better, starts at 100 and subtracts penalties)
        const fitness = 100 - (
            calorieError * 40 +      // Calories are very important
            proteinError * 30 +      // Protein is important (especially not being under)
            carbsError * 15 +        // Carbs matter but less critical
            fatError * 10 +          // Fat is least critical
            budgetError * 20         // Budget overruns are bad
        ) + varietyBonus * 10;       // Variety is good

        return Math.max(0, fitness); // Don't allow negative fitness
    }

    calculateNutritionFromIndividual(individual, foods) {
        let totalCalories = 0;
        let totalProtein = 0;
        let totalCarbs = 0;
        let totalFat = 0;
        let totalCost = 0;

        individual.forEach(meal => {
            meal.forEach(foodIndex => {
                if (foodIndex < foods.length) {
                    const food = foods[foodIndex];
                    totalCalories += food.calories;
                    totalProtein += food.protein;
                    totalCarbs += food.carbs;
                    totalFat += food.fat;
                    totalCost += food.price;
                }
            });
        });

        return {
            calories: totalCalories,
            protein: totalProtein,
            carbs: totalCarbs,
            fat: totalFat,
            cost: totalCost
        };
    }

    selectParent(population, fitnessScores) {
        // Tournament selection
        const tournamentSize = 3;
        let bestIndex = Math.floor(Math.random() * population.length);
        
        for (let i = 1; i < tournamentSize; i++) {
            const candidateIndex = Math.floor(Math.random() * population.length);
            if (fitnessScores[candidateIndex] > fitnessScores[bestIndex]) {
                bestIndex = candidateIndex;
            }
        }
        
        return this.deepCopy(population[bestIndex]);
    }

    crossover(parent1, parent2) {
        const child = [];
        const maxLength = Math.max(parent1.length, parent2.length);
        
        for (let i = 0; i < maxLength; i++) {
            if (Math.random() < 0.5 && parent1[i]) {
                child.push([...parent1[i]]);
            } else if (parent2[i]) {
                child.push([...parent2[i]]);
            } else if (parent1[i]) {
                child.push([...parent1[i]]);
            }
        }
        
        return child;
    }

    mutate(individual, foods, mutationRate) {
        individual.forEach(meal => {
            meal.forEach((foodIndex, index) => {
                if (Math.random() < mutationRate) {
                    // Replace with random food
                    meal[index] = Math.floor(Math.random() * foods.length);
                }
            });
            
            // Sometimes add or remove a food from the meal
            if (Math.random() < mutationRate) {
                if (meal.length > 1 && Math.random() < 0.5) {
                    // Remove a food
                    meal.splice(Math.floor(Math.random() * meal.length), 1);
                } else if (meal.length < 4) {
                    // Add a food
                    meal.push(Math.floor(Math.random() * foods.length));
                }
            }
        });
        
        return individual;
    }

    formatMealPlan(solution, mealsPerDay, foods) {
        const mealTypes = ['breakfast', 'lunch', 'dinner'];
        const dailyPlan = {};
        
        solution.forEach((meal, index) => {
            const mealType = mealTypes[index % mealsPerDay];
            const mealFoods = meal.map(foodIndex => foods[foodIndex]).filter(Boolean);
            dailyPlan[mealType] = mealFoods;
        });

        const actualNutrition = this.calculateNutritionFromIndividual(solution, foods);
        
        return {
            dailyPlan,
            actualNutrition,
            optimizationScore: this.calculateFitness(solution, foods, actualNutrition.calories, actualNutrition.protein, actualNutrition.carbs, actualNutrition.fat, 100)
        };
    }

    // Helper functions
    deepCopy(obj) {
        return JSON.parse(JSON.stringify(obj));
    }

    getMaxIndex(array) {
        let maxIndex = 0;
        for (let i = 1; i < array.length; i++) {
            if (array[i] > array[maxIndex]) {
                maxIndex = i;
            }
        }
        return maxIndex;
    }

    getSortedIndices(array) {
        return array
            .map((value, index) => ({ value, index }))
            .sort((a, b) => b.value - a.value)
            .map(item => item.index);
    }
}

module.exports = MealOptimizer;