# Anthropic Token Counter

A command-line utility to count Claude API tokens in text files, directories, and direct input.

## Features

- Count tokens for text files, directories, and direct input
- Handles multiple files and directories recursively
- Skips binary files and excluded paths automatically
- Provides detailed token count and size information

## Prerequisites

- `curl`
- `jq`
- `file`
- `tr`
- `base64`
- `numfmt`
- `perl`
- Optional: `pdftotext` (from poppler-utils) for PDF support

## Installation

### Method 1: Direct Usage

1. Clone or download this repository
2. Make the script executable:
   ```bash
   chmod +x tokens.sh
   ```
3. Set up your API key (see Configuration section below)
4. Run the script directly:
   ```bash
   ./tokens.sh "some text" file.txt directory/
   ```

### Method 2: System-wide Installation

1. Copy the script to your local bin directory:
   ```bash
   cp tokens.sh ~/.local/bin/tokens
   chmod +x ~/.local/bin/tokens
   ```
   Note: Ensure `~/.local/bin` is in your PATH. If not, add this to your shell config file:
   ```bash
   export PATH="$HOME/.local/bin:$PATH"
   ```

2. Set up your API key (see Configuration section below)
3. Use the command from anywhere:
   ```bash
   tokens "some text" file.txt directory/
   ```

## Configuration

There are two ways to configure your Anthropic API key:

### Method 1: Environment Variable (Recommended)

Add this to your shell configuration file (`~/.bashrc`, `~/.zshrc`, etc.):
```bash
export ANTHROPIC_API_KEY="sk-ant-xxxx..."
```

Then reload your shell configuration:
```bash
source ~/.bashrc  # or ~/.zshrc
```

### Method 2: Command Line

Pass the API key directly when running the command:
```bash
tokens --api-key "sk-ant-xxxx..." "some text" file.txt
```

## Usage

```bash
# Count tokens in text
tokens "Hello, world!"

# Count tokens in a file
tokens path/to/file.txt

# Count tokens in multiple files
tokens file1.txt file2.txt file3.txt

# Count tokens in a directory (recursive)
tokens path/to/directory/

# Mix different input types
tokens "direct text" file.txt directory/

# Using with API key flag
tokens --api-key "sk-ant-xxxx..." file.txt
```

## Output

The script provides:
- Progress updates for each processed file
- File sizes in human-readable format
- Total number of files processed
- Total bytes processed
- Final token count

## Notes

- The script automatically skips binary files and certain paths (e.g., `venv` directories)
- Large files are processed in chunks to stay within API limits
- PDF support requires the `pdftotext` utility (install via poppler-utils package)