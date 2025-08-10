# FreshPunk App Icon Generator

To create the FreshPunk app icon from the SVG, you'll need to convert the SVG to PNG format.

## Option 1: Online Conversion (Recommended)
1. Go to https://convertio.co/svg-png/ or https://cloudconvert.com/svg-to-png
2. Upload the `assets/icons/app_icon_192.svg` file
3. Set output size to 1024x1024 pixels
4. Download the converted PNG file
5. Save it as `assets/icons/app_icon.png`

## Option 2: Using Inkscape (If installed)
```bash
inkscape --export-png=assets/icons/app_icon.png --export-width=1024 --export-height=1024 assets/icons/app_icon_192.svg
```

## Option 3: Using ImageMagick (If installed)
```bash
magick convert -background white -size 1024x1024 assets/icons/app_icon_192.svg assets/icons/app_icon.png
```

## After Converting:
1. Update pubspec.yaml to point to the PNG file:
   ```yaml
   flutter_launcher_icons:
     android: true
     ios: true
     image_path: "assets/icons/app_icon.png"
   ```

2. Run the icon generation:
   ```bash
   flutter pub get
   flutter pub run flutter_launcher_icons
   ```

## Design Details:
The FreshPunk logo features:
- **Plate with compartments** containing meat (red), carrot (orange), and greens
- **Fork and knife** on the sides
- **"Fresh" text in green** (#22aa22)
- **"Punk" text in red/orange** (#ff4444)
- **Clean white background** with rounded corners
- **Gray utensils and plate borders** (#4a4a4a)

This matches the uploaded reference image with proper app icon proportions.
