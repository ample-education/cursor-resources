#!/usr/bin/env bash

# Ensure we're running in bash and preserve environment
if [ -z "$BASH_VERSION" ]; then
  # Get the real path of the script
  SCRIPT_PATH=$(readlink -f "$0")
  env ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" exec bash "$SCRIPT_PATH" "$@"
fi

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Constants
MAX_BYTES_PER_REQUEST=8000000  # Stay under the 9MB limit
MAX_CHUNK_SIZE=50000  # For string handling

# Validate and set API key
validate_api_key() {
    # Check if ANTHROPIC_API_KEY is set via environment
    local api_key="${ANTHROPIC_API_KEY}"
    if [[ "$1" == "--api-key" && -n "$2" ]]; then
        api_key="$2"
        shift 2
    fi

    if [ -z "$api_key" ]; then
        echo -e "${RED}Error:${NC} ANTHROPIC_API_KEY not set. Please set it using:"
        echo "export ANTHROPIC_API_KEY=\"sk-ant-...\"" 
        echo "or pass it directly:"
        echo "tokens --api-key \"sk-ant-...\" <files...>"
        return 1
    fi

    # Updated API key validation to be more permissive
    if [[ ! "$api_key" =~ ^sk-ant- ]]; then
        echo -e "${RED}Error:${NC} Invalid API key format. API key should start with 'sk-ant-'"
        return 1
    fi

    echo "$api_key"
    return 0
}

# Function to check if path should be excluded
is_excluded_path() {
    local path="$1"
    
    # Exclude any directory containing 'venv' in its name
    if [[ "$path" =~ /venv[^a-zA-Z0-9]* || "$path" =~ /sw_venv[^a-zA-Z0-9]* ]]; then
        return 0
    fi
    
    return 1
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    # Required dependencies
    if ! command -v curl >/dev/null; then
        missing_deps+=("curl")
    fi
    if ! command -v jq >/dev/null; then
        missing_deps+=("jq")
    fi
    if ! command -v file >/dev/null; then
        missing_deps+=("file")
    fi
    if ! command -v tr >/dev/null; then
        missing_deps+=("tr")
    fi
    if ! command -v base64 >/dev/null; then
        missing_deps+=("base64")
    fi
    if ! command -v numfmt >/dev/null; then
        missing_deps+=("numfmt")
    fi
    if ! command -v perl >/dev/null; then
        missing_deps+=("perl")
    fi

    # Optional dependencies with warnings
    if ! command -v pdftotext >/dev/null; then
        echo -e "${YELLOW}Warning:${NC} 'pdftotext' not found. PDF processing will be skipped."
        echo -e "${YELLOW}Warning:${NC} Install poppler-utils package to enable PDF support."
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "${RED}Error:${NC} Missing required dependencies: ${missing_deps[*]}"
        echo "Please install them using your package manager:"
        echo "For Ubuntu/Debian: sudo apt-get install ${missing_deps[*]}"
        echo "For MacOS: brew install ${missing_deps[*]}"
        exit 1
    fi
}

# Make API request with content chunk
make_api_request() {
    local content="$1"
    local api_key="$2"
    
    # Create temporary file for JSON payload
    local tmp_file=$(mktemp)
    
    # Write JSON payload to temp file
    echo "{\"model\":\"claude-3-haiku-20240307\",\"messages\":[{\"role\":\"user\",\"content\":$content}]}" > "$tmp_file"

    # Make API call using the temp file with updated headers
    local response=$(curl -s https://api.anthropic.com/v1/messages/count_tokens \
        --header "x-api-key: $api_key" \
        --header "anthropic-version: 2023-06-01" \
        --header "content-type: application/json" \
        --data @"$tmp_file")

    # Clean up temp file
    rm -f "$tmp_file"

    # Add small delay to respect rate limits
    sleep 0.05

    if echo "$response" | grep -q '"input_tokens":[0-9]*'; then
        echo "$response" | grep -o '"input_tokens":[0-9]*' | cut -d':' -f2
    elif echo "$response" | grep -q '"error":{'; then
        echo -e "${RED}Error:${NC} $(echo $response | jq -r '.error.message')" >&2
        echo "0"
    else
        echo -e "${RED}Error:${NC} Unexpected API response" >&2
        echo -e "${RED}Response:${NC} $response" >&2
        echo "0"
    fi
}

# Function to check if a file is text
is_text_file() {
    local file="$1"
    local mime_type
    local file_output
    
    # Get MIME type
    mime_type=$(file -b --mime-type "$file")
    file_output=$(file -b "$file")
    
    # Common text file extensions
    if [[ "$file" =~ \.(txt|md|sh|bash|json|xml|yaml|yml|conf|cfg|ini|log|properties|dart|cpp|h|cc|java|kt|swift|cmake|rc|manifest|plist|pbxproj|storyboard|xib|xcscheme|xcconfig|xcworkspacedata|gradle|iml)$ ]]; then
        return 0
    fi
    
    # Check MIME type
    if [[ "$mime_type" =~ ^text/ ]] || \
       [[ "$mime_type" == "application/json" ]] || \
       [[ "$mime_type" == "application/xml" ]] || \
       [[ "$mime_type" == "application/x-yaml" ]] || \
       [[ "$mime_type" == "application/javascript" ]] || \
       [[ "$mime_type" == "application/x-shellscript" ]]; then
        return 0
    fi
    
    # Additional checks for text files that might be misidentified
    if [[ "$file_output" =~ "ASCII text" ]] || \
       [[ "$file_output" =~ "Unicode text" ]] || \
       [[ "$file_output" =~ "UTF-8 text" ]]; then
        return 0
    fi
    
    # Check if file is not binary using grep
    if grep -qI . "$file" 2>/dev/null; then
        return 0
    fi
    
    return 1
}

# Function to collect file content
collect_file_content() {
    local file="$1"
    local results_file="$2"
    local file_size
    local content
    
    # Check if file should be excluded
    if is_excluded_path "$file"; then
        echo -e "${YELLOW}Skipping excluded path: $(basename "$file")${NC}"
        return
    fi
    
    # Get file size
    file_size=$(wc -c < "$file")
    total_bytes=$((total_bytes + file_size))
    
    # Skip empty files
    if [ "$file_size" -eq 0 ]; then
        echo -e "${YELLOW}Warning: Empty file skipped: $(basename "$file")${NC}"
        return
    fi
    
    # Check if file is text
    if ! is_text_file "$file"; then
        echo -e "${YELLOW}Warning: Binary file skipped: $(basename "$file")${NC}"
        return
    fi
    
    # Read file content
    content=$(<"$file")
    
    # Skip if content is empty
    if [ -z "$content" ]; then
        echo -e "${YELLOW}Warning: Empty content skipped: $(basename "$file")${NC}"
        return
    fi
    
    processed_files=$((processed_files + 1))
    valid_content_found=true
    
    # Append to results file with file info
    printf "%s\t%d\t%s\n" "$content" "$file_size" "$file" >> "$results_file"
    echo -e "${GREEN}Successfully read file: $(basename "$file") ($(numfmt --to=iec-i --suffix=B $file_size))${NC}"
}

# Token counting function
tokens() {
    # Check dependencies first
    check_dependencies

    # Validate API key
    local api_key=$(validate_api_key "$@")
    if [ $? -ne 0 ]; then
        return 1
    fi

    # Check if any arguments were provided
    if [ $# -eq 0 ]; then
        echo "Usage: tokens [--api-key YOUR_API_KEY] <text, files, or directories...>"
        return 1
    fi

    # Initialize counters
    local total_bytes=0
    local processed_files=0
    local total_tokens=0
    local valid_content_found=false
    
    # Create temporary file for collecting content
    local content_file=$(mktemp)
    
    echo "Collecting file contents..."

    # Process each argument
    for arg in "$@"; do
        if [ -d "$arg" ]; then
            # Handle directories recursively, but skip excluded directories entirely
            while IFS= read -r file; do
                collect_file_content "$file" "$content_file"
            done < <(find "$arg" -type f -not -path "*/venv/*" -not -path "*/sw_venv/*")
        elif [ -f "$arg" ]; then
            collect_file_content "$arg" "$content_file"
        else
            # If it's not a file or directory, treat it as direct text input
            local bytes=${#arg}
            total_bytes=$((total_bytes + bytes))
            processed_files=$((processed_files + 1))
            valid_content_found=true
            printf "%s\t%d\t%s\n" "$arg" "$bytes" "<direct-input>" >> "$content_file"
        fi
    done

    if [ "$valid_content_found" = true ]; then
        echo "Processing content in chunks..."
        
        # Initialize chunk variables
        local chunk=""
        local chunk_size=0
        local max_chunk_size=1000000 # ~1MB chunks to be safe
        local total_size=0
        
        # Read and process content in chunks
        while IFS=$'\t' read -r content size file; do
            # Skip empty or invalid lines
            if [ -z "$content" ] || [ -z "$size" ] || ! [[ "$size" =~ ^[0-9]+$ ]]; then
                continue
            fi
            
            # Calculate new chunk size
            local new_size=$((${#chunk} + ${#content}))
            
            # If adding this content would exceed max chunk size, process current chunk first
            if [ -n "$chunk" ] && [ "$new_size" -gt "$max_chunk_size" ]; then
                chunk_size=${#chunk}
                echo "Processing chunk ($(numfmt --to=iec-i --suffix=B $chunk_size))..."
                local escaped_chunk=$(echo "$chunk" | jq -Rs .)
                local tokens=$(make_api_request "$escaped_chunk" "$api_key")
                total_tokens=$((total_tokens + tokens))
                chunk=""
            fi
            
            # Add content to current chunk
            chunk+="$content"
            total_size=$((total_size + size))
        done < "$content_file"
        
        # Process final chunk if any
        if [ -n "$chunk" ]; then
            chunk_size=${#chunk}
            echo "Processing final chunk ($(numfmt --to=iec-i --suffix=B $chunk_size))..."
            local escaped_chunk=$(echo "$chunk" | jq -Rs .)
            local tokens=$(make_api_request "$escaped_chunk" "$api_key")
            total_tokens=$((total_tokens + tokens))
        fi
    fi

    # Print summary
    echo -e "\nSummary:"
    echo "Total files processed: $processed_files"
    echo "Total bytes processed: $(numfmt --to=iec-i --suffix=B $total_bytes)"
    if [ "$valid_content_found" = true ]; then
        echo "Total tokens: $total_tokens"
    else
        echo "Warning: No valid content found to process"
    fi
    
    # Cleanup
    rm -f "$content_file"
}

# Call the tokens function with all script arguments
tokens "$@"