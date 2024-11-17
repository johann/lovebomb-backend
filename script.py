import os
import shutil
from pathlib import Path
import datetime
import hashlib

def convert_elixir_to_txt(source_dir, output_dir):
    """
    Convert all Elixir files (.ex and .exs) to .txt files in a single output directory
    
    Args:
        source_dir (str): Source directory to start from
        output_dir (str): Output directory for the converted files
    """
    # Create the output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    # Create a log file
    log_path = os.path.join(output_dir, '_conversion_log.txt')
    processed_files = set()  # Keep track of processed files to handle duplicates
    
    with open(log_path, 'w', encoding='utf-8') as log:
        log.write(f"Elixir Files Conversion Log\n")
        log.write(f"Generated on: {datetime.datetime.now()}\n")
        log.write(f"Source directory: {os.path.abspath(source_dir)}\n")
        log.write(f"Output directory: {os.path.abspath(output_dir)}\n\n")

        # Walk through the directory
        for root, dirs, files in os.walk(source_dir):
            # Remove deps directory from dirs to prevent walking into it
            if 'deps' in dirs:
                dirs.remove('deps')
            
            for file in files:
                # Only process .ex and .exs files
                if not (file.endswith('.ex') or file.endswith('.exs')):
                    continue
                
                source_file = os.path.join(root, file)
                base_name = Path(file).stem
                original_ext = Path(file).suffix
                
                # Create a filename safe version of the base name
                safe_name = "".join(c if c.isalnum() or c in ('-', '_') else '_' for c in base_name)
                safe_name = f"{safe_name}{original_ext}"
                
                # Add .txt extension
                new_filename = f"{safe_name}.txt"
                
                # If filename already exists, add a hash of the path
                if new_filename in processed_files:
                    path_hash = hashlib.md5(source_file.encode()).hexdigest()[:8]
                    new_filename = f"{safe_name}_{path_hash}.txt"
                
                processed_files.add(new_filename)
                output_file = os.path.join(output_dir, new_filename)
                
                try:
                    # Try to read the source file
                    with open(source_file, 'r', encoding='utf-8', errors='replace') as src:
                        content = src.read()
                        
                        # Write to new txt file with metadata header
                        with open(output_file, 'w', encoding='utf-8') as dst:
                            # Write detailed metadata header
                            dst.write("="*80 + "\n")
                            dst.write("FILE METADATA\n")
                            dst.write("="*80 + "\n")
                            dst.write(f"Original filename: {file}\n")
                            dst.write(f"Original path: {os.path.relpath(source_file, source_dir)}\n")
                            dst.write(f"Original extension: {original_ext}\n")
                            dst.write(f"Conversion date: {datetime.datetime.now()}\n")
                            dst.write("="*80 + "\n\n")
                            dst.write(content)
                        
                        log.write(f"SUCCESS: {source_file} -> {new_filename}\n")
                
                except Exception as e:
                    log.write(f"ERROR converting {source_file}: {str(e)}\n")

def main():
    # Get current directory as source
    source_dir = "."
    
    # Create output directory name
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    output_dir = f"elixir_txt_{timestamp}"
    
    # Run the conversion
    convert_elixir_to_txt(source_dir, output_dir)
    
    print(f"Elixir files have been converted to text format in: {output_dir}")
    print("Check _conversion_log.txt in the output directory for details")

if __name__ == "__main__":
    main()