#!/usr/bin/env python3
"""
Script to extract vehicle images from SQL Server database and display them in VS Code.

Requirements:
    pip install pyodbc pillow

Usage:
    python view_car_images.py
"""

import pyodbc
import sys
import os

# Database connection configuration
SERVER = 'localhost'
DATABASE = 'POC25'
USERNAME = 'sa'
PASSWORD = 'YourPassword'  # Update with your password


def get_connection():
    """Create and return database connection."""
    try:
        # Try Windows Authentication first
        conn_str = f'DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={SERVER};DATABASE={DATABASE};Trusted_Connection=yes;'
        try:
            conn = pyodbc.connect(conn_str)
            print(f"✓ Connected to {DATABASE} using Windows Authentication")
            return conn
        except:
            # Fall back to SQL Server authentication
            conn_str = f'DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={SERVER};DATABASE={DATABASE};UID={USERNAME};PWD={PASSWORD}'
            conn = pyodbc.connect(conn_str)
            print(f"✓ Connected to {DATABASE} using SQL Server Authentication")
            return conn
    except Exception as e:
        print(f"✗ Error connecting to database: {e}")
        sys.exit(1)


def extract_images():
    """Extract all car images from database and save to files."""
    conn = get_connection()
    cursor = conn.cursor()
    
    # Create Images directory if it doesn't exist
    images_dir = '/workspaces/Project25/Images'
    os.makedirs(images_dir, exist_ok=True)
    print(f"✓ Images directory: {images_dir}")
    
    # Query to get all cars with images
    cursor.execute("""
        SELECT MotID, VIN, ImageURL, ImageBlob, DATALENGTH(ImageBlob) AS ImageSize
        FROM dbo.MeansOfTransportation
        WHERE ImageBlob IS NOT NULL
        ORDER BY MotID
    """)
    
    rows = cursor.fetchall()
    
    if not rows:
        print("\n⚠ No images found in database.")
        print("To load images, use the LoadImageFromFile stored procedure or load_images.py script.")
        cursor.close()
        conn.close()
        return
    
    print(f"\n✓ Found {len(rows)} vehicle(s) with images\n")
    
    saved_files = []
    
    for row in rows:
        mot_id = row.MotID
        vin = row.VIN
        image_url = row.ImageURL
        image_blob = row.ImageBlob
        image_size = row.ImageSize
        
        # Determine file extension from URL or default to .jpg
        if image_url:
            ext = os.path.splitext(image_url)[1] or '.jpg'
        else:
            ext = '.jpg'
        
        # Create filename
        filename = f"Car{mot_id}_{vin.replace('-', '_')}{ext}"
        filepath = os.path.join(images_dir, filename)
        
        # Save image to file
        try:
            with open(filepath, 'wb') as f:
                f.write(image_blob)
            
            saved_files.append(filepath)
            print(f"  MotID {mot_id} ({vin}): {filename} - {image_size:,} bytes")
            
        except Exception as e:
            print(f"  ✗ Error saving MotID {mot_id}: {e}")
    
    cursor.close()
    conn.close()
    
    # Display summary
    print(f"\n{'='*60}")
    print(f"✓ Successfully extracted {len(saved_files)} image(s)")
    print(f"{'='*60}\n")
    
    # Print file paths for easy opening
    if saved_files:
        print("Saved files:")
        for filepath in saved_files:
            print(f"  {filepath}")
        
        print(f"\nTo view images in VS Code:")
        print(f"  1. Open the Images folder in the Explorer")
        print(f"  2. Click on any image file to preview it")
        print(f"\nOr open the first image directly:")
        print(f"  code {saved_files[0]}")


if __name__ == '__main__':
    print("="*60)
    print("Vehicle Image Extractor - View images from SQL Server")
    print("="*60)
    extract_images()
