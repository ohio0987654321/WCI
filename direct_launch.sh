#!/bin/bash
# direct_launch.sh - Quick launcher for WindowControlInjector with direct-control profile
# This script makes it easy to inject the direct-control profile into any macOS application

# Display colored output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Print usage
function print_usage {
    echo -e "${BOLD}Usage:${NC} ./direct_launch.sh <application_path>"
    echo
    echo -e "${BOLD}Examples:${NC}"
    echo "  ./direct_launch.sh /Applications/TextEdit.app"
    echo "  ./direct_launch.sh /Applications/Calculator.app"
    echo
    echo -e "${BOLD}Description:${NC}"
    echo "  This script launches the specified application with the advanced direct-control"
    echo "  profile applied, which provides enhanced screen recording protection,"
    echo "  stealth mode, and click-through capabilities."
    echo
    echo -e "${YELLOW}Note: You may need to run this script with sudo for some applications.${NC}"
}

# Check if we have enough arguments
if [ $# -lt 1 ]; then
    echo -e "${RED}Error: No application path provided.${NC}"
    print_usage
    exit 1
fi

APP_PATH="$1"

# Check if the application exists
if [ ! -e "$APP_PATH" ]; then
    echo -e "${RED}Error: Application not found at '$APP_PATH'${NC}"
    exit 1
fi

# Build directory where the injector binary should be
BUILD_DIR="./build"
INJECTOR_PATH="$BUILD_DIR/injector"

# Check if the injector binary exists
if [ ! -x "$INJECTOR_PATH" ]; then
    echo -e "${YELLOW}Building WindowControlInjector...${NC}"
    make

    # Check if build was successful
    if [ ! -x "$INJECTOR_PATH" ]; then
        echo -e "${RED}Error: Failed to build WindowControlInjector.${NC}"
        echo "Try running 'make' manually to see the error."
        exit 1
    fi
fi

# Launch the application with direct-control profile
echo -e "${BLUE}Launching ${BOLD}$(basename "$APP_PATH")${NC}${BLUE} with direct-control profile...${NC}"
"$INJECTOR_PATH" --direct-control --verbose "$APP_PATH"

# Check exit status
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Successfully launched application with direct-control profile.${NC}"
else
    echo -e "${RED}Failed to launch application with direct-control profile.${NC}"
    echo "Check the error message above for details."
    exit 1
fi

exit 0
