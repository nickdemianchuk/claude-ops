#!/usr/bin/env bash
# PreToolUse(Bash): enforce rules/git.md commit subject format
# (Angular convention: "type: lowercase subject", <=50 chars, no trailing period).
# Best-effort: only validates when a message can be confidently extracted from
# the command (a heredoc-built -m, or a simple single-line -m "..."). Anything
# else (interactive commit, -F file, multi -m) is left unchecked rather than
# risk a false block.
set -euo pipefail

input="$(cat)"
cmd="$(jq -r '.tool_input.command // empty' <<<"$input")"

echo "$cmd" | grep -qE '(^|[;&|]\s*)git\s+commit\b' || exit 0

CC_COMMIT_CMD="$cmd" perl -e '
my $cmd = $ENV{CC_COMMIT_CMD};

my $msg;
if ($cmd =~ /<<[\s]*[\x27"]?(\w+)[\x27"]?\s*\n(.*?)\n\1/s) {
    my $body = $2;
    ($msg) = split /\n/, $body, 2;
} elsif ($cmd =~ /-m\s+"([^"]*)"/) {
    $msg = $1;
} elsif ($cmd =~ /-m\s+\x27([^\x27]*)\x27/) {
    $msg = $1;
}

exit 0 unless defined $msg;
$msg =~ s/^\s+|\s+$//g;
exit 0 if $msg eq "";

my @problems;
push @problems, "must be \x27type: subject\x27 with type in feat|fix|docs|refactor|test|ci|perf, lowercase after the colon"
    unless $msg =~ /^(feat|fix|docs|refactor|test|ci|perf): [a-z]/;
push @problems, "must be <=50 chars (got " . length($msg) . ")" if length($msg) > 50;
push @problems, "must not end with a period" if $msg =~ /\.$/;

if (@problems) {
    my $reason = "claude-ops rule (rules/git.md) violated: " . join("; ", @problems) . qq{. Message was: "$msg"};
    $reason =~ s/(["\\\\])/\\$1/g;
    print qq({"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"$reason"}});
}
'
