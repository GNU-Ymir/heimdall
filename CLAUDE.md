# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this
repository.

## What this is

Heimdall is the HTTP server and the actor system of Ymir, as a gyllir library package built on
midgard's primitives (`std::net::tcp`, `std::concurrency`, `std::pack`). Both used to live in
midgard as `std::net::http` and `std::concurrency::actor`; they moved out so the standard library
every `gyc` program links against stays small, dependency-free and stable, while the HTTP stack
(and its eventual TLS, compression and websocket needs) moves at its own pace here.

The repository is being stood up: `PLAN.md` tracks the move (HTTPS-1). Until it lands, the code
still lives in `../midgard/midgard/std/net/http*` and `../midgard/midgard/std/concurrency/actor*`.

## Issue tracking (Plane)

Project **HTTP server hardening** (key `HTTPS`), workspace `ymir-bootstrap`. Use the plane MCP
tools. Items migrated from Linear say so at the end of their description (`YMI-…`).

- HTTPS-1: standing up this repository and relocating the existing code, API unchanged.
- MID-141 (project `MID`): removing both trees from midgard, merged once heimdall builds and tests
  its copy.
- The other items rebuild the API on ymirc's tags once the move is done: `#[route]` routes and
  bound parameters (HTTPS-11, 12, 13), middlewares as tags (HTTPS-9), `#[json]` bodies and JSON
  Schema (HTTPS-20, 21), streaming over chunked encoding (HTTPS-5, 7), `Packable` as the actor
  serialization in place of `&Config` (HTTPS-19); HTTPS-2 to HTTPS-16 harden or extend the server.

The branch checked out is generally named `HTTPS-<issue_number>-<short-description>`; the
`HTTPS-<issue_number>` part is the Plane work item it is tracked against.

## Pull request titles

PR titles must read `[HTTPS-XXX][kind] Log`, `[kind]` being optional and defaulting to a feature.
Known kinds: `feat`/`feature`, `fix`, `perf`, `refactor`, `doc(s)`, `test(s)`,
`chore`/`ci`/`build`/`style`, `breaking`. Once CI mirrors midgard's (see `PLAN.md`), the release
notes are generated from these titles and the Plane sync attaches a PR to the work item of its
leading tag and of nothing else: a title without a valid tag is left out of both, silently.

## Policy

Concise comments:
- only describe what the functions do, not what the current work is adding
- don't write comments inside code unless absolutely necessary for understanding
- a comment of more than 3 lines is generally too verbose

Commits:
- split work in logical commits
- rewrite history when a new commit modifies something introduced by another commit of the same
  branch
- tests don't need to pass, nor the code to compile, between commits, as long as the last commit
  of the branch compiles and its tests succeed
- commit messages are one line long
- don't add co-authors

## Language

Ymir's memory model (`dmut` / `alias` / `copy` / `dcopy` / `ref`) is documented at length in
`../midgard/CLAUDE.md`, verified against the installed `gyc`; read it before touching code that
hands out mutable handles. `../bootstrap/test_resources/<topic>/` (the compiler's test cases) is
the quickest reference on what a language feature allows.

## Layout

The layout of the other non-midgard Ymir projects (`../bootstrap`, `../ymir-lsp`), not midgard's
`midgard/` + `rt/` + `tests/` + `test-rt/`:

- `gyllir.toml`: `type = "library"`, `package-root = "heimdall"`, `[std]` pinned to the midgard
  release, `[registry]` this repository.
- `src/heimdall.yr`: the package root, declaring `heimdall::http` and `heimdall::actor`.
- `src/heimdall/http*`: the HTTP server (`server`, `request`, `response`, `header`, `errors`),
  formerly `std::net::http`.
- `src/heimdall/actor*`: the actor system (`base`, `errors`, `reference`, `request`, `sys`,
  `sys::{message,utils}`), formerly `std::concurrency::actor`.
- `test/__test__.yr`: the test root, mirroring `src/` (`test/http/…`, `test/actor/…`).

There is no C code here: anything needing the runtime goes through midgard's public `std`/`core`/
`etc` modules. A need for a new `_yrt_*` symbol is a midgard change (with its own `MID` item).

`http/server.yr` and `actor/sys.yr` sit below `std` in two places, as midgard's own `std` modules
do, since there is no wrapper above them: `etc::runtime::threads::{_yrt_get_nprocs,
_yrt_thread_self_id}` and the raw C bindings `etc::c::{files, poll}` (`pipe`, `close`, epoll). A
rename inside midgard's `_yrt_*` ABI therefore breaks heimdall too, and has to be followed here.

## Build / run / test

The build system is `gyllir`, with `gyc` on `PATH` (`compiler` in `gyllir.toml`).

- Build: `gyllir build`. Dependencies (midgard included, through `[std]`) are resolved into
  `.deps/`, intermediate objects into `.target/`.
- Tests: `gyllir test`, which passes the runner options to the test binary: `-f` (a `::`-separated
  glob path with exactly as many segments as the test name, not a substring), `-sf`, `--resume`,
  `-j N`, `-s`, `-cov`, `-l`. Tests run concurrently in one process under `-j`, so a test creating
  threads must release them (`ActorSystem::join`, `TaskPool::dispose`), and a test opening a
  socket must not depend on a fixed port another test may hold.
- Keep gyc's unused-import warning `E3038` at zero; it only credits a `use` when a symbol is
  reached through the shortened path.

### The ymir-dev workspace (`../..`)

This checkout is `repos/heimdall` of ymir-dev (`/home/emile/ymir/ymir-dev`), cloned by its
`uv run start` (`ymir_dev/start.py`). `uv run preview` there builds a preview gyc and midgard into
`target/`, and `ymirc` (`~/.local/bin/ymirc`) is that preview. To build heimdall against an
unreleased midgard, set `compiler = "/home/emile/.local/bin/ymirc"` in `gyllir.toml` after a
`gyllir clean` (`.target/` is not keyed by compiler), and restore it before committing; gyllir has
no env-var or `--compiler` override.
