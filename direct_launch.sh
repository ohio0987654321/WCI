#!/bin/bash
# WindowControlInjector Direct Launch Script
# This script launches applications with the WCI library injected
# It ensures each launch is a new instance with improved screen recording protection

# Function to show usage instructions
show_usage() {
    echo "Usage: $0 [options] <application_path>"
    echo ""
    echo "Options:"
    echo "  --invisible     Make windows invisible to screen recording"
    echo "  --stealth       Hide application from Dock and status bar"
    echo "  --unfocusable   Prevent windows from receiving focus"
    echo "  --click-through Make windows click-through (ignore mouse events)"
    echo "  --all           Apply all profiles"
    echo ""
    echo "Example:"
    echo "  $0 --invisible --stealth /Applications/TextEdit.app"
    exit 1
}

# Check if we have enough arguments
if [ $# -lt 2 ]; then
    show_usage
fi

# Get the absolute path to the directory containing this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Find the dylib
DYLIB_PATH="$SCRIPT_DIR/build/libwindow_control.dylib"
if [ ! -f "$DYLIB_PATH" ]; then
    echo "Error: Cannot find libwindow_control.dylib at $DYLIB_PATH"
    echo "Make sure to build the project first."
    exit 1
fi

# Parse arguments to collect profiles
PROFILES=""
APP_PATH=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --invisible)
            if [ -z "$PROFILES" ]; then
                PROFILES="invisible"
            else
                PROFILES="$PROFILES,invisible"
            fi
            shift
            ;;
        --stealth)
            if [ -z "$PROFILES" ]; then
                PROFILES="stealth"
            else
                PROFILES="$PROFILES,stealth"
            fi
            shift
            ;;
        --unfocusable)
            if [ -z "$PROFILES" ]; then
                PROFILES="unfocusable"
            else
                PROFILES="$PROFILES,unfocusable"
            fi
            shift
            ;;
        --click-through)
            if [ -z "$PROFILES" ]; then
                PROFILES="click_through"
            else
                PROFILES="$PROFILES,click_through"
            fi
            shift
            ;;
        --all)
            PROFILES="invisible,stealth,unfocusable,click_through"
            shift
            ;;
        --help)
            show_usage
            ;;
        *)
            # The last parameter should be the application path
            APP_PATH="$1"
            shift
            ;;
    esac
done

# Verify we have an application path
if [ -z "$APP_PATH" ]; then
    echo "Error: No application path provided"
    show_usage
fi

# Verify the application exists
if [ ! -d "$APP_PATH" ]; then
    echo "Error: Application not found at $APP_PATH"
    exit 1
fi

# Setup environment variables
export DYLD_INSERT_LIBRARIES="$DYLIB_PATH"

if [ ! -z "$PROFILES" ]; then
    export WCI_PROFILES="$PROFILES"
    echo "Applying profiles: $PROFILES"
fi

# Launch the application with the -n flag to force a new instance
echo "Launching $APP_PATH with WindowControlInjector..."
/usr/bin/open -n -a "$APP_PATH"

echo "Application launched!"
echo "If you need to debug issues, check the log file at ~/wci_debug.log"
