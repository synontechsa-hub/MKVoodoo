import os
import codecs

root_dir = r'd:\Coding\SynonTech\MKVoodoo'

replacements = [
    ('MKVoodoo', 'MKVoodoo'),
    ('mkvoodoo', 'mkvoodoo'),
    ('MKVOODOO', 'MKVOODOO'),
    ('Mkvoodoo', 'Mkvoodoo')
]

for root, dirs, files in os.walk(root_dir):
    if any(x in root for x in ['.git', '.dart_tool', 'build', '.venv', '__pycache__', 'scratch', 'logs']):
        continue
        
    for f in files:
        if not f.endswith(('.py', '.dart', '.md', '.txt', '.html', '.yaml', '.toml', '.json', '.bat', '.xml', '.plist', '.pbxproj', '.cc', '.cpp', '.rc', '.xcconfig', '.xcscheme', '.h', '.c', '.gradle', '.kts', '.properties')):
            continue
            
        filepath = os.path.join(root, f)
        try:
            with codecs.open(filepath, 'r', 'utf-8') as file:
                content = file.read()
                
            new_content = content
            for old, new in replacements:
                new_content = new_content.replace(old, new)
                
            if new_content != content:
                with codecs.open(filepath, 'w', 'utf-8') as file:
                    file.write(new_content)
                print(f"Updated {filepath}")
        except Exception as e:
            print(f"Failed to process {filepath}: {e}")
