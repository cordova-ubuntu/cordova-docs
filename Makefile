# Function Reference:
# 	https://www.gnu.org/software/make/manual/html_node/Text-Functions.html
#  	https://www.gnu.org/software/make/manual/html_node/File-Name-Functions.html
# Variable Reference:
# 	https://www.gnu.org/software/make/manual/html_node/Automatic-Variables.html

# Makefile's own config
ifeq ($(OS),Windows_NT)
WINDOWS=1
endif

ifdef WINDOWS
SHELL  = cmd
JEKYLL = jekyll.bat
MKDIRP = mkdir
else
SHELL  = sh
JEKYLL = jekyll
MKDIRP = mkdir -p
endif

# constants
EMPTY =
SPACE = $(EMPTY) $(EMPTY)
COMMA = ,

VERSION_VAR_NAME = latest_docs_version

# paths and files
BIN_DIR      = tools/bin
NODE_BIN_DIR = ./node_modules/.bin

SRC_DIR  = www
DEV_DIR  = build-dev
PROD_DIR = build-prod

DOCS_DIR         = $(SRC_DIR)/docs
DATA_DIR         = $(SRC_DIR)/_data
TOC_DIR          = $(DATA_DIR)/toc
STATIC_DIR       = $(SRC_DIR)/static
CSS_SRC_DIR      = $(STATIC_DIR)/css-src
CSS_DEST_DIR     = $(STATIC_DIR)/css
PLUGINS_SRC_DIR  = $(STATIC_DIR)/plugins
PLUGINS_DEST_DIR = $(STATIC_DIR)/js

# executables
NODE       = node
GULP       = $(NODE_BIN_DIR)/gulp
LESSC      = $(NODE_BIN_DIR)/lessc
SASSC      = $(NODE_BIN_DIR)/node-sass
BROWSERIFY = $(NODE_BIN_DIR)/browserify
UGLIFY     = $(NODE_BIN_DIR)/uglifyjs

# replace slashes in executables on Windows
ifdef WINDOWS
GULP       := $(subst /,\,$(GULP))
LESSC      := $(subst /,\,$(LESSC))
SASSC      := $(subst /,\,$(SASSC))
BROWSERIFY := $(subst /,\,$(BROWSERIFY))
UGLIFY     := $(subst /,\,$(UGLIFY))
endif

# existing files
MAIN_CONFIG         = _config.yml
DEV_CONFIG          = _dev.yml
PROD_CONFIG         = _prod.yml
DOCS_EXCLUDE_CONFIG = _nodocs.yml
PLUGINS_SRC         = $(PLUGINS_SRC_DIR)/app.js
VERSION_FILE        = VERSION

# NOTE:
#      the .scss files are separate because they combine into MAIN_STYLE_FILE,
#      which includes them on its own, and the SCSS compiler takes care of them;
#      because of this, there is also no .scss -> .css pattern rule
ifdef WINDOWS
SCSS_SRC   = $(shell cd $(CSS_SRC_DIR) && dir *.scss /S /B)
STYLES_SRC = $(shell cd $(CSS_SRC_DIR) && dir *.less *.css /S /B)
else
SCSS_SRC   = $(shell find $(CSS_SRC_DIR) -name "*.scss")
STYLES_SRC = $(shell find $(CSS_SRC_DIR) -name "*.less" -or -name "*.css")
endif

# generated files
VERSION_CONFIG  = _version.yml
DEFAULTS_CONFIG = _defaults.yml
LANGUAGES_DATA  = $(DATA_DIR)/languages.yml
PLUGINS_APP     = $(PLUGINS_DEST_DIR)/plugins.js
MAIN_STYLE_FILE = $(CSS_DEST_DIR)/main.css

STYLES = $(MAIN_STYLE_FILE) $(addsuffix .css,$(basename $(subst $(CSS_SRC_DIR),$(CSS_DEST_DIR),$(STYLES_SRC))))

# NOTE:
#      docs slugs are lang/version pairs, with "/" and "." replaced by "-"
DOCS_VERSION_DIRS  = $(wildcard $(DOCS_DIR)/**/*)
DOCS_VERSION_SLUGS = $(subst /,-,$(subst .,-,$(subst $(DOCS_DIR)/,,$(DOCS_VERSION_DIRS))))
TOC_FILES          = $(addprefix $(TOC_DIR)/,$(addsuffix -generated.yml,$(DOCS_VERSION_SLUGS)))

# variables
# NOTE:
#      the order of config files matters to Jekyll
JEKYLL_CONFIGS = $(MAIN_CONFIG) $(DEFAULTS_CONFIG) $(VERSION_CONFIG)

ifdef WINDOWS
LATEST_DOCS_VERSION = $(shell type $(VERSION_FILE))
else
LATEST_DOCS_VERSION = $(shell cat $(VERSION_FILE))
endif

# convenience targets
help usage default:
	@echo ""
	@echo "Usage:"
	@echo ""
	@echo "    make dev:     build site with dev config"
	@echo "    make prod:    build site with prod config"
	@echo "    make install: install dependencies"
	@echo ""
	@echo "    make data:    generate data files (Generated ToCs, $(LANGUAGES_DATA))"
	@echo "    make configs: generate Jekyll configs ($(DEFAULTS_CONFIG), $(VERSION_CONFIG))"
	@echo "    make styles:  generate CSS"
	@echo "    make plugins: generate plugins app ($(PLUGINS_APP))"
	@echo ""
	@echo "    make clean:   remove all generated output"
	@echo "    make nuke:    run 'make clean' and remove all dependencies"
	@echo ""
	@echo "Arguments:"
	@echo ""
	@echo "    NODOCS: (defined or undefined) - excludes docs from build"
	@echo ""

debug:
	@echo "LATEST_DOCS_VERSION: " $(LATEST_DOCS_VERSION)
	@echo ""
	@echo "OS: " $(OS)
	@echo ""
	@echo "SCSS_SRC: " $(SCSS_SRC)
	@echo ""
	@echo "STYLES_SRC: " $(STYLES_SRC)
	@echo ""
	@echo "TOC_FILES: " $(TOC_FILES)
	@echo ""
	@echo "MKDIRP: " $(MKDIRP)
	@echo ""

data: $(TOC_FILES) $(LANGUAGES_DATA)
configs: $(DEFAULTS_CONFIG) $(VERSION_CONFIG)
styles: $(STYLES)
plugins: $(PLUGINS_APP)

dev: JEKYLL_CONFIGS += $(DEV_CONFIG)
dev: JEKYLL_FLAGS += --trace
dev: DEBUG = 1

prod: JEKYLL_CONFIGS += $(PROD_CONFIG)
prod: JEKYLL_FLAGS +=
prod: DEBUG =

dev prod: build

ifdef NODOCS
build: JEKYLL_CONFIGS += $(DOCS_EXCLUDE_CONFIG)
endif

build: JEKYLL_FLAGS += --config $(subst $(SPACE),$(COMMA),$(strip $(JEKYLL_CONFIGS)))
build: $(JEKYLL_CONFIGS) $(TOC_FILES) $(LANGUAGES_DATA) $(STYLES) $(PLUGINS_APP)
	$(JEKYLL) build $(JEKYLL_FLAGS)

install:
	bundle install
	npm install

serve:
	cd $(DEV_DIR) && python -m SimpleHTTPServer 8000

# real targets
# NOTE:
#      the ">>" operator appends to a file in both CMD and SH
$(PLUGINS_APP): $(PLUGINS_SRC) Makefile
	echo ---> $@
	echo --->> $@
	$(BROWSERIFY) -t reactify -t envify $< | $(UGLIFY) >> $@

$(LANGUAGES_DATA): $(BIN_DIR)/gen_languages.js Makefile
	$(NODE) $(BIN_DIR)/gen_languages.js $(DOCS_DIR) > $@

$(DEFAULTS_CONFIG): $(BIN_DIR)/gen_defaults.js $(VERSION_FILE) Makefile
	$(NODE) $(BIN_DIR)/gen_defaults.js $(DOCS_DIR) "$(LATEST_DOCS_VERSION)" > $@

$(VERSION_CONFIG): $(VERSION_FILE) Makefile
	sed -e "s/^/$(VERSION_VAR_NAME): /" < $< > $@

$(TOC_FILES): $(BIN_DIR)/toc.js Makefile
	$(NODE) $(BIN_DIR)/toc.js $(DOCS_DIR) $(DATA_DIR)

$(MAIN_STYLE_FILE): $(SCSS_SRC)

# pattern rules

# NODE:
#      $(@D) means "directory part of target"
$(CSS_DEST_DIR)/%.css: $(CSS_SRC_DIR)/%.less Makefile
ifdef WINDOWS
	-$(MKDIRP) $(subst /,\,$(@D))
else
	$(MKDIRP) $(@D)
endif
	echo ---> $@
	echo --->> $@
	$(LESSC) $< >> $@

$(CSS_DEST_DIR)/%.css: $(CSS_SRC_DIR)/%.scss Makefile
ifdef WINDOWS
	-$(MKDIRP) $(subst /,\,$(@D))
else
	$(MKDIRP) $(@D)
endif
	echo ---> $@
	echo --->> $@
	$(SASSC) $< >> $@

$(CSS_DEST_DIR)/%.css: $(CSS_SRC_DIR)/%.css Makefile
ifdef WINDOWS
	-$(MKDIRP) $(subst /,\,$(@D))
else
	$(MKDIRP) $(@D)
endif
	echo ---> $@
	echo --->> $@
	cat $< >> $@

# maintenance
clean:

	$(RM) -r $(PROD_DIR) $(DEV_DIR)
	$(RM) $(VERSION_CONFIG)
	$(RM) $(DEFAULTS_CONFIG)
	$(RM) $(TOC_FILES)
	$(RM) $(LANGUAGES_DATA)
	$(RM) $(PLUGINS_APP)
	$(RM) -r $(CSS_DEST_DIR)

nuke: clean
	$(RM) -r node_modules
	$(RM) Gemfile.lock

.PHONY: clean usage help default build
