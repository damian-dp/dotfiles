#!/bin/bash
# Fast commit function using Claude CLI
# Create commit.sh in ~/.config/shell/commit.sh
# Add source ~/.config/shell/commit.sh to ~/.zshrc

commit() {
  # Force bash-style 0-indexed arrays in zsh
  [[ -n "$ZSH_VERSION" ]] && setopt localoptions ksharrays

  local debug=false
  local confirm=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --debug) debug=true ;;
      -c|--confirm) confirm=true ;;
      *) ;;
    esac
    shift
  done

  # Check we're in a git repo
  if ! git rev-parse --git-dir &>/dev/null; then
    echo "Not a git repository"
    return 1
  fi

  # Always run from repo root to ensure paths are consistent
  local repo_root=$(git rev-parse --show-toplevel)
  local original_dir="$PWD"
  cd "$repo_root" || { echo "Failed to cd to repo root"; return 1; }

  # Pre-fetch all git context
  local staged=$(git diff --cached --stat 2>/dev/null)
  local has_staged=$([[ -n "$staged" ]] && echo "true" || echo "false")

  # Diff size limit (lines) - truncate large diffs to avoid prompt overflow
  local max_diff_lines=1500

  # Exclude lock files from diff content (noisy) but keep them in file list
  local lock_exclude="':!bun.lock' ':!package-lock.json' ':!yarn.lock' ':!pnpm-lock.yaml'"

  if [[ "$has_staged" == "true" ]]; then
    local diff_full=$(eval "git diff --cached -- . $lock_exclude")
    local diff_stat=$(git diff --cached --stat)
    # Use --name-status to capture both sides of renames (R old new)
    local files=$(git diff --cached --name-status | awk '{if($1~/^R/){print $2; print $3}else{print $2}}')
    local binary_files=$(git diff --cached --numstat | awk '$1 == "-" && $2 == "-" {print $3}')
  else
    local diff_full=$(eval "git diff -- . $lock_exclude")
    local diff_stat=$(git diff --stat)
    local files=$(git diff --name-status | awk '{if($1~/^R/){print $2; print $3}else{print $2}}')
    local binary_files=$(git diff --numstat | awk '$1 == "-" && $2 == "-" {print $3}')
    local untracked=$(git ls-files --others --exclude-standard)
  fi

  # Check for problematic filenames (git quotes names with special chars)
  if echo "$files" | grep -q '^".*"$'; then
    echo "⚠️  Warning: Some files have special characters in their names (quoted by git). These may not commit correctly."
  fi

  # Store original file list for verification later
  local -a original_files=()
  while IFS= read -r f; do
    [[ -n "$f" ]] && original_files+=("$f")
  done <<< "$files"
  if [[ -n "$untracked" ]]; then
    while IFS= read -r f; do
      [[ -n "$f" ]] && original_files+=("$f")
    done <<< "$untracked"
  fi

  # Truncate diff if too large
  local diff_lines=$(echo "$diff_full" | wc -l | tr -d ' ')
  local diff_truncated=""
  if [[ $diff_lines -gt $max_diff_lines ]]; then
    local diff=$(echo "$diff_full" | head -n $max_diff_lines)
    diff_truncated=" (TRUNCATED from ${diff_lines} lines - use file names and stats to infer intent)"
  else
    local diff="$diff_full"
  fi

  local git_status=$(git status --short)
  local recent=$(git log --oneline -5 2>/dev/null)
  local branch=$(git branch --show-current)

  # Bail if nothing to commit
  if [[ -z "$diff" && -z "$untracked" ]]; then
    echo "Nothing to commit"
    cd "$original_dir"
    return 0
  fi

  if [[ "$debug" == true ]]; then
    echo "━━━ DEBUG: Git Context ━━━"
    echo "Branch: $branch"
    echo "Has staged: $has_staged"
    echo "Files (${#original_files[@]}):"
    for f in "${original_files[@]}"; do
      echo "  $f"
    done
    echo "Diff lines: $diff_lines (max: $max_diff_lines)${diff_truncated:+ [TRUNCATED]}"
    echo ""
  fi

  # Build the prompt with all context
  local prompt="Generate a git commit message for the following changes.

## Important
- Split into logical commits by category: deps, components, docs, tests, config, etc.
- Group related small changes together - avoid single-file commits for minor tweaks
- Respond with ONLY commit blocks - no preamble, no explanations, no markdown fences

## Output Format
For each commit, use this exact format:
---COMMIT---
FILES:
path/to/file1.ts
path/to/file2.ts
MESSAGE:
[gitmoji] type: short description

- bullet point 1
- bullet point 2
---END---

Output multiple blocks for logically separate changes. One block only if changes are truly atomic.
IMPORTANT: List files ONE PER LINE after FILES: (not comma-separated). Use exact paths from the file list.

## Format Required
- Title line: \`[gitmoji] type: short description\` (under 80 characters)
- Blank line
- 2-3 bullet points describing key changes (each under 80 chars)

## Type Reference
feat, fix, refactor, chore, docs, test, style, perf, build, ci

## Gitmoji (use standard gitmoji, common ones below)
✨ feat | 🐛 fix | ♻️ refactor | 🔧 chore | 📝 docs | ✅ test | 💄 style | ⚡️ perf | 🚚 move/rename | 🔥 remove | ➕➖ deps

## Recent Commits (match this style)
${recent}

## Current Branch
${branch}

## Committing Staged Only
${has_staged}

## Files Changed (include ALL in your commit)
${files}${untracked:+
$untracked}
${binary_files:+
## Binary Files (no diff content, include in FILES if relevant)
$binary_files}

## Diff Stats
${diff_stat}

## Diff${diff_truncated}
${diff}"

  # Pick model based on diff complexity
  local model="haiku"
  if [[ $diff_lines -gt 500 ]]; then
    model="sonnet"
  fi

  [[ "$debug" == true ]] && echo "Model: $model (diff: $diff_lines lines)"
  echo "Generating commit message..."

  # Call Claude in print mode (fast, no tools)
  local claude_stderr=$(mktemp)
  local msg=$(echo "$prompt" | claude --print --model "$model" 2>"$claude_stderr")
  local claude_exit=$?

  if [[ $claude_exit -ne 0 ]] || [[ -z "$msg" ]]; then
    echo "❌ Failed to generate commit message"
    if [[ -s "$claude_stderr" ]]; then
      echo "Error: $(cat "$claude_stderr")"
    fi
    rm -f "$claude_stderr"
    cd "$original_dir"
    return 1
  fi
  rm -f "$claude_stderr"

  # Strip any markdown code fences
  msg=$(echo "$msg" | sed '/^```$/d')

  if [[ "$debug" == true ]]; then
    echo "━━━ DEBUG: Claude Response ━━━"
    echo "$msg"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
  fi

  # Count how many commits
  local commit_count=$(echo "$msg" | grep -c "^---COMMIT---$")

  if [[ $commit_count -eq 0 ]]; then
    echo "❌ Failed to parse commit message (no ---COMMIT--- blocks found)"
    echo "━━━ Claude Response ━━━"
    echo "$msg"
    echo "━━━━━━━━━━━━━━━━━━━━━━━"
    cd "$original_dir"
    return 1
  fi

  [[ "$debug" == true ]] && echo "━━━ DEBUG: Found $commit_count commit(s) ━━━"

  # Parse commit blocks into arrays
  local -a commit_files=()
  local -a commit_messages=()
  local current_files=""
  local current_message=""
  local in_files=false
  local in_message=false

  while IFS= read -r line; do
    if [[ "$line" == "---COMMIT---" ]]; then
      current_files=""
      current_message=""
      in_files=false
      in_message=false
    elif [[ "$line" == "---END---" ]]; then
      if [[ -n "$current_files" && -n "$current_message" ]]; then
        commit_files+=("$current_files")
        commit_messages+=("$current_message")
      fi
      in_files=false
      in_message=false
    elif [[ "$line" == "FILES:" ]]; then
      in_files=true
      in_message=false
    elif [[ "$line" == "MESSAGE:" ]]; then
      in_files=false
      in_message=true
    elif [[ "$in_files" == true ]]; then
      # Collect file paths (one per line)
      line=$(echo "$line" | sed 's/^ *//;s/ *$//')  # trim
      if [[ -n "$line" ]]; then
        if [[ -z "$current_files" ]]; then
          current_files="$line"
        else
          current_files="$current_files"$'\n'"$line"
        fi
      fi
    elif [[ "$in_message" == true ]]; then
      if [[ -z "$current_message" ]]; then
        current_message="$line"
      else
        current_message="$current_message"$'\n'"$line"
      fi
    fi
  done <<< "$msg"

  # Show planned commits
  echo ""
  for ((i=0; i<${#commit_messages[@]}; i++)); do
    local msg="${commit_messages[$i]}"
    local file_list="${commit_files[$i]}"
    local file_count=$(echo "$file_list" | grep -c .)

    echo "[$((i+1))/$commit_count]"
    echo "$msg"
    echo ""
    if [[ "$debug" == true ]]; then
      echo "    Files ($file_count):"
      echo "$file_list" | while IFS= read -r f; do
        echo "      $f"
      done
    else
      echo "    Files: $file_count"
    fi
    [[ $i -lt $((commit_count - 1)) ]] && echo ""
  done

  # Confirm only if -c flag
  if [[ "$confirm" == true ]]; then
    echo ""
    printf "Proceed? [Y/n] "
    read -r REPLY
    if [[ ! $REPLY =~ ^[Yy]?$ ]]; then
      echo "Aborted."
      cd "$original_dir"
      return 0
    fi
  fi

  echo ""

  # Track committed files and results for verification
  local -a committed_files=()
  local -a commit_results=()  # "ok" or "fail"
  local -a commit_errors=()   # error messages per commit
  local total_committed=0

  # Execute commits
  for ((i=0; i<${#commit_messages[@]}; i++)); do
    local file_list="${commit_files[$i]}"
    local message="${commit_messages[$i]}"
    local title=$(echo "$message" | head -n 1)

    # Reset staging area
    git reset HEAD --quiet 2>/dev/null

    # Stage files with validation
    local staged_count=0
    local errors=""

    while IFS= read -r f; do
      f=$(echo "$f" | sed 's/^ *//;s/ *$//')  # trim whitespace
      [[ -z "$f" ]] && continue

      # Check if file was in original changeset (prevent hallucinated files)
      local in_scope=false
      for orig in "${original_files[@]}"; do
        if [[ "$f" == "$orig" ]]; then
          in_scope=true
          break
        fi
      done

      if [[ "$in_scope" == false ]]; then
        errors+="      Not in changeset: $f"$'\n'
        continue
      fi

      # Try to stage (works for modifications, additions, AND deletions)
      if ! git add "$f" 2>/dev/null; then
        errors+="      Failed to stage: $f"$'\n'
      else
        [[ "$debug" == true ]] && echo "  ✓ $f"
        committed_files+=("$f")
        ((staged_count++))
      fi
    done <<< "$file_list"

    # Commit
    if ! git diff --cached --quiet 2>/dev/null; then
      if git commit --quiet -m "$message" 2>/dev/null; then
        commit_results+=("ok")
        ((total_committed++))
      else
        commit_results+=("fail")
        errors+="      Commit command failed"$'\n'
      fi
    else
      commit_results+=("fail")
      errors+="      Nothing staged"$'\n'
    fi

    commit_errors+=("$errors")
  done

  # Verify all original files were included
  local -a missed_files=()
  for orig in "${original_files[@]}"; do
    local found=false
    for committed in "${committed_files[@]}"; do
      if [[ "$orig" == "$committed" ]]; then
        found=true
        break
      fi
    done
    if [[ "$found" == false ]]; then
      missed_files+=("$orig")
    fi
  done

  # Final summary
  echo ""
  local has_errors=false
  for ((i=0; i<${#commit_results[@]}; i++)); do
    if [[ "${commit_results[$i]}" != "ok" ]] || [[ -n "${commit_errors[$i]}" ]]; then
      has_errors=true
      break
    fi
  done

  if [[ "$has_errors" == true ]] || [[ ${#missed_files[@]} -gt 0 ]]; then
    echo "Done with errors:"
    echo ""
    for ((i=0; i<${#commit_messages[@]}; i++)); do
      local title=$(echo "${commit_messages[$i]}" | head -n 1)
      if [[ "${commit_results[$i]}" == "ok" ]]; then
        echo "  ✓ $title"
      else
        echo "  ✗ $title"
      fi
      if [[ -n "${commit_errors[$i]}" ]]; then
        printf "%s" "${commit_errors[$i]}"
      fi
      echo ""
    done
    if [[ ${#missed_files[@]} -gt 0 ]]; then
      echo "  Files not committed:"
      for f in "${missed_files[@]}"; do
        echo "    - $f"
      done
    fi
  else
    echo "✓ Done ($total_committed commit(s))"
  fi

  cd "$original_dir"
}
