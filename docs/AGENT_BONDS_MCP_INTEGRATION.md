# Agent Bonds MCP Integration

MCP is the tool/action invocation surface.

FlowMemory Agent Bonds adds MCP tools, resources, and prompts for:
- passport discovery;
- envelope quoting/validation;
- receipt lookup;
- verifier and challenge preparation;
- x402 funding previews.

Mutating MCP tools must:
- require explicit dryRun: false;
- avoid implicit chain execution unless an existing repo pattern explicitly supports it;
- never expose private keys;
- never expose sensitive evidence unless policy allows it.

MCP is an integration surface, not a replacement for Agent Bonds policy and receipt rules.
