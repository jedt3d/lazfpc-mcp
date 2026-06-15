# lazfpc-mcp Implementation Plan

## Overview

lazfpc-mcp is an MCP (Model Context Protocol) server for Lazarus and Free Pascal development, written in Free Pascal using the official FPC MCP framework from `gitlab.com/freepascal.org/mcp`.

## Repositories

| Repo | URL | Purpose |
|------|-----|---------|
| pascal-language-server | `git@github.com:jedt3d/pascal-language-server.git` | LSP for Free Pascal (fork, updated) |
| lazfpc-mcp | `git@github.com:jedt3d/lazfpc-mcp.git` | MCP server for AI coding agents |

## Architecture

### Framework: FPC MCP (`gitlab.com/freepascal.org/mcp`)

The FPC MCP framework provides:
- `TMCPStdIOApplication` / `TMCPSocketApplication` - Transport (stdio, socket, HTTP)
- `TMCPTool` / `TMCPEventTool` - Base tool classes
- `TMCPSchema` / `TMCPSchema.AddArgument` - Input schema definition
- `TMCPToolRegistry` - Global tool registration
- `TMCPController` - Request routing and lifecycle
- `TMCPResource` / `TMCPPrompt` - Resources and prompts support

### Tool Pattern

Each tool inherits from `TMCPTool` and overrides `DoExecute(aInput: TJSONObject; aResult: TJSONObject)`:

```pascal
TMyTool = class(TMCPTool)
  constructor create(aName, aDescription: string); override;
  procedure DoExecute(aInput: TJSONObject; aResult: TJSONObject); override;
end;
```

Registration:
```pascal
TMyTool.create('tool_name', 'Tool description').Register;
```

### Transport

`TMCPStdIOApplication` reads JSON-RPC from stdin and writes to stdout. Compatible with all MCP clients that support stdio transport.

## Tools Specification

### Phase 1 - Core

#### `build_project` (TBuildProjectTool)

Builds a Lazarus .lpi project using lazbuild.

Input:
- `project_path` (string, required) - Path to .lpi file
- `target_os` (string, optional) - Target OS: "darwin", "win64", "linux"
- `target_cpu` (string, optional) - Target CPU: "aarch64", "x86_64"

Output:
```json
{
  "success": true,
  "project_path": "/path/to/project.lpi",
  "target_os": "darwin",
  "output": "Linking...",
  "errors": [],
  "warnings": []
}
```

Implementation: Uses `TProcess` to run lazbuild with proper PATH resolution.

#### `parse_lfm` (TParseLFMTool)

Parses a .lfm form file and returns the component tree.

Input:
- `lfm_path` (string, required) - Path to .lfm file
- `max_depth` (integer, optional) - Max depth (0 = unlimited)

Output:
```json
{
  "lfm_path": "/path/to/unit1.lfm",
  "root": {
    "name": "Form1",
    "class": "TForm",
    "properties": { "Left": 0, "Top": 0, "Width": 320, "Height": 240 },
    "children": [
      { "name": "Button1", "class": "TButton", "properties": {...} }
    ]
  }
}
```

Implementation: Reuses existing `LfmParser.pas` from `lfm_layout_designer` project.

### Phase 2 - Analysis & Testing

#### `parse_lpi` (TParseLPITool)

Parses .lpi XML project files.

Input:
- `lpi_path` (string, required)

Output:
```json
{
  "name": "MyProject",
  "units": ["unit1.pas", "unit2.pas"],
  "dependencies": ["LCLBase"],
  "compiler_options": { "target_os": "darwin", "target_cpu": "aarch64" },
  "output_directory": "lib/aarch64-darwin"
}
```

#### `run_fpcunit_tests` (TRunTestsTool)

Builds and runs FPCUnit test projects.

Input:
- `test_project_path` (string, required)
- `suite_filter` (string, optional)

Output:
```json
{
  "success": true,
  "tests_run": 5,
  "tests_passed": 4,
  "tests_failed": 1,
  "results": [
    { "suite": "TMyTestCase", "test": "TestSomething", "passed": true },
    { "suite": "TMyTestCase", "test": "TestOther", "passed": false, "message": "Expected 5 got 3" }
  ]
}
```

### Phase 3 - Discovery

#### `search_fpc_help` (TSearchFPCHelpTool)

Searches FPC documentation.

Input:
- `query` (string, required)
- `max_results` (integer, optional, default 10)

#### `list_projects` (TListProjectsTool)

Scans directories for Lazarus projects.

Input:
- `directory_path` (string, required)
- `recursive` (boolean, optional, default true)

## Project Structure

```
lazfpc-mcp/
  lazfpc-mcp.lpi
  lazfpc-mcp.lpr
  COPYING.FPC
  src/
    tools/
      mcptools.build.pas
      mcptools.lfm.pas
      mcptools.lpi_parse.pas
      mcptools.tests.pas
      mcptools.docs.pas
      mcptools.projects.pas
    utils/
      mcputils.pathconfig.pas
      mcputils.build.pas
      mcputils.errorparser.pas
    lsp/
  docs/
    lazfpc-mcp_plan.md
```

## Build Commands

```bash
# Resolve FPC version and PATH
FPC_VER=$(/path/to/fpc/bin/fpc -iV)
PATH="/path/to/fpc/lib/fpc/${FPC_VER}:/path/to/fpc/bin:$PATH"

# Build macOS
lazbuild -B --ws=cocoa --compiler=/path/to/fpc/bin/fpc lazfpc-mcp.lpi

# Build Windows (cross-compile)
lazbuild -B --os=win64 --cpu=x86_64 --compiler=/path/to/fpc/bin/fpc lazfpc-mcp.lpi
```

## MCP Client Configuration

### opencode.json
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

### Claude Desktop (claude_desktop_config.json)
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

## Comparable Implementations

| Project | Language | Pattern | Tools |
|---------|----------|---------|-------|
| [mcp-cpp](https://github.com/mpsm/mcp-cpp) | Rust | Wraps clangd LSP | Diagnostics, symbols, references |
| [clangd-mcp-server](https://github.com/felipeerias/clangd-mcp-server) | Rust | Wraps clangd | Diagnostics, symbol search, includes |
| [Clangaroo](https://github.com/jasondk/clangaroo) | Rust | Custom parser + compilation DB | Code intelligence |
| [cplusplus_mcp](https://github.com/kandrwmrtn/cplusplus_mcp) | Rust | Semantic analysis | Class hierarchy, signatures |
| [pascal-language-server](https://github.com/jedt3d/pascal-language-server) | FPC | LSP via CodeTools | Completion, formatting |
| FPC MCP dbconnector | FPC | FPC MCP framework | SQL: list_tables, execute_sql |
| **lazfpc-mcp** | **FPC** | **FPC MCP framework** | **Build, LFM, LPI, tests** |

## Benchmarking Plan

### Layer 1: Performance

| Metric | Target | Method |
|--------|--------|--------|
| Throughput (RPS) | 3000+ | k6 load tester with 50 VUs |
| Avg Latency | < 10ms | k6 (excluding lazbuild spawn) |
| P95 Latency | < 20ms | k6 |
| Memory | < 20MB | Docker stats / `ps` |
| Error Rate | 0% | k6 thresholds |

Expected Tier 1 performance (native FPC binary, comparable to Rust/Go).

### Layer 2: Tool Quality

| Metric | Target | Method |
|--------|--------|--------|
| Tool Hit Rate | > 90% | 10 predefined tasks, measure correct tool selection |
| Tool Success Rate | > 95% | 20 valid + 5 invalid inputs per tool |
| Parameter Accuracy | > 85% | Measure correct parameter passing |

### Layer 3: Agent Effectiveness

| Scenario | Expected | Method |
|----------|----------|--------|
| "Build my project" | Correct build_project call | Claude/GPT prompt test |
| "Show form layout" | Correct parse_lfm call | Claude/GPT prompt test |
| "List project units" | Correct parse_lpi call | Claude/GPT prompt test |

### Layer 4: Protocol Compliance

- `initialize` response matches MCP spec
- `tools/list` returns all registered tools with schemas
- `tools/call` returns proper JSON-RPC response
- Error codes for invalid parameters, missing files

## Roadmap

| Phase | Scope | Status |
|-------|-------|--------|
| 1 | `build_project`, `parse_lfm` | Skeleton created |
| 2 | `parse_lpi`, `run_fpcunit_tests` | Skeleton created |
| 3 | `search_fpc_help`, `list_projects` | Skeleton created |
| Future | CodeTools integration, LSP bridge | Planned |

## Git Workflow

Feature branches, PRs, merge, branch cleanup.

```
main ──────────────────────────────────
  ├─ init/project-setup ── PR #1 (initial setup)
  ├─ feat/phase1-build-lfm ── PR (tools + utils)
  ├─ feat/phase2-analysis-tests ── PR
  ├─ feat/phase3-discovery ── PR
  └─ feat/codetools-integration ── PR
```

Conventional commits: `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`
