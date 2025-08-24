#!/bin/bash

# Evolution Mapper - Stop Frontend and Backend Servers
# This script stops both the R Plumber backend and React frontend servers

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

# Function to check if a port is in use
check_port() {
    local port=$1
    if lsof -ti:$port >/dev/null 2>&1; then
        return 0  # Port is in use
    else
        return 1  # Port is free
    fi
}

# --- NEW: argument parsing ---
PLUMBER=false
REACT=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --plumber)
            PLUMBER=true
            ;;
        --react)
            REACT=true
            ;;
        *)
            error "Unknown option: $1"
            exit 1
            ;;
    esac
    shift
done

# If neither flag is set, stop both
if [[ $PLUMBER == false && $REACT == false ]]; then
    PLUMBER=true
    REACT=true
fi

main() {
    echo -e "${BLUE}🛑 Evolution Mapper Server Shutdown${NC}"
    echo "===================================="
    
    # Show current environment info if available
    if [[ -f "evolution-mapper-frontend/.env" ]]; then
        local local_url=$(grep "^LOCAL_REACT_APP_BACKEND_URL=" evolution-mapper-frontend/.env | cut -d'=' -f2)
        echo "📍 Development environment: $local_url"
    fi
    
    # Stop backend if requested
    if [[ $PLUMBER == true ]]; then
        if [[ -f "backend.pid" ]]; then
            BACKEND_PID=$(cat backend.pid)
            if kill -0 $BACKEND_PID 2>/dev/null; then
                log "Stopping backend server (PID: $BACKEND_PID)..."
                kill $BACKEND_PID 2>/dev/null && success "Backend server stopped" || warning "Backend server may already be stopped"
            else
                warning "Backend process (PID: $BACKEND_PID) not found"
            fi
            rm -f backend.pid
        fi
        
        if check_port 8000; then
            warning "Found processes still using port 8000, force killing..."
            lsof -ti:8000 | xargs kill -9 2>/dev/null || true
        fi
    fi
    
    # Stop frontend if requested
    if [[ $REACT == true ]]; then
        if [[ -f "frontend.pid" ]]; then
            FRONTEND_PID=$(cat frontend.pid)
            if kill -0 $FRONTEND_PID 2>/dev/null; then
                log "Stopping frontend server (PID: $FRONTEND_PID)..."
                kill $FRONTEND_PID 2>/dev/null && success "Frontend server stopped" || warning "Frontend server may already be stopped"
            else
                warning "Frontend process (PID: $FRONTEND_PID) not found"
            fi
            rm -f frontend.pid
        fi
        
        if check_port 3000; then
            warning "Found processes still using port 3000, force killing..."
            lsof -ti:3000 | xargs kill -9 2>/dev/null || true
        fi
    fi
    
    # Wait a moment for cleanup
    sleep 2
    
    # Final verification
    local all_good=true
    if [[ $PLUMBER == true ]] && check_port 8000; then
        error "Port 8000 still in use"
        all_good=false
    fi
    if [[ $REACT == true ]] && check_port 3000; then
        error "Port 3000 still in use"
        all_good=false
    fi
    
    if [[ $all_good == true ]]; then
        success "Selected servers stopped successfully!"
    fi
    
    # Log files info
    if [[ -f "backend.log" || -f "frontend.log" ]]; then
        echo ""
        echo "📝 Log files preserved:"
        [[ -f "backend.log" && $PLUMBER == true ]] && echo "   Backend logs: ./backend.log"
        [[ -f "frontend.log" && $REACT == true ]] && echo "   Frontend logs: ./frontend.log"
        echo ""
        echo "To clean up log files, run: rm -f backend.log frontend.log"
    fi
}

# Run main function
main
