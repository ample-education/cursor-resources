INSTRUCTIONS:

- add the following to ur .zshrc or whatever u use
- add export ANTHROPIC_API_KEY="ur_anthropic_api_key" above that
- source then run 'tokens "pasted text" image.png example.pdf test.py' or whatever u want


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
