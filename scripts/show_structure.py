from pathlib import Path


def show_structure(directory, prefix="", ignore_dirs=None):
    """Shows directory structure"""
    if ignore_dirs is None:
        ignore_dirs = {
            "__pycache__",
            "venv",
            ".git",
            "node_modules",
            "staticfiles",
            "media",
        }

    items = []
    try:
        items = sorted(
            Path(directory).iterdir(), key=lambda x: (not x.is_dir(), x.name)
        )
    except PermissionError:
        return

    for index, item in enumerate(items):
        if item.name in ignore_dirs or item.name.startswith("."):
            continue

        is_last = index == len(items) - 1
        current_prefix = "└── " if is_last else "├── "
        print(f"{prefix}{current_prefix}{item.name}")

        if item.is_dir():
            extension = "    " if is_last else "│   "
            show_structure(item, prefix + extension, ignore_dirs)


if __name__ == "__main__":
    print("📁 Maintenance System - Project Structure\n")
    print("maintenance_system/")
    show_structure(
        ".", ignore_dirs={"__pycache__", "venv", ".git", "staticfiles", "media"}
    )

    print("\n" + "=" * 60)
    print("📊 Statistics:")
    print("=" * 60)

    # Count files
    py_files = list(Path(".").rglob("*.py"))
    html_files = list(Path(".").rglob("*.html"))

    print(f"Python files: {len([f for f in py_files if 'venv' not in str(f)])}")
    print(f"HTML templates: {len([f for f in html_files if 'venv' not in str(f)])}")
    print(
        f"Apps: {len([d for d in Path('apps').iterdir() if d.is_dir() and not d.name.startswith('.')])}"
    )
