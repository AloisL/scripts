#!/usr/bin/env bash
# Delete the comments of a GitHub pull request (conversation and/or inline).
# Dry run by default: nothing is deleted without --apply.
#
# Usage:
#   gh-pr-clean-comments <PR> [options]
#
# <PR>, for any organization:
#   https://github.com/org/repo/pull/123   PR URL
#   org/repo#123                           repository and number
#   123                                    number only, in the repository of
#                                          the current directory
#
# Options:
#   --author login        Only comments by this author
#                         (default: you, the account logged in to gh)
#   --all-authors         Every author, bots and reviewers included
#                         (deleting other people's comments requires admin)
#   --only general|inline Only conversation comments, or only inline review
#                         comments (default: both)
#   --apply               Actually delete (otherwise: dry run)
#   --no-hide             Do not hide comments that GitHub refuses to delete
#   -h, --help            Show this help
#
# Examples:
#   gh-pr-clean-comments https://github.com/acme/api/pull/42   # dry run
#   gh-pr-clean-comments acme/api#42 --all-authors --apply     # delete all
#   gh-pr-clean-comments 42 --author Copilot --only inline --apply
#
# Inline comments rejected by the REST API (HTTP 422, e.g. Copilot review
# comments) are retried through the GraphQL deletePullRequestReviewComment
# mutation. When GitHub still refuses ("cannot be deleted"), the comment is
# hidden as outdated instead (reversible, reported as "hidden"); pass
# --no-hide to skip that. Review bodies cannot be deleted through the API.

set -euo pipefail

usage() { sed -n '2,35p' "$0" | sed 's/^# \{0,1\}//'; }

pr="" repo="" author="" all_authors=false only="all" apply=false hide=true
while [ $# -gt 0 ]; do
  case "$1" in
    --author) author="${2:?--author expects a login}"; shift 2 ;;
    --all-authors) all_authors=true; shift ;;
    --only) only="${2:?--only expects general or inline}"; shift 2 ;;
    --apply) apply=true; shift ;;
    --no-hide) hide=false; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) pr="$1"; shift ;;
  esac
done

# <PR>: URL, org/repo#123 or bare number
if [[ "$pr" =~ ^https?://[^/]+/([^/]+/[^/]+)/pull/([0-9]+) ]]; then
  repo="${BASH_REMATCH[1]}" pr="${BASH_REMATCH[2]}"
elif [[ "$pr" =~ ^([^/#[:space:]]+/[^/#[:space:]]+)#([0-9]+)$ ]]; then
  repo="${BASH_REMATCH[1]}" pr="${BASH_REMATCH[2]}"
fi
[[ "$pr" =~ ^[0-9]+$ ]] || { echo "Missing or invalid PR: URL, org/repo#123 or number." >&2; usage >&2; exit 2; }
case "$only" in all|general|inline) ;; *) echo "--only: general or inline" >&2; exit 2 ;; esac

export GH_PROMPT_DISABLED=1
if [ -z "$repo" ]; then
  repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner </dev/null 2>/dev/null) ||
    { echo "Not in a GitHub repository: pass a PR URL or org/repo#123." >&2; exit 2; }
fi
gh api "repos/$repo/pulls/$pr" --jq .number </dev/null >/dev/null 2>&1 ||
  { echo "PR $repo#$pr not found or not accessible." >&2; exit 1; }
if ! $all_authors && [ -z "$author" ]; then
  author=$(gh api user --jq .login </dev/null)
fi

filter='.[]'
$all_authors || filter=".[] | select(.user.login == \"$author\")"
filter="$filter | \"\\(.id)\\t\\(.node_id)\\t\\(.user.login)\\t\\(.body | gsub(\"\\n\"; \" \") | .[0:70])\""

echo "PR $repo#$pr — author: $($all_authors && echo all || echo "$author") — scope: $only — $($apply && echo DELETE || echo dry run)"

one_line() { printf '%s' "$1" | tr '\n' ' ' | cut -c1-160; }

# Inline review comments: GraphQL fallback when REST refuses the deletion.
delete_inline_graphql() {
  gh api graphql -f id="$1" \
    -f query='mutation($id: ID!) { deletePullRequestReviewComment(input: { id: $id }) { clientMutationId } }' \
    </dev/null 2>&1 >/dev/null
}

# Last resort: hide the comment as outdated (reversible from the GitHub UI).
hide_comment() {
  gh api graphql -f id="$1" \
    -f query='mutation($id: ID!) { minimizeComment(input: { subjectId: $id, classifier: OUTDATED }) { minimizedComment { isMinimized } } }' \
    </dev/null 2>&1 >/dev/null
}

total=0 deleted=0 hidden=0 failed=0
process() { # $1 = label, $2 = list path, $3 = delete path
  local label=$1 list=$2 del=$3 id node_id login body err err2 err3
  while IFS=$'\t' read -r id node_id login body; do
    [ -n "$id" ] || continue
    total=$((total + 1))
    if ! $apply; then
      echo "$label $id ($login): $body"
      continue
    fi
    err2=""
    if err=$(gh api -X DELETE "repos/$repo/$del/$id" </dev/null 2>&1 >/dev/null); then
      deleted=$((deleted + 1)); echo "deleted  $label $id ($login)"
    elif [ "$label" = inline ] && err2=$(delete_inline_graphql "$node_id"); then
      deleted=$((deleted + 1)); echo "deleted  $label $id ($login) [GraphQL]"
    elif $hide && err3=$(hide_comment "$node_id"); then
      hidden=$((hidden + 1)); echo "hidden   $label $id ($login) [cannot be deleted]"
    else
      failed=$((failed + 1))
      echo "FAILED   $label $id ($login): $(one_line "$err")${err2:+ | GraphQL: $(one_line "$err2")}"
    fi
  done < <(gh api "repos/$repo/$list" --paginate --jq "$filter" </dev/null)
}

[ "$only" = inline ] || process general "issues/$pr/comments" "issues/comments"
[ "$only" = general ] || process inline "pulls/$pr/comments" "pulls/comments"

if $apply; then
  echo "— $deleted deleted, $hidden hidden, $failed failed out of $total."
else
  echo "— $total comment(s) matched. Run again with --apply to delete."
fi
