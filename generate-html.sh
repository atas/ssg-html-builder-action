#!/bin/bash

# Create a symbolic link to the current directory
# if it doesn't exist
if [[ ! -L "/workspace" ]]; then
    echo "Creating symbolic link /workspace to $(pwd)"
    ln -s "$(pwd)" /workspace
fi

# Check if php-fpm is running
if ! pgrep "php-fpm" >/dev/null; then
    php-fpm -D
fi

# Check if nginx is running
if ! pgrep "nginx" >/dev/null; then
    service nginx start
fi

# Curl the URL $1 and save it to $2
function curl_and_save() {
    echo "curl_and_save https://localhost$1 > $2"
    curl -ks --fail "https://localhost$1" >"$2"

    # Check if the file exists and is not zero bytes
    if [[ ! -s $2 ]]; then
        echo "Error: The file does not exist or is zero bytes."
        exit 1
    fi

    # Check if file exists
    if [[ ! -e "$2" ]]; then
        echo "Error: File $2 does not exist."
        exit 1
    fi

    # Check if file size is zero
    if [[ ! -s "$2" ]]; then
        echo "Error: File $2 is empty."
        exit 1
    fi
}

#region Building HTML files
rm -rf html
mkdir -p html
chmod 777 tmp

touch build.lock # we are running the build process.
trap "rm -rf build.lock" EXIT

curl_and_save "/" "html/index.html"

# pages/*.md HTML BUilding
for file in pages/*.md; do
    filename=$(basename "$file" .md)
    curl_and_save "/$filename" "html/$filename.html"
done

# posts/*.md HTML Building
mkdir -p html/p
for file in posts/*.md; do
    filename=$(basename "$file" .md)
    slug=$(awk -F': ' '/^slug:|^[ \t]*"slug":/ {gsub(/["\r]/, "", $2); print $2}' "$file")
    curl_and_save "/p/$slug" "html/p/$slug.html"
done

# **/*.php Any php file HTML Building
find . -name "*.php" ! -path "./system/*" ! -path "./vendor/*" ! -path "./layout/*" | while read -r file; do
    file="${file#./}" #Remove the leading ./
    #pages and posts are handled above separately
    if [[ "$file" == "page.php" || "$file" == "post.php" || "$file" == "index.php" ]]; then
        continue
    fi

    without_extension="${file%.*}"
    # Replace the .php extension with .txt
    html_file="html/${file%.php}.html"

    # Create the directory structure if it doesn't exist
    mkdir -p "$(dirname "$html_file")"

    filename=$(basename "$file" .php)
    curl_and_save "/$without_extension" "$html_file"
done

#endregion

# ./assets/* copying to ./html
cp -R assets html/assets

#region less
if [[ -n "$LESS_FILE_PATH" ]]; then
    echo "Compiling less at $LESS_FILE_PATH"
    lessc html/"$LESS_FILE_PATH" html/"${LESS_FILE_PATH%.less}".css
    rm -f html/assets/styles/*.less
else
    echo "Skipping less as LESS_FILE_PATH is not set"
fi
#endregion

# Robots.txt is good to have
cp robots.txt html/
