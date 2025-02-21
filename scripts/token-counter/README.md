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


---


```bash
# Token counting function
function tokens() {
    # Check if any arguments were provided
    if [ $# -eq 0 ]; then
        echo "Usage: tokens <text or files...>"
        return 1
    fi

    # Initialize empty content array
    local -a content_parts=()
    
    # Process each argument
    for arg in "$@"; do
        if [ -f "$arg" ]; then
            # Check file type
            local file_type=$(file -b --mime-type "$arg")
            
            case "$file_type" in
                image/*)
                    # Handle images by base64 encoding them
                    local base64_data=$(base64 < "$arg" | tr -d '\n')
                    if [ $? -eq 0 ]; then
                        content_parts+=("{\"type\": \"image\", \"source\": {\"type\": \"base64\", \"media_type\": \"$file_type\", \"data\": \"$base64_data\"}}")
                    else
                        echo "Error: Failed to encode image: $arg"
                        return 1
                    fi
                    ;;
                application/pdf)
                    if command -v pdftotext > /dev/null; then
                        content_parts+=("$(pdftotext "$arg" -)")
                    else
                        echo "Error: pdftotext not installed"
                        return 1
                    fi
                    ;;
                application/x-executable|application/x-archive|application/x-compress|application/x-compressed|application/zip)
                    echo "Error: Binary file not supported: $arg"
                    return 1
                    ;;
                *)
                    # Attempt to read as text
                    if content_temp=$(cat "$arg" 2>/dev/null); then
                        content_parts+=("$content_temp")
                    else
                        echo "Error: Unable to read file: $arg"
                        return 1
                    fi
                    ;;
            esac
        else
            # If it's not a file, treat it as direct text input
            content_parts+=("$arg")
        fi
    done

    # Join all parts with newlines and escape for JSON
    local content=$(printf "%s\n" "${content_parts[@]}" | jq -Rs .)

    # Create JSON payload using printf for better control
    local json_payload=$(printf '{
    "model": "claude-3-5-sonnet-20241022",
    "system": "You are a scientist",
    "messages": [{
        "role": "user",
        "content": %s
    }]
}' "$content")

    # Make API call
    local response=$(curl -s https://api.anthropic.com/v1/messages/count_tokens \
        --header "x-api-key: $ANTHROPIC_API_KEY" \
        --header "content-type: application/json" \
        --header "anthropic-version: 2023-06-01" \
        --data "$json_payload")

    # Extract token count or error
    if echo "$response" | grep -q '"input_tokens":[0-9]*'; then
        echo "Input Tokens: $(echo $response | grep -o '"input_tokens":[0-9]*' | cut -d':' -f2)"
    elif echo "$response" | grep -q '"error":{'; then
        echo "Error: $(echo $response | jq -r '.error.message')"
    else
        echo "Error: Unexpected API response"
    fi
}
```
