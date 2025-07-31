import re
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from mpl_toolkits.mplot3d import Axes3D
import seaborn as sns

def parse_homology_data(filename):
    """Parse the homology computation data from the file."""
    data = []
    
    with open(filename, 'r') as file:
        content = file.read()
    
    # Pattern to match graph processing blocks
    graph_pattern = r'Processing graph \d+ \(index \d+\): erdos_renyi_(\d+)_([\d.]+) \((\d+) vertices\)\s+H0: (\d+) \(([\d.]+)s\)\s+H1: (\d+) \(([\d.]+)s\)\s+Total: ([\d.]+)s'
    
    matches = re.findall(graph_pattern, content)
    
    for match in matches:
        vertices_name = int(match[0])  # vertices from name
        edge_prob = float(match[1])
        vertices_actual = int(match[2])  # vertices from description
        h0_dim = int(match[3])
        h0_time = float(match[4])
        h1_dim = int(match[5])
        h1_time = float(match[6])
        total_time = float(match[7])
        
        data.append({
            'vertices': vertices_actual,
            'edge_probability': edge_prob,
            'h0_dimension': h0_dim,
            'h0_time': h0_time,
            'h1_dimension': h1_dim,
            'h1_time': h1_time,
            'total_time': total_time
        })
    
    return pd.DataFrame(data)

def create_visualizations(df, filename='parallel_simp_test.txt'):
    """Create various visualizations of the homology computation data."""
    
    # Set up the plotting style
    plt.style.use('default')
    sns.set_palette("husl")
    
    # Create a figure with multiple subplots
    fig = plt.figure(figsize=(15, 12))
    
    # 1. Scatter plots: Time vs Vertices colored by edge probability
    ax1 = plt.subplot(3, 3, 1)
    scatter1 = plt.scatter(df['vertices'], df['h0_time'], c=df['edge_probability'], 
                          alpha=0.7, cmap='viridis', s=50)
    plt.xlabel('Number of Vertices')
    plt.ylabel('H0 Computation Time (s)')
    plt.title('H0 Time vs Vertices')
    plt.colorbar(scatter1, label='Edge Probability')
    plt.yscale('log')
    
    ax2 = plt.subplot(3, 3, 2)
    scatter2 = plt.scatter(df['vertices'], df['h1_time'], c=df['edge_probability'], 
                          alpha=0.7, cmap='viridis', s=50)
    plt.xlabel('Number of Vertices')
    plt.ylabel('H1 Computation Time (s)')
    plt.title('H1 Time vs Vertices')
    plt.colorbar(scatter2, label='Edge Probability')
    plt.yscale('log')
    
    ax3 = plt.subplot(3, 3, 3)
    scatter3 = plt.scatter(df['vertices'], df['total_time'], c=df['edge_probability'], 
                          alpha=0.7, cmap='viridis', s=50)
    plt.xlabel('Number of Vertices')
    plt.ylabel('Total Computation Time (s)')
    plt.title('Total Time vs Vertices')
    plt.colorbar(scatter3, label='Edge Probability')
    plt.yscale('log')
    
    # 2. Scatter plots: Time vs Edge Probability colored by vertices
    ax4 = plt.subplot(3, 3, 4)
    scatter4 = plt.scatter(df['edge_probability'], df['h0_time'], c=df['vertices'], 
                          alpha=0.7, cmap='plasma', s=50)
    plt.xlabel('Edge Probability')
    plt.ylabel('H0 Computation Time (s)')
    plt.title('H0 Time vs Edge Probability')
    plt.colorbar(scatter4, label='Vertices')
    plt.yscale('log')
    
    ax5 = plt.subplot(3, 3, 5)
    scatter5 = plt.scatter(df['edge_probability'], df['h1_time'], c=df['vertices'], 
                          alpha=0.7, cmap='plasma', s=50)
    plt.xlabel('Edge Probability')
    plt.ylabel('H1 Computation Time (s)')
    plt.title('H1 Time vs Edge Probability')
    plt.colorbar(scatter5, label='Vertices')
    plt.yscale('log')
    
    ax6 = plt.subplot(3, 3, 6)
    scatter6 = plt.scatter(df['edge_probability'], df['total_time'], c=df['vertices'], 
                          alpha=0.7, cmap='plasma', s=50)
    plt.xlabel('Edge Probability')
    plt.ylabel('Total Computation Time (s)')
    plt.title('Total Time vs Edge Probability')
    plt.colorbar(scatter6, label='Vertices')
    plt.yscale('log')
    
    # 3. Box plots showing distribution by vertex ranges
    vertex_bins = pd.cut(df['vertices'], bins=5, labels=['100-130', '130-160', '160-190', '190-220', '220-280'])
    df_binned = df.copy()
    df_binned['vertex_range'] = vertex_bins
    
    ax7 = plt.subplot(3, 3, 7)
    df_binned.boxplot(column='h0_time', by='vertex_range', ax=ax7)
    plt.xlabel('Vertex Range')
    plt.ylabel('H0 Time (s)')
    plt.title('H0 Time Distribution by Vertex Range')
    plt.yscale('log')
    plt.suptitle('')  # Remove automatic title
    
    ax8 = plt.subplot(3, 3, 8)
    df_binned.boxplot(column='h1_time', by='vertex_range', ax=ax8)
    plt.xlabel('Vertex Range')
    plt.ylabel('H1 Time (s)')
    plt.title('H1 Time Distribution by Vertex Range')
    plt.yscale('log')
    plt.suptitle('')  # Remove automatic title
    
    ax9 = plt.subplot(3, 3, 9)
    df_binned.boxplot(column='total_time', by='vertex_range', ax=ax9)
    plt.xlabel('Vertex Range')
    plt.ylabel('Total Time (s)')
    plt.title('Total Time Distribution by Vertex Range')
    plt.yscale('log')
    plt.suptitle('')  # Remove automatic title
    
    plt.tight_layout(pad=2.0)
    plt.show()
    
    # Create 3D surface plots
    fig2 = plt.figure(figsize=(15, 5))
    
    # Prepare data for 3D plotting
    vertices_unique = sorted(df['vertices'].unique())
    edge_probs_unique = sorted(df['edge_probability'].unique())
    
    # Create meshgrids for interpolation if needed
    from scipy.interpolate import griddata
    
    for i, (time_col, title) in enumerate([('h0_time', 'H0'), ('h1_time', 'H1'), ('total_time', 'Total')]):
        ax = fig2.add_subplot(1, 3, i+1, projection='3d')
        
        # Create 3D scatter plot
        scatter = ax.scatter(df['vertices'], df['edge_probability'], df[time_col], 
                           c=df[time_col], cmap='viridis', alpha=0.7, s=50)
        
        ax.set_xlabel('Vertices')
        ax.set_ylabel('Edge Probability')
        ax.set_zlabel(f'{title} Time (s)')
        ax.set_title(f'{title} Computation Time 3D View')
        ax.set_zscale('log')
        
        fig2.colorbar(scatter, ax=ax, shrink=0.5, aspect=5)
    
    plt.tight_layout()
    plt.show()
    
    # Print some statistics
    print("Data Summary:")
    print(f"Total graphs processed: {len(df)}")
    print(f"Vertex range: {df['vertices'].min()} - {df['vertices'].max()}")
    print(f"Edge probability range: {df['edge_probability'].min():.4f} - {df['edge_probability'].max():.4f}")
    print("\nTime statistics:")
    print(df[['h0_time', 'h1_time', 'total_time']].describe())
    
    print("\nCorrelation with vertices:")
    print(f"H0 time correlation: {df['vertices'].corr(df['h0_time']):.3f}")
    print(f"H1 time correlation: {df['vertices'].corr(df['h1_time']):.3f}")
    print(f"Total time correlation: {df['vertices'].corr(df['total_time']):.3f}")
    
    print("\nCorrelation with edge probability:")
    print(f"H0 time correlation: {df['edge_probability'].corr(df['h0_time']):.3f}")
    print(f"H1 time correlation: {df['edge_probability'].corr(df['h1_time']):.3f}")
    print(f"Total time correlation: {df['edge_probability'].corr(df['total_time']):.3f}")

def main():
    """Main function to run the analysis."""
    filename = 'parallel_simp_test.txt'
    
    try:
        # Parse the data
        df = parse_homology_data(filename)
        print(f"Successfully parsed {len(df)} graphs from {filename}")
        
        # Create visualizations
        create_visualizations(df, filename)
        
        # Save processed data to CSV for future use
        df.to_csv('homology_data_processed.csv', index=False)
        print("\nProcessed data saved to 'homology_data_processed.csv'")
        
    except FileNotFoundError:
        print(f"Error: Could not find file '{filename}'")
        print("Please make sure the file is in the same directory as this script.")
    except Exception as e:
        print(f"Error processing data: {e}")

if __name__ == "__main__":
    main()
