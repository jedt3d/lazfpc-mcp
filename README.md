# lazfpc-mcp

An [MCP](https://modelcontextprotocol.io/) (Model Context Protocol) server for Lazarus and Free Pascal development. Provides AI coding agents (Claude, Cursor, OpenCode, etc.) with structured access to Lazarus build tools, form analysis, project metadata, and testing workflows.

Built with the [official FPC MCP framework](https://gitlab.com/freepascal.org/mcp) and written entirely in Free Pascal.

## Why This Exists

AI coding agents are powerful, but they lack native understanding of the Lazarus/Free Pascal ecosystem. This MCP server bridges that gap by exposing Lazarus-specific development workflows as MCP tools that any MCP-compatible client can invoke.

## Architecture

```
                    AI Coding Agent
                   (Claude, Cursor, etc.)
                          |
                   MCP Protocol
                  (JSON-RPC 2.0 / stdio)
                          |
                   lazfpc-mcp
                  (Free Pascal binary)
                          |
          +---------------+---------------+
          |               |               |
     lazbuild/fpc    LfmParser      .lpi XML Parse
     (build tools)  (form analysis)  (project metadata)
```

The server uses `TMCPStdIOApplication` from the FPC MCP framework for stdio transport, making it compatible with all major MCP clients.

## Tools

### Phase 1 - Core

| Tool | Description | Input | Output |
|------|-------------|-------|--------|
| `build_project` | Build a Lazarus .lpi project using lazbuild | `project_path`, `target_os`?, `target_cpu`? | success, output, errors[] |
| `parse_lfm` | Parse a .lfm form file and return component tree | `lfm_path`, `max_depth`? | component tree JSON |

### Phase 2 - Analysis & Testing

| Tool | Description | Input | Output |
|------|-------------|-------|--------|
| `parse_lpi` | Parse .lpi project file metadata | `lpi_path` | units[], dependencies[], options |
| `run_fpcunit_tests` | Build and run FPCUnit test project | `test_project_path`, `suite_filter`? | pass/fail per test |

### Phase 3 - Discovery

| Tool | Description | Input | Output |
|------|-------------|-------|--------|
| `search_fpc_help` | Search FPC RTL/FCL documentation | `query`, `max_results`? | docs with snippets |
| `list_projects` | Scan directories for .lpi/.lpr files | `directory_path`, `recursive`? | project list |

## Prerequisites

- Free Pascal Compiler 3.2.2+
- Lazarus IDE with `mcpbase.lpk` package installed
- FPC MCP framework (`gitlab.com/freepascal.org/mcp`)

## Setup

### 1. Clone the FPC MCP Framework

```bash
cd /path/to/your/lazarus/workspace
git clone https://gitlab.com/freepascal.org/mcp.git
```

### 2. Install MCP Packages in Lazarus

Open the following packages in Lazarus IDE and compile them:
- `mcp/Src/Base/mcpbase.lpk` - Core MCP library
- `mcp/Src/IDE/mcpdesign.lpk` - Design-time components (optional)

### 3. Build lazfpc-mcp

```bash
FPC_VER=$(/path/to/fpc/bin/fpc -iV)
PATH="/path/to/fpc/lib/fpc/${FPC_VER}:/path/to/fpc/bin:$PATH" \
  lazbuild -B --compiler=/path/to/fpc/bin/fpc lazfpc-mcp.lpi
```

## MCP Client Configuration

### OpenCode

Add to `opencode.json`:

```json
{
  "mcpServers": {
    "lazarus-dev": {
      "command": "/path/to/lazfpc-mcp/lazfpc-mcp",
      "args": []
    }
  }
}
```

### Claude Desktop

Add to `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "lazarus-dev": {
      "command": "/path/to/lazfpc-mcp/lazfpc-mcp",
      "args": []
    }
  }
}
```

### Cursor / VS Code

Add to `.cursor/mcp.json` or settings:

```json
{
  "mcpServers": {
    "lazarus-dev": {
      "command": "/path/to/lazfpc-mcp/lazfpc-mcp",
      "args": []
    }
  }
}
```

## Project Structure

```
lazfpc-mcp/
  lazfpc-mcp.lpi          # Lazarus project file
  lazfpc-mcp.lpr          # Main program (TMCPStdIOApplication)
  COPYING.FPC             # LGPL with linking exception
  src/
    tools/
      mcptools.build.pas      # TBuildProjectTool
      mcptools.lfm.pas        # TParseLFMTool
      mcptools.lpi_parse.pas  # TParseLPITool
      mcptools.tests.pas      # TRunTestsTool
      mcptools.docs.pas       # TSearchFPCHelpTool
      mcptools.projects.pas   # TListProjectsTool
    utils/
      mcputils.pathconfig.pas # FPC version / PATH resolution
      mcputils.build.pas      # lazbuild CLI wrapper
      mcputils.errorparser.pas # FPC error message parser
      mcputils.process.pas   # TProcess wrapper for running external programs
    lsp/                      # Future: CodeTools integration
  docs/
    lazfpc-mcp_plan.md     # Detailed implementation plan
```

## Related Projects

- [**pascal-language-server**](https://github.com/jedt3d/pascal-language-server) - LSP server for Free Pascal using CodeTools. Provides code completion, formatting, and diagnostics in editors like VS Code and Emacs.
- [**FPC MCP Framework**](https://gitlab.com/freepascal.org/mcp) - The official Free Pascal implementation of the Model Context Protocol.
- [**FPC MCP ACP**](https://gitlab.com/freepascal.org/acp) - Agent Communication Protocol client for connecting FPC applications to AI agents.
- [**mcp-cpp**](https://github.com/mpsm/mcp-cpp) - Comparable C++ MCP server using clangd LSP. Similar architecture pattern applied to C++.

## Benchmarking

See [docs/lazfpc-mcp_plan.md](docs/lazfpc-mcp_plan.md) for the full benchmarking plan covering:

- **Performance**: RPS, latency, memory footprint (expected Tier 1 as native FPC binary)
- **Tool Quality**: Hit rate, success rate, parameter accuracy
- **Agent Effectiveness**: Task completion with real-world scenarios
- **Protocol Compliance**: JSON-RPC 2.0 and MCP spec validation

## Roadmap

- [x] Phase 1: `build_project` — full lazbuild integration with PATH resolution, error/warning parsing
- [x] Phase 1: `parse_lfm` — full LFM parser with component tree, properties, layout summary, children
- [x] Phase 1: FPC error parsing (file, line, column, severity, message extraction)
- [x] Phase 2: `parse_lpi` — XML parsing with units, compiler options, search paths
- [x] Phase 2: `run_fpcunit_tests` — build + run + parse FPCUnit output with pass/fail per test
- [x] Phase 3: `search_fpc_help` — search FPC RTL/FCL/packages source for identifiers
- [x] Phase 3: `list_projects` — recursive directory scanner for .lpi/.lpr/.lpk files
- [x] All 6 tools implemented and compiling successfully
- [ ] Future: CodeTools integration for code analysis tools
- [ ] Future: Integration with pascal-language-server for LSP capabilities
- [ ] Future: Automated test suite and benchmarking

## Contributing

Contributions are welcome. Please open an issue or submit a pull request.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m 'feat: add my feature'`)
4. Push to the branch (`git push -u origin feature/my-feature`)
5. Open a Pull Request

## License

LGPL with linking exception (same as FPC RTL and the FPC MCP framework). See [COPYING.FPC](COPYING.FPC) for details.
