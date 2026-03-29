"""
Batch fix admin pages navigation - Remove custom back buttons
"""

import re
from pathlib import Path

# List of remaining admin pages to fix
ADMIN_PAGES = [
    "amenity_bookings_admin_page.dart",
    "concierge_requests_admin_page.dart",
    "fee_types_admin_page.dart",
    "meter_readings_admin_page.dart",
    "parking_plans_admin_page.dart",
    "parking_passes_admin_page.dart",
    "payment_qr_admin_page.dart",
    "vehicles_admin_page.dart",
    "visitors_admin_page.dart",
]

BASE_DIR = Path(r"d:\icitizen_app\lib\features\manager")

def fix_file(filepath):
    """Fix a single admin page file"""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Pattern 1: Find and remove custom back button in header
    # Looking for IconButton with Navigator.pop
    pattern_back_button = r'Row\(\s*children:\s*\[\s*IconButton\(\s*onPressed:\s*\(\)\s*=>\s*Navigator\.of\(context\)\.pop\(\),.*?\],\s*\),\s*const SizedBox\(height:\s*\d+\),'
    
    # Pattern 2: Add AppBar if not exists
    pattern_scaffold = r'(@override\s+Widget build\(BuildContext context\)\s*\{\s*return Scaffold\(\s*backgroundColor:\s*\w+,)'
    
    # Check if appBar already exists
    if 'appBar: AppBar(' not in content:
        # Add AppBar after Scaffold
        replacement_scaffold = r'\1\n      appBar: AppBar(\n        title: Text(\'Admin Page\', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),\n        backgroundColor: _primaryColor,\n        foregroundColor: Colors.white,\n        elevation: 0,\n      ),'
        content = re.sub(pattern_scaffold, replacement_scaffold, content, flags=re.DOTALL)
    
    # Remove custom back button
    content = re.sub(pattern_back_button, '', content, flags=re.DOTALL)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"Fixed: {filepath.name}")

def main():
    for page_name in ADMIN_PAGES:
        filepath = BASE_DIR / page_name
        if filepath.exists():
            try:
                fix_file(filepath)
            except Exception as e:
                print(f"Error fixing {page_name}: {e}")
        else:
            print(f"File not found: {filepath}")

if __name__ == "__main__":
    main()
    print("\nBatch fix completed!")
