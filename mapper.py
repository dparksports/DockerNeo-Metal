import numpy as np
import matplotlib.pyplot as plt
from PIL import Image

def create_interactive_3d_map(image_path, downsample_factor=None):
    # 1. Load and process the image
    print(f"Loading image from {image_path}...")
    try:
        img = Image.open(image_path).convert('L')  # Convert to grayscale (L)
    except FileNotFoundError:
        print("Error: Image file not found. Please check the path.")
        return

    # 2. Downsample for performance (Matplotlib struggles with full-res images)
    # If no factor provided, calculate one to keep max dimension under ~100-150px
    if downsample_factor is None:
        max_dim = max(img.size)
        downsample_factor = max(1, max_dim // 100)
    
    # Resize image using the calculated factor
    target_size = (img.width // downsample_factor, img.height // downsample_factor)
    img_resized = img.resize(target_size, Image.Resampling.BILINEAR)
    
    # Convert to numpy array (these will be our Z values - height)
    Z = np.array(img_resized)
    
    # Create X and Y coordinates
    rows, cols = Z.shape
    x = np.arange(cols)
    y = np.arange(rows)
    X, Y = np.meshgrid(x, y)

    # 3. Create the 3D Plot
    fig = plt.figure(figsize=(10, 8))
    # '3d' projection requires mplot3d (included in standard matplotlib)
    ax = fig.add_subplot(111, projection='3d')
    
    # Plot the surface
    # cmap='viridis' adds color based on height
    # rstride/cstride control how many lines are drawn (higher = faster)
    surf = ax.plot_surface(X, Y, Z, cmap='viridis', 
                           linewidth=0, antialiased=False,
                           rstride=1, cstride=1)

    # Set initial view angles
    ax.view_init(elev=45, azim=45)
    
    # Remove axis clutter for a cleaner look
    ax.set_axis_off()
    plt.title("Use W/A/S/D to tilt and rotate")

    # 4. Define the Interactive Logic
    current_view = {'elev': 45, 'azim': 45}

    def on_key(event):
        step = 5  # Degrees to move per key press
        
        if event.key == 'w':
            current_view['elev'] += step
        elif event.key == 's':
            current_view['elev'] -= step
        elif event.key == 'a':
            current_view['azim'] -= step
        elif event.key == 'd':
            current_view['azim'] += step
            
        # Clamp elevation to prevent flipping upside down
        if current_view['elev'] > 90: current_view['elev'] = 90
        if current_view['elev'] < -90: current_view['elev'] = -90
            
        # Update the view
        ax.view_init(elev=current_view['elev'], azim=current_view['azim'])
        
        # Redraw the figure slightly lighter than a full render
        fig.canvas.draw_idle()

    # Connect the keyboard event to the figure
    fig.canvas.mpl_connect('key_press_event', on_key)

    print("Map generated! Press W/A/S/D to move.")
    plt.show()

# --- RUN THE CODE ---
# Create a dummy image if you don't have one, or replace with your file path
# e.g., create_interactive_3d_map('my_photo.jpg')


if __name__ == "__main__":
    create_interactive_3d_map('agentsquare.jpg')    