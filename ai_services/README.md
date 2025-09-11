# Meal Planner App

A smart meal planning application that uses AI to create personalized nutrition plans based on user preferences and dietary requirements.

## Features

- AI-powered meal planning using OpenAI
- Personalized nutrition calculations based on BMR/TDEE
- Support for various dietary restrictions (vegetarian, vegan, keto, paleo, gluten-free)
- Optimization algorithm for balanced meal selection
- Shopping cart functionality for meal ordering
- Real-time chat interface for meal planning

## Technologies Used

- **Backend**: Node.js, Express.js
- **AI**: OpenAI GPT-4
- **Frontend**: HTML, CSS, JavaScript
- **Optimization**: Custom meal optimization algorithm

## Setup Instructions

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd meal-planner-app
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Create a `.env` file with your OpenAI API key:
   ```
   OPENAI_API_KEY=your_openai_api_key_here
   PORT=3000
   ```

4. Start the server:
   ```bash
   npm start
   ```

5. Open your browser and go to `http://localhost:3000`

## API Endpoints

- `POST /api/chat` - Main chat interface for meal planning
- `POST /api/add-to-cart` - Add food items to shopping cart
- `GET /api/cart/:userId` - Get user's cart contents
- `POST /api/checkout` - Process order checkout
- `GET /api/health` - Health check endpoint

## Project Structure

```
meal-planner-app/
├── server.js              # Main Express server
├── mealOptimizer.js       # Meal optimization algorithm
├── package.json           # Project dependencies
├── public/
│   └── index.html        # Frontend interface
└── .env                  # Environment variables (not in repo)
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This project is licensed under the MIT License.
