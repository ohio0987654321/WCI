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

# Target archs for universal binary
ARCHS = x86_64 arm64 arm64e
ARCH_FLAGS = $(foreach arch,$(ARCHS),-arch $(arch))

# Version information
VERSION = 1.1.0
BUILD_DATE = $(shell date +"%Y-%m-%d")
GIT_COMMIT = $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")

VERSION_FLAGS = -DVERSION=\"$(VERSION)\" -DBUILD_DATE=\"$(BUILD_DATE)\" -DGIT_COMMIT=\"$(GIT_COMMIT)\"

# Code signing
CODESIGN = codesign
CODESIGN_IDENTITY = -
ENTITLEMENTS = entitlements.plist

# Default target
all: directories $(LIB_DIR)/$(LIB_NAME) $(BIN_DIR)/$(BIN_NAME)

# Create necessary directories
directories:
	@mkdir -p $(OBJ_DIR)/$(SRC_DIR)/core
	@mkdir -p $(OBJ_DIR)/$(SRC_DIR)/interceptors
	@mkdir -p $(OBJ_DIR)/$(SRC_DIR)/util
	@mkdir -p $(LIB_DIR)
	@mkdir -p $(BIN_DIR)
	@mkdir -p backup/core
	@mkdir -p backup/interceptors
	@mkdir -p backup/util

# Compile source files
$(OBJ_DIR)/%.o: %.m
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(OBJCFLAGS) $(ARCH_FLAGS) $(VERSION_FLAGS) -I$(INCLUDE_DIR) -I$(SRC_DIR) -c $< -o $@

# Link library
$(LIB_DIR)/$(LIB_NAME): $(LIB_OBJS)
	$(CC) $(LDFLAGS_LIB) $(ARCH_FLAGS) -o $@ $^
	@echo "Library built at: $@"
	@install_name_tool -id "@rpath/$(LIB_NAME)" $@
	$(CODESIGN) --force --options=runtime --sign $(CODESIGN_IDENTITY) --entitlements $(ENTITLEMENTS) $@
	@echo "Library signed with entitlements"

# Link executable
$(BIN_DIR)/$(BIN_NAME): $(MAIN_OBJ) $(LIB_DIR)/$(LIB_NAME)
	$(CC) $(CFLAGS) $(ARCH_FLAGS) -o $@ $(MAIN_OBJ) $(LDFLAGS_BIN) -L$(LIB_DIR) -lwindowcontrolinjector
	@echo "Executable built at: $@"
	@install_name_tool -add_rpath @executable_path/lib $@
	$(CODESIGN) --force --options=runtime --sign $(CODESIGN_IDENTITY) --entitlements $(ENTITLEMENTS) $@
	@echo "Executable signed with entitlements"

# Debug build
debug: CFLAGS += -DDEBUG -g3 -O0
debug: all

# Release build
release: CFLAGS += -DNDEBUG -Os
release: all
	@dsymutil $(LIB_DIR)/$(LIB_NAME)
	@strip -x $(LIB_DIR)/$(LIB_NAME)
	@dsymutil $(BIN_DIR)/$(BIN_NAME)
	@strip -x $(BIN_DIR)/$(BIN_NAME)

# Create distribution package
dist: release
	@mkdir -p $(BUILD_DIR)/WindowControlInjector-$(VERSION)
	@cp $(BIN_DIR)/$(BIN_NAME) $(BUILD_DIR)/WindowControlInjector-$(VERSION)/
	@mkdir -p $(BUILD_DIR)/WindowControlInjector-$(VERSION)/lib
	@cp $(LIB_DIR)/$(LIB_NAME) $(BUILD_DIR)/WindowControlInjector-$(VERSION)/lib/
	@cp README.md $(BUILD_DIR)/WindowControlInjector-$(VERSION)/ 2>/dev/null || echo "No README.md found"
	@cp LICENSE $(BUILD_DIR)/WindowControlInjector-$(VERSION)/ 2>/dev/null || echo "No LICENSE found"
	@cd $(BUILD_DIR) && zip -r WindowControlInjector-$(VERSION).zip WindowControlInjector-$(VERSION)
	@echo "Distribution package created at: $(BUILD_DIR)/WindowControlInjector-$(VERSION).zip"

# Install
install: all
	@mkdir -p ~/Library/Application\ Support/WindowControlInjector
	@cp $(LIB_DIR)/$(LIB_NAME) ~/Library/Application\ Support/WindowControlInjector/
	@cp $(BIN_DIR)/$(BIN_NAME) ~/Library/Application\ Support/WindowControlInjector/
	@echo "Installed to: ~/Library/Application Support/WindowControlInjector/"

# Restore files from backup if needed
restore:
	# Check if backup files exist
	@if [ -d backup ]; then \
		echo "Restoring files from backup..."; \
		mkdir -p src/util src/interceptors; \
		cp -n backup/util/* src/util/ 2>/dev/null || true; \
		cp -n backup/interceptors/* src/interceptors/ 2>/dev/null || true; \
		echo "Files restored from backup."; \
	else \
		echo "No backup directory found."; \
	fi

# Clean
clean:
	rm -rf $(BUILD_DIR)
	@echo "Build directory cleaned"

# Help
help:
	@echo "WindowControlInjector $(VERSION) ($(BUILD_DATE), commit: $(GIT_COMMIT))"
	@echo ""
	@echo "Available targets:"
	@echo "  all      - Build library and executable (default)"
	@echo "  debug    - Build with debug information"
	@echo "  release  - Build optimized version"
	@echo "  dist     - Create distribution package"
	@echo "  install  - Install to ~/Library/Application Support/WindowControlInjector/"
	@echo "  clean    - Remove build files"
	@echo "  help     - Show this help message"
	@echo "  restore   - Restore original files from backup if needed"

.PHONY: all directories debug release dist install clean help restore
