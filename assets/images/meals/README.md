Meal images directory

Place one PNG or JPG per meal here using this naming scheme:
- File name: <meal-slug>.png (or .jpg)
- The slug is derived from the meal name used in Firestore:
  - lowercase
  - non-alphanumeric -> "-"
  - collapse repeated dashes
  - trim leading/trailing dashes

Examples:
- "Greek Yogurt Parfait" -> greek-yogurt-parfait.png
- "Avocado Toast" -> avocado-toast.png
- "Salmon with Vegetables" -> salmon-with-vegetables.png

How it works
- The app now renders images from either network URLs or bundled assets using a unified AppImage widget.
- An admin tool in Settings can re-point all meals' imageUrl to assets: assets/images/meals/<slug>.png
- After copying images here, open Settings > Admin Tools > "Use Bundled Asset Images for Meals".

Notes
- Ensure pubspec.yaml keeps: assets/images/
- After adding files, run a Flutter build or restart the app for hot-reload to pick up new assets (Web needs rebuild to deploy to Hosting).
- If you prefer JPG, the switcher can be adjusted to use .jpg; current default is .png.
