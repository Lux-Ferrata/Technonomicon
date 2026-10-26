# claude-local: Claude Code on Akmon's Strata instead of Anthropic's
# models -- same tool, local model, nothing leaves the tailnet. Straight to
# akmon:8011 (not Kvasir's 127.0.0.1:8011, which would quietly fall back to
# the small offline model): away from Akmon it fails instead. Strata
# answers to any model name; Claude Code just needs one it knows. The key
# is added by Akmon's nginx (Tn-dev-host). `lagent agent` runs it headless.
{ writeShellScriptBin, claude-code }:
writeShellScriptBin "claude-local" ''
  unset ANTHROPIC_API_KEY
  export ANTHROPIC_BASE_URL=http://akmon:8011
  export ANTHROPIC_AUTH_TOKEN=local
  export ANTHROPIC_MODEL=claude-sonnet-5-5
  export ANTHROPIC_DEFAULT_OPUS_MODEL=$ANTHROPIC_MODEL
  export ANTHROPIC_DEFAULT_SONNET_MODEL=$ANTHROPIC_MODEL
  export ANTHROPIC_DEFAULT_HAIKU_MODEL=$ANTHROPIC_MODEL
  export CLAUDE_CODE_SUBAGENT_MODEL=$ANTHROPIC_MODEL
  # Strata's context (Tn-dev-host); Claude Code can't ask it
  export CLAUDE_CODE_MAX_CONTEXT_TOKENS=131072
  export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
  # the first request may wait for Strata to load (a minute or two)
  export API_TIMEOUT_MS=900000
  exec ${claude-code}/bin/claude "$@"
''
