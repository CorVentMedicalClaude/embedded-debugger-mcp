# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Rust-based MCP (Model Context Protocol) server for embedded debugging using probe-rs. Exposes 22 debugging tools to AI assistants for ARM Cortex-M and RISC-V microcontroller debugging via J-Link, ST-Link, DAPLink probes.

## Build Environment Setup

The project uses a self-contained toolchain installed locally in `tools/` (gitignored). PowerShell scripts in `scripts/` manage everything.

```powershell
.\scripts\setup.ps1            # First-time: installs Rust + C compiler into tools/
.\scripts\build.ps1            # cargo build --release
.\scripts\build.ps1 test       # cargo test
.\scripts\build.ps1 clippy     # cargo clippy
.\scripts\build.ps1 fmt        # cargo fmt
```

After setup, you can also use cargo directly by dot-sourcing the environment first:

```powershell
. .\scripts\env.ps1            # Set RUSTUP_HOME, CARGO_HOME, PATH, CC
cargo build --release
cargo test test_name            # Run a single test by name
cargo test -- --nocapture       # Run tests with stdout visible
```

The integration tests in `tests/integration_tests.rs` work without hardware (probe discovery returns empty list gracefully). The `full-integration` feature flag exists but is currently unused.

## Architecture

The server uses RMCP 0.3.2 (Rust MCP SDK) with stdio transport and tokio async runtime.

### Core Flow

`main.rs` parses CLI args (clap), loads TOML config, creates `EmbeddedDebuggerToolHandler`, and serves it over stdio via RMCP.

### Module Structure

- **`tools/debugger_tools.rs`** — The central file (~1800 lines). Contains `EmbeddedDebuggerToolHandler` which implements all 22 MCP tools via RMCP's `#[tool]` macro attributes. Each tool method is annotated with `#[tool(name = "...", description = "...")]`. Sessions are stored in `Arc<RwLock<HashMap<String, Arc<DebugSession>>>>`.
- **`tools/types.rs`** — Input argument structs (with `JsonSchema` derive for MCP schema generation) and response types for all tools.
- **`config.rs`** — TOML-based configuration with CLI arg merging. Config sections: server, debugger, rtt, memory, flash, security, targets, logging.
- **`error.rs`** — Error hierarchy using `thiserror`: `DebugError` (top-level), `RttError`, `TargetError`, `MemoryError`, `FlashError` with `From` conversions.
- **`debugger/discovery.rs`** — Probe discovery via probe-rs `Lister`.
- **`debugger/mod.rs`** — `SessionConfig` struct.
- **`rtt/manager.rs`** — RTT attach/detach/read/write operations wrapping probe-rs RTT.
- **`rtt/elf_parser.rs`** — ELF symbol parsing (via `goblin`) to find RTT control block addresses.
- **`flash/manager.rs`** — Flash erase/program/verify operations with `FlashManager`.
- **`utils.rs`** — Probe type detection by USB VID/PID, address parsing helpers.

### Key Patterns

- All tool implementations live in a single `#[tool_router]` impl block on `EmbeddedDebuggerToolHandler`.
- Session management: `connect` creates a `DebugSession` (with UUID), stores it in the sessions map; subsequent tools take a `session_id` parameter.
- Each `DebugSession` holds `Arc<tokio::sync::Mutex<Session>>` (probe-rs) and `Arc<tokio::sync::Mutex<RttManager>>`.
- Tool methods return `Result<CallToolResult, McpError>` where success/error content is JSON-serialized into MCP text content.
- Address parameters accept both hex strings ("0x8000000") and decimal, parsed via `utils::parse_address`.

### STM32 Demo

`examples/STM32_demo/` is a standalone embedded Rust project (separate Cargo workspace) targeting STM32G431CBTx with RTT bidirectional communication. It has its own build toolchain (`thumbv7em-none-eabi`).
