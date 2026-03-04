# ===============================
#  Professional CLI Showcase
#  Author: monkeymonk
#  Project: cdx
# ===============================

# -------- Output --------
Output demo.gif

# -------- Terminal Look --------
Set Shell "bash"
Set FontSize 18
Set Width 1200
Set Height 700
Set FontFamily "FiraCode Nerd Font"
Set Theme "Dracula"
Set Padding 20
Set CursorBlink true

# Optional: for slower, more polished feel
Set TypingSpeed 80ms
Set Framerate 60

# Hidden setup: clean environment + prompt
Hide
Type `export PS1='$ '`
Enter
Type "export XDG_CONFIG_HOME=/tmp/alx-demo-vhs"
Enter
Type "rm -rf /tmp/alx-demo-vhs"
Enter
Type "clear"
Enter
Sleep 500ms
Show

# -------- Setup (hidden) --------
Hide

# Create demo directory structure
Type@0ms "rm -rf /tmp/cdx-demo && mkdir -p /tmp/cdx-demo/projects/my-app/{src/components,tests,docs}"
Enter
Sleep 200ms

# Add some dummy files for eza to display
Type@0ms "touch /tmp/cdx-demo/projects/my-app/README.md /tmp/cdx-demo/projects/my-app/package.json"
Enter
Sleep 200ms
Type@0ms "touch /tmp/cdx-demo/projects/my-app/src/index.ts /tmp/cdx-demo/projects/my-app/src/components/App.tsx"
Enter
Sleep 200ms
Type@0ms "touch /tmp/cdx-demo/projects/my-app/tests/app.test.ts"
Enter
Sleep 200ms
Type@0ms "touch /tmp/cdx-demo/projects/my-app/docs/guide.md /tmp/cdx-demo/projects/my-app/docs/api.md"
Enter
Sleep 200ms

# Init git repo with a commit so status shows something
Type@0ms "cd /tmp/cdx-demo/projects/my-app && git init -q && git add -A && git commit -q -m 'init' && touch TODO.md"
Enter
Sleep 200ms

# Source cdx and hooks
Type@0ms "source /home/monkeymonk/works/tools/cdx/cdx.sh"
Enter
Sleep 200ms
Type@0ms "source /home/monkeymonk/works/tools/cdx/hooks/preview.sh"
Enter
Sleep 200ms
Type@0ms "source /home/monkeymonk/works/tools/cdx/hooks/git.sh"
Enter
Sleep 200ms

# Set eza args for nice output
Type@0ms "export CDX_LS_ARGS='--icons=always --color=always -la --no-user --no-permissions --no-time'"
Enter
Sleep 200ms

# Start at demo root
Type@0ms "cd /tmp/cdx-demo"
Enter
Sleep 200ms

Type@0ms "clear"
Enter
Sleep 200ms

Show

# -------- Intro Section --------
Sleep 300ms

# Big clean intro
Type "# cdx -- A modern shell navigation tool with hooks and inspect mode"
Enter
Sleep 800ms

# -------- Help / Usage --------
Type "cdx --help"
Enter
Sleep 2000ms

# -------- Basic Navigation --------
Sleep 200ms
Type "# Navigate into a project — hooks show preview + git status"
Enter
Sleep 1000ms

Type "cdx projects/my-app"
Enter
Sleep 2000ms

# -------- Dive into src to set up next demos --------
Type "# Dive into src/"
Enter
Sleep 500ms

Type "cdx src"
Enter
Sleep 2000ms

# -------- Up with Subpath --------
Type "# Jump up one level and into docs/ in one command"
Enter
Sleep 1000ms

Type "cdx -1/docs"
Enter
Sleep 2000ms

# -------- Inspect Mode --------
Type "# Inspect a directory without leaving the current one"
Enter
Sleep 1000ms

Type "cdx -i ../src"
Enter
Sleep 1000ms
Type "pwd"
Enter
Sleep 2000ms

# -------- Up Shorthand --------
Type "# Go up 3 levels back to the root"
Enter
Sleep 1000ms

Type "cdx -3"
Enter
Sleep 2000ms

# -------- Outro --------
Type "# Documentation: https://github.com/monkeymonk/cdx"
Enter
Sleep 1500ms
