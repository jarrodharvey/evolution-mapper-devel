#!/bin/bash

# Script to show detailed chronological git commit history for both frontend and backend projects

echo "========================================="
echo "GIT COMMIT HISTORY - EVOLUTION MAPPER"
echo "========================================="

# Get the base directory
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define project directories
FRONTEND_DIR="$BASE_DIR/evolution-mapper-frontend"
BACKEND_DIR="$BASE_DIR/evolution-mapper-backend"

echo ""
echo "Frontend Project: $FRONTEND_DIR"
echo "Backend Project: $BACKEND_DIR"
echo ""

# Function to display commits for a project using git show
show_project_commits() {
    local project_dir="$1"
    local project_name="$2"
    
    echo "========================================="
    echo "$project_name COMMITS"
    echo "========================================="
    echo ""
    
    if [ -d "$project_dir/.git" ]; then
        cd "$project_dir"
        
        # Get list of commit hashes in chronological order (oldest first)
        git log --pretty=format:"%H" --all --reverse | while read -r hash; do
            if [ -n "$hash" ]; then
                echo "========================================================================"
                echo "PROJECT: $project_name"
                echo "COMMIT:  $hash"
                echo "DATE:    $(git show -s --format="%ad" --date=format:"%Y-%m-%d %H:%M:%S" "$hash")"
                echo "AUTHOR:  $(git show -s --format="%an <%ae>" "$hash")"
                echo "------------------------------------------------------------------------"
                echo "SUBJECT: $(git show -s --format="%s" "$hash")"
                
                # Get commit body
                body=$(git show -s --format="%b" "$hash")
                if [ -n "$body" ] && [ "$body" != "" ]; then
                    echo ""
                    echo "MESSAGE:"
                    echo "$body" | sed 's/^/  /'
                fi
                
                echo "========================================================================"
                echo ""
            fi
        done
    else
        echo "No git repository found in $project_dir"
        echo ""
    fi
}

# Function to get timestamped commit info for sorting
get_timestamped_commits() {
    local project_dir="$1"
    local project_name="$2"
    
    if [ -d "$project_dir/.git" ]; then
        cd "$project_dir"
        git log --pretty=format:"%ai|$project_name|%H" --all
    fi
}

echo "Collecting commit history..."
echo ""

# Show commits for both projects separately
show_project_commits "$FRONTEND_DIR" "FRONTEND"
show_project_commits "$BACKEND_DIR" "BACKEND"

# Now show combined chronological view
echo "========================================="
echo "COMBINED CHRONOLOGICAL VIEW (OLDEST TO NEWEST)"
echo "========================================="
echo ""

# Create temporary file for combined view
TEMP_FILE=$(mktemp)

# Get timestamped commits from both projects
get_timestamped_commits "$FRONTEND_DIR" "FRONTEND" >> "$TEMP_FILE"
get_timestamped_commits "$BACKEND_DIR" "BACKEND" >> "$TEMP_FILE"

# Sort by timestamp in chronological order (oldest first)
sort "$TEMP_FILE" | while IFS='|' read -r timestamp project hash; do
    if [ -n "$hash" ] && [ "$hash" != "" ]; then
        # Change to appropriate directory
        if [ "$project" = "FRONTEND" ]; then
            cd "$FRONTEND_DIR"
        else
            cd "$BACKEND_DIR"
        fi
        
        echo "========================================================================"
        echo "PROJECT: $project"
        echo "COMMIT:  $hash"
        echo "DATE:    $(git show -s --format="%ad" --date=format:"%Y-%m-%d %H:%M:%S" "$hash")"
        echo "AUTHOR:  $(git show -s --format="%an <%ae>" "$hash")"
        echo "------------------------------------------------------------------------"
        echo "SUBJECT: $(git show -s --format="%s" "$hash")"
        
        # Get commit body
        body=$(git show -s --format="%b" "$hash")
        if [ -n "$body" ] && [ "$body" != "" ]; then
            echo ""
            echo "MESSAGE:"
            echo "$body" | sed 's/^/  /'
        fi
        
        echo "========================================================================"
        echo ""
    fi
done

# Clean up
rm -f "$TEMP_FILE"

echo "========================================="
echo "ADDITIONAL COMMANDS:"
echo "========================================="
echo "View git log with graph for frontend:"
echo "  cd $FRONTEND_DIR && git log --oneline --graph --decorate"
echo ""
echo "View git log with graph for backend:"
echo "  cd $BACKEND_DIR && git log --oneline --graph --decorate"