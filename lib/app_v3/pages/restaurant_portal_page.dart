import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:html' as html;

/// Restaurant portal page that redirects to the dedicated restaurant.html interface
/// This provides restaurants with a clean interface to view their prep schedules
class RestaurantPortalPage extends StatefulWidget {
  const RestaurantPortalPage({super.key});

  @override
  State<RestaurantPortalPage> createState() => _RestaurantPortalPageState();
}

class _RestaurantPortalPageState extends State<RestaurantPortalPage> {
  @override
  void initState() {
    super.initState();
    
    // On web, redirect to the dedicated restaurant.html page
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        html.window.location.href = '/restaurant.html';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fallback UI for non-web or during redirect
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
            ],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.restaurant,
                size: 80,
                color: Colors.white,
              ),
              SizedBox(height: 24),
              Text(
                'FreshPunk Restaurant Portal',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Redirecting to restaurant portal...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              SizedBox(height: 32),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}