# WindowControlInjector Makefile

# Compiler and flags
CC = clang
CFLAGS = -Wall -Wextra -pedantic -fPIC -g -O2
OBJCFLAGS = -fobjc-arc
LDFLAGS_LIB = -dynamiclib -framework Foundation -framework AppKit -framework CoreGraphics
LDFLAGS_BIN = -framework Foundation -framework AppKit -framework CoreGraphics

# Directories
SRC_DIR = src
BUILD_DIR = build
LIB_DIR = $(BUILD_DIR)/lib
BIN_DIR = $(BUILD_DIR)
OBJ_DIR = $(BUILD_DIR)/obj
INCLUDE_DIR = include

# Source files
CORE_SRC = $(wildcard $(SRC_DIR)/core/*.m)
INTERCEPTORS_SRC = $(wildcard $(SRC_DIR)/interceptors/*.m)
UTIL_SRC = $(wildcard $(SRC_DIR)/util/*.m)
MAIN_SRC = $(SRC_DIR)/main.m

LIB_SRC = $(CORE_SRC) $(INTERCEPTORS_SRC) $(UTIL_SRC)

# Object files
LIB_OBJS = $(patsubst %.m,$(OBJ_DIR)/%.o,$(LIB_SRC))
MAIN_OBJ = $(patsubst %.m,$(OBJ_DIR)/%.o,$(MAIN_SRC))

# Target names
LIB_NAME = libwindowcontrolinjector.dylib
BIN_NAME = injector

# Define the WC_ prefixed files (use these variables for documentation purposes)
WC_CORE_FILES = $(SRC_DIR)/core/wc_window_bridge.m \
                $(SRC_DIR)/core/wc_window_info.m \
                $(SRC_DIR)/core/wc_window_scanner.m \
                $(SRC_DIR)/core/wc_window_protector.m \
                $(SRC_DIR)/core/wc_injector_config.m

WC_UTIL_FILES = $(SRC_DIR)/util/wc_cgs_functions.m \
                $(SRC_DIR)/util/wc_cgs_types.h

# Target archs for universal binary
ARCHS = arm64 arm64e x86_64
ARCH_FLAGS = $(foreach arch,$(ARCHS),-arch $(arch))

# Code signing
CODESIGN = codesign
CODESIGN_IDENTITY = -
ENTITLEMENTS = entitlements.plist

# Default target
all: directories $(LIB_DIR)/$(LIB_NAME) $(BIN_DIR)/$(BIN_NAME)

# Create necessary directories
directories:
	@mkdir -p $(OBJ_DIR)/$(SRC_DIR)/core $(OBJ_DIR)/$(SRC_DIR)/interceptors $(OBJ_DIR)/$(SRC_DIR)/util
	@mkdir -p $(LIB_DIR) $(BIN_DIR)

# Compile source files
$(OBJ_DIR)/%.o: %.m
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(OBJCFLAGS) $(ARCH_FLAGS) -I$(INCLUDE_DIR) -I$(SRC_DIR) -c $< -o $@

# Link library
$(LIB_DIR)/$(LIB_NAME): $(LIB_OBJS)
	$(CC) $(LDFLAGS_LIB) $(ARCH_FLAGS) -o $@ $^
	@echo "Library built at: $@"
	@install_name_tool -id "@rpath/$(LIB_NAME)" $@
	$(CODESIGN) --force --options=runtime --sign $(CODESIGN_IDENTITY) --entitlements $(ENTITLEMENTS) $@

# Link executable
$(BIN_DIR)/$(BIN_NAME): $(MAIN_OBJ) $(LIB_DIR)/$(LIB_NAME)
	$(CC) $(CFLAGS) $(ARCH_FLAGS) -o $@ $(MAIN_OBJ) $(LDFLAGS_BIN) -L$(LIB_DIR) -lwindowcontrolinjector
	@echo "Executable built at: $@"
	@install_name_tool -add_rpath @executable_path/lib $@
	$(CODESIGN) --force --options=runtime --sign $(CODESIGN_IDENTITY) --entitlements $(ENTITLEMENTS) $@

# Release build (optimized)
release: CFLAGS += -DNDEBUG -Os
release: all
	@dsymutil $(LIB_DIR)/$(LIB_NAME)
	@strip -x $(LIB_DIR)/$(LIB_NAME)
	@dsymutil $(BIN_DIR)/$(BIN_NAME)
	@strip -x $(BIN_DIR)/$(BIN_NAME)
	@echo "Release build complete"

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)
	@echo "Build directory cleaned"

# Help information
help:
	@echo "WindowControlInjector"
	@echo ""
	@echo "Available targets:"
	@echo "  all      - Build library and executable (default)"
	@echo "  release  - Build optimized version"
	@echo "  clean    - Remove build files"
	@echo "  help     - Show this help message"

.PHONY: all directories release clean help
