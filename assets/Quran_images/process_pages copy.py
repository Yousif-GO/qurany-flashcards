from PIL import Image, ImageEnhance
import os
import numpy as np
import requests
import os
from PIL import Image, ImageEnhance, ImageFilter
import numpy as np
def process_image(input_path, output_path, max_size=1053, target_size_kb=100):
    # Open image
    output_image = Image.open(input_path)
    
    # Convert to RGBA if not already
    if output_image.mode != 'RGBA':
        output_image = output_image.convert('RGBA')
    
    # Convert to numpy array for faster processing
    data = np.array(output_image)
    
    # Create mask for the specific yellow color (255,254,216)
    tolerance = 10
    color_mask = (
        (data[:, :, 0] >= 255 - tolerance) & (data[:, :, 0] <= 255) &
        (data[:, :, 1] >= 254 - tolerance) & (data[:, :, 1] <= 255) &
        (data[:, :, 2] >= 216 - tolerance) & (data[:, :, 2] <= 216 + tolerance)
    )
    
    # Set matched pixels to white
    data[color_mask] = [255, 255, 255, 255]
    
    # Convert back to PIL Image
    output_image = Image.fromarray(data)
    
    # Convert to RGB with white background
    background = Image.new('RGB', output_image.size, (255, 255, 255))
    background.paste(output_image, mask=output_image.split()[3])
    output_image = background
    
    # Calculate new dimensions while maintaining aspect ratio
    width, height = output_image.size
    if width > max_size or height > max_size:
        ratio = min(max_size/width, max_size/height)
        new_width = int(width * ratio)
        new_height = int(height * ratio)
        output_image = output_image.resize((new_width, new_height), Image.Resampling.LANCZOS)
    
    # Apply sharpening
    sharpener = ImageEnhance.Sharpness(output_image)
    output_image = sharpener.enhance(2.0)  # Adjust value between 1.0-2.0
    
    # Apply contrast enhancement
    contraster = ImageEnhance.Contrast(output_image)
    output_image = contraster.enhance(1.2)  # Adjust value between 1.0-1.5
    
    # Save with progressive quality reduction until target size is reached
    quality = 100
    min_quality = 30
    
    while quality >= min_quality:
        output_image.save(output_path, 'JPEG', 
                         quality=quality, 
                         optimize=True,
                         subsampling=0)  # Changed to 0 for better text quality
        
        if os.path.getsize(output_path) <= target_size_kb * 1024:
            break
        quality -= 3
    
    # If still too large, try more aggressive compression
    if os.path.getsize(output_path) > target_size_kb * 1024:
        output_image.save(output_path, 'JPEG', 
                         quality=min_quality, 
                         optimize=True,
                         subsampling=1)  # Use less aggressive subsampling

def download_and_process_page(page_num):
    # Create formatted page number (001, 002, etc)
    page_str = str(page_num).zfill(3)
    
    # Create URL
    url = f"https://easyquran.com/wp-content/HafsPages/images/{page_str}.jpg"
    
    try:
        # Download image
        response = requests.get(url)
        response.raise_for_status()
        
        # Save original image temporarily
        temp_path = f"temp_{page_str}.jpg"
        with open(temp_path, "wb") as f:
            f.write(response.content)
        
        # Process the image using your enhancement function
        output_path = f"Txt files\Quran_images\{page_str}.jpg"
        process_image(temp_path, output_path)
        
        # Clean up temp file
        os.remove(temp_path)
        
        print(f"Successfully processed page {page_str}")
        
    except Exception as e:
        print(f"Error processing page {page_str}: {str(e)}")

def main():
    # Process all pages
    for page_num in range(1, 605):
        download_and_process_page(page_num)
        
if __name__ == "__main__":
    main()