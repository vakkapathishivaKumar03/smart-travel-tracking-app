import colorsys
from PIL import Image

def recolor():
    img_path = r"C:\Users\puppa\.gemini\antigravity\brain\32e0a578-c501-4d2a-942a-ec5a9871ccb6\media__1774474022827.png"
    out_path = r"C:\Users\puppa\OneDrive\Desktop\smart-travel\smart_travel_app\assets\logo\travelpilot_logo.png"

    img = Image.open(img_path).convert("RGBA")
    pixels = img.load()

    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = pixels[x, y]
            if a == 0: continue
            
            h, s, v = colorsys.rgb_to_hsv(r/255.0, g/255.0, b/255.0)
            
            # Yellow hue is around 0.12 - 0.20
            # If it's somewhat saturated and bright, it's the yellow accent
            if 0.05 <= h <= 0.25 and s > 0.2 and v > 0.4:
                # Shift Hue to Teal (0.5 for Cyan/Teal)
                h = 0.50
                # Darken slightly to match #008080 (Teal is a darker cyan)
                v = min(v, 0.6)
                
                nr, ng, nb = colorsys.hsv_to_rgb(h, s, v)
                pixels[x, y] = (int(nr*255), int(ng*255), int(nb*255), a)

    img.save(out_path, "PNG")
    print("RECOLOR SUCCESS")

if __name__ == "__main__":
    recolor()
