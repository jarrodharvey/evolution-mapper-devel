#!/bin/bash

# Evolution Mapper - Start Frontend and Backend Servers
# This script starts both the R Plumber backend (port 8000) and React frontend (port 3000)
# and ensures they can communicate with each other.

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Log function
log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
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

# Function to wait for server to be ready
wait_for_server() {
    local url=$1
    local name=$2
    local max_attempts=30
    local attempt=1
    
    log "Waiting for $name to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s "$url" >/dev/null 2>&1; then
            success "$name is ready!"
            return 0
        fi
        
        printf "   Attempt $attempt/$max_attempts...\r"
        sleep 2
        attempt=$((attempt + 1))
    done
    
    error "$name failed to start within $((max_attempts * 2)) seconds"
    return 1
}

# Function to get API key from frontend .env file
get_api_key() {
    local env_file="evolution-mapper-frontend/.env"
    if [[ -f "$env_file" ]]; then
        grep "^REACT_APP_API_KEY=" "$env_file" | cut -d'=' -f2 | tr -d '"' | tr -d "'"
    else
        echo "demo-key-12345"
    fi
}

# Function to test connectivity between frontend and backend
test_connectivity() {
    log "Testing connectivity between frontend and backend..."
    
    # Get API key from frontend environment
    local api_key=$(get_api_key)
    log "Using API key: ${api_key:0:10}..."
    
    # Test backend health endpoint
    if curl -s -H "X-API-Key: $api_key" "http://localhost:8000/api/health" >/dev/null 2>&1; then
        success "Backend API is responding"
    else
        error "Backend API health check failed"
        return 1
    fi
    
    # Test a simple API endpoint
    if curl -s -H "X-API-Key: $api_key" "http://localhost:8000/api/species?search=human&limit=1" >/dev/null 2>&1; then
        success "Backend species endpoint is responding"
    else
        error "Backend species endpoint failed"
        return 1
    fi
    
    # Test frontend
    if curl -s "http://localhost:3000" >/dev/null 2>&1; then
        success "Frontend is responding"
    else
        error "Frontend health check failed"
        return 1
    fi
    
    success "All connectivity tests passed!"
}

# Main script
main() {
    echo -e "${BLUE}🚀 Evolution Mapper Server Startup${NC}"
    echo "=================================="
    
    # Check if we're in the right directory
    if [[ ! -d "evolution-mapper-backend" || ! -d "evolution-mapper-frontend" ]]; then
        error "Please run this script from the evolution-mapper root directory"
        exit 1
    fi
    
    # Kill existing processes on ports 8000 and 3000
    log "Cleaning up existing processes..."
    
    if check_port 8000; then
        warning "Port 8000 is in use, killing existing processes..."
        lsof -ti:8000 | xargs kill -9 2>/dev/null || true
        sleep 2
    fi
    
    if check_port 3000; then
        warning "Port 3000 is in use, killing existing processes..."
        lsof -ti:3000 | xargs kill -9 2>/dev/null || true
        sleep 2
    fi
    
    # Start backend server
    log "Starting R Plumber backend server on port 8000..."
    cd evolution-mapper-backend
    
    # Check if R is available
    if ! command -v R &> /dev/null; then
        error "R is not installed or not in PATH"
        exit 1
    fi
    
    # Start R server in background
    nohup R -e "library(plumber); pr('plumber.R') %>% pr_run(port = 8000)" > ../backend.log 2>&1 &
    BACKEND_PID=$!
    echo $BACKEND_PID > ../backend.pid
    
    cd ..
    
    # Wait for backend to be ready
    if ! wait_for_server "http://localhost:8000/api/health" "Backend"; then
        error "Backend server failed to start"
        exit 1
    fi
    
    # Start frontend server
    log "Starting React frontend server on port 3000..."
    cd evolution-mapper-frontend
    
    # Check if npm is available
    if ! command -v npm &> /dev/null; then
        error "npm is not installed or not in PATH"
        exit 1
    fi
    
    # Check environment configuration
    if [[ -f ".env" ]]; then
        local local_url=$(grep "^LOCAL_REACT_APP_BACKEND_URL=" .env | cut -d'=' -f2)
        local do_url=$(grep "^DIGITAL_OCEAN_REACT_APP_BACKEND_URL=" .env | cut -d'=' -f2)
        local api_key=$(grep "^REACT_APP_API_KEY=" .env | cut -d'=' -f2)
        
        success "Environment configuration found:"
        echo "   Local Backend URL: $local_url"
        echo "   DO Backend URL: $do_url"
        echo "   API Key: ${api_key:0:10}..."
    else
        warning ".env file not found - using default configuration"
    fi
    
    # Check if node_modules exists
    if [[ ! -d "node_modules" ]]; then
        warning "node_modules not found, running npm install..."
        npm install
    fi
    
    # Start frontend in background
    nohup npm start > ../frontend.log 2>&1 &
    FRONTEND_PID=$!
    echo $FRONTEND_PID > ../frontend.pid
    
    cd ..
    
    # Wait for frontend to be ready
    if ! wait_for_server "http://localhost:3000" "Frontend"; then
        error "Frontend server failed to start"
        exit 1
    fi
    
    # Test connectivity
    if ! test_connectivity; then
        error "Connectivity tests failed"
        exit 1
    fi
    
    # Success message
    echo ""
    success "🎉 Both servers are running successfully!"
    echo ""
    echo "📍 Server URLs:"
    echo "   Frontend (React):     http://localhost:3000"
    echo "   Backend API:          http://localhost:8000"
    echo "   API Documentation:    http://localhost:8000/__docs__/"
    echo ""
    echo "🔧 Process Information:"
    echo "   Backend PID:  $BACKEND_PID"
    echo "   Frontend PID: $FRONTEND_PID"
    echo ""
    echo "📋 Available API Endpoints:"
    echo "   • GET  /api/health           - Health check"
    echo "   • GET  /api/species          - Search species" 
    echo "   • POST /api/tree             - Generate tree from species list"
    echo "   • GET  /api/random-tree      - Generate random tree"
    echo ""
    echo "📝 Log Files:"
    echo "   Backend logs: ./backend.log"
    echo "   Frontend logs: ./frontend.log"
    echo ""
    echo "🛑 To stop servers:"
    echo "   kill \$(cat backend.pid frontend.pid) 2>/dev/null || true"
    echo "   # Or use: ./stop_servers.sh (if you create it)"
}

# Run main function
main "$@"