#!/usr/bin/env python3
"""
Add libtdjson.dylib to the Xcode project.
This script modifies the project.pbxproj file to include libtdjson.dylib
in the frameworks and embed it in the app bundle.
"""

import re
import sys
import uuid
from pathlib import Path

def generate_xcode_uuid():
    """Generate a 24-character hex UUID for Xcode."""
    return uuid.uuid4().hex[:24].upper()

def add_libtdjson_to_project(pbxproj_path):
    """Add libtdjson.dylib to the Xcode project."""

    with open(pbxproj_path, 'r') as f:
        content = f.read()

    # Generate UUIDs for the new entries
    file_ref_uuid = generate_xcode_uuid()
    build_file_uuid = generate_xcode_uuid()
    embed_uuid = generate_xcode_uuid()
    frameworks_uuid = generate_xcode_uuid()

    print(f"Generated UUIDs:")
    print(f"  File Reference: {file_ref_uuid}")
    print(f"  Build File: {build_file_uuid}")
    print(f"  Embed: {embed_uuid}")
    print(f"  Frameworks: {frameworks_uuid}")

    # Check if libtdjson is already in the project
    if 'libtdjson.dylib' in content:
        print("libtdjson.dylib already exists in project, skipping...")
        return False

    # 1. Add PBXBuildFile entries
    build_file_section = re.search(r'/\* Begin PBXBuildFile section \*/', content)
    if not build_file_section:
        print("ERROR: Could not find PBXBuildFile section")
        return False

    insert_pos = build_file_section.end()
    build_file_entries = f"""
\t\t{build_file_uuid} /* libtdjson.dylib in Frameworks */ = {{isa = PBXBuildFile; fileRef = {file_ref_uuid} /* libtdjson.dylib */; }};
\t\t{embed_uuid} /* libtdjson.dylib in Embed Libraries */ = {{isa = PBXBuildFile; fileRef = {file_ref_uuid} /* libtdjson.dylib */; settings = {{ATTRIBUTES = (CodeSignOnCopy, RemoveHeadersOnCopy, ); }}; }};"""

    content = content[:insert_pos] + build_file_entries + content[insert_pos:]

    # 2. Add PBXFileReference entry
    file_ref_section = re.search(r'/\* Begin PBXFileReference section \*/', content)
    if not file_ref_section:
        print("ERROR: Could not find PBXFileReference section")
        return False

    insert_pos = file_ref_section.end()
    file_ref_entry = f"""
\t\t{file_ref_uuid} /* libtdjson.dylib */ = {{isa = PBXFileReference; includeInIndex = 1; lastKnownFileType = "compiled.mach-o.dylib"; name = libtdjson.dylib; path = "../build/tdlib-phase0/ios-sim/libtdjson.dylib"; sourceTree = "<group>"; }};"""

    content = content[:insert_pos] + file_ref_entry + content[insert_pos:]

    # 3. Add to Frameworks group (find the frameworks group and add the file reference)
    # Look for a pattern like: files = ( ... /* frameworks */ );
    frameworks_group = re.search(r'([A-F0-9]{24}) /\* frameworks \*/ = \{[^}]+files = \([^)]+\);', content, re.DOTALL)
    if frameworks_group:
        group_content = frameworks_group.group(0)
        # Find the files array closing
        files_close = group_content.rfind(');')
        if files_close != -1:
            # Insert before the closing
            insert_text = f"\n\t\t\t\t{file_ref_uuid} /* libtdjson.dylib */,"
            new_group = group_content[:files_close] + insert_text + group_content[files_close:]
            content = content.replace(group_content, new_group)

    # 4. Add to PBXFrameworksBuildPhase (link the library) - for ALL targets
    frameworks_phases = re.finditer(r'([A-F0-9]{24}) /\* Frameworks \*/ = \{[^}]+isa = PBXFrameworksBuildPhase;[^}]+files = \([^)]+\);', content, re.DOTALL)
    for frameworks_phase in frameworks_phases:
        phase_content = frameworks_phase.group(0)
        files_close = phase_content.rfind(');')
        if files_close != -1:
            insert_text = f"\n\t\t\t\t{build_file_uuid} /* libtdjson.dylib in Frameworks */,"
            new_phase = phase_content[:files_close] + insert_text + phase_content[files_close:]
            content = content.replace(phase_content, new_phase)

    # 5. Add to Embed Libraries phase
    embed_phase = re.search(r'([A-F0-9]{24}) /\* Embed Libraries \*/ = \{[^}]+isa = PBXCopyFilesBuildPhase;[^}]+files = \([^)]+\);', content, re.DOTALL)
    if embed_phase:
        phase_content = embed_phase.group(0)
        files_close = phase_content.rfind(');')
        if files_close != -1:
            insert_text = f"\n\t\t\t\t{embed_uuid} /* libtdjson.dylib in Embed Libraries */,"
            new_phase = phase_content[:files_close] + insert_text + phase_content[files_close:]
            content = content.replace(phase_content, new_phase)

    # Write back
    with open(pbxproj_path, 'w') as f:
        f.write(content)

    print(f"Successfully added libtdjson.dylib to {pbxproj_path}")
    return True

def main():
    script_dir = Path(__file__).parent
    project_file = script_dir.parent / "ios" / "cjmp.xcodeproj" / "project.pbxproj"

    if not project_file.exists():
        print(f"ERROR: Project file not found: {project_file}")
        sys.exit(1)

    # Backup the original file
    backup_file = project_file.with_suffix('.pbxproj.backup')
    import shutil
    shutil.copy2(project_file, backup_file)
    print(f"Created backup: {backup_file}")

    success = add_libtdjson_to_project(project_file)

    if success:
        print("\n✓ libtdjson.dylib has been added to the Xcode project")
        print("  The library will be linked and embedded in the app bundle")
    else:
        print("\n✗ Failed to add libtdjson.dylib")
        sys.exit(1)

if __name__ == "__main__":
    main()
