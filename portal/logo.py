import matplotlib.pyplot as plt
from matplotlib.patches import Circle, Rectangle

# Create a figure for the logo
fig, ax = plt.subplots(figsize=(6, 6), facecolor='#ffffff')

# Draw the main circle for the logo
main_circle = Circle((0.5, 0.5), 0.4, color='#2980b9', ec='none', alpha=0.9)
ax.add_patch(main_circle)

# Draw the X in the center
plt.plot([0.35, 0.65], [0.35, 0.65], color='white', lw=8, solid_capstyle='round')
plt.plot([0.35, 0.65], [0.65, 0.35], color='white', lw=8, solid_capstyle='round')

# Add a small rectangle at the center
center_rect = Rectangle((0.48, 0.48), 0.04, 0.04, color='white')
ax.add_patch(center_rect)

# Add the text below the logo
plt.text(0.5, 0.2, 'SmartSwapX', fontsize=20, fontweight='bold', color='#2980b9', ha='center', va='center')

# Remove axes
ax.axis('off')

# Save the logo as a PNG file
file_path = "SmartSwapX_Logo.png"
fig.savefig(file_path, dpi=300, bbox_inches='tight', transparent=True)

# Display the logo
plt.tight_layout()
plt.show()
