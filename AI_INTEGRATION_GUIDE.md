# AI Service Setup Instructions

## Overview
Your original AI meal planner uses a Node.js backend with OpenAI to provide conversational meal planning. The Flutter app now connects to this service for a proper AI chat experience.

## Setup Steps

### 1. Install Dependencies
```bash
cd ai_services
npm install
```

### 2. Set up Environment Variables
Create a `.env` file in the `ai_services` directory:
```
OPENAI_API_KEY=your_openai_api_key_here
PORT=3000
```

### 3. Start the AI Service
```bash
cd ai_services
npm start
```
The service will run on `http://localhost:3000`

### 4. Test the Service
You can test the service directly by opening `http://localhost:3000` in your browser to use the HTML chat interface.

## Integration with Flutter App

The Flutter app now has an `AIChatPageV3` that connects to your AI service:

- **Endpoint**: `POST http://localhost:3000/api/chat`
- **Payload**: `{"userId": "unique_id", "message": "user_message"}`
- **Response**: Contains AI response, profile completeness, and meal plan data

## Features

### AI Conversation Flow
1. User starts chat with health goals
2. AI extracts information using GPT-4
3. Profile completeness is tracked and displayed
4. When profile is 80%+ complete, AI generates meal plans
5. User can accept the meal plan to complete onboarding

### Smart Extraction
The AI service automatically extracts:
- Age, weight, height, gender
- Activity level and dietary restrictions  
- Health goals and meal preferences
- Target calories and protein
- Allergies and cuisine preferences

### Meal Plan Generation
- Uses optimization algorithm for balanced nutrition
- Considers dietary restrictions and preferences
- Provides actual nutrition calculations
- Explains plan and suggests adjustments

## Next Steps

1. **Get OpenAI API Key**: Sign up at https://platform.openai.com
2. **Start AI Service**: Run the commands above
3. **Test Integration**: Use the AI-Powered Setup option in the Flutter app
4. **Deploy AI Service**: Consider deploying to Heroku, Railway, or similar for production

The original AI service is much more sophisticated than the simple form - it provides natural conversation, intelligent information extraction, and personalized meal planning using real AI.
