# ADR 0007: Hierarchical section markers for single-file navigation

## Status
Accepted

## Context
`run.sh` is a single file that would otherwise span multiple files. Without structure, the file becomes unsearchable as it grows. Vim (and similar editors) need stable, unique anchors to jump between logical sections.

## Decision
Use `§NN` section markers as unique searchable anchors throughout the file. Three levels of hierarchy:

```
§NN        — top-level section (e.g. §05 STEM RESOLUTION)
§NN.MM     — subsection / function group (e.g. §05.03 parse_run_file)
§NN.MM.KK  — individual function or block (e.g. §05.03.01 handle_include)
```

The file opens with a **master TOC** listing all `§NN` sections. Each `§NN` section opens with a **local TOC** listing its `§NN.MM` entries. This gives two levels of jump table before reaching code.

### Marker format

Section markers use `§NN` (section sign, U+00A7) only. The typeable alias is handled by a vim `cnoreabbrev`, not embedded in the file.

Section headers:
```sh
# ────────────────────────────────────────────────────────────
# §05 STEM RESOLUTION
# ────────────────────────────────────────────────────────────
# §05.01  resolve_stem()      — symlink dispatch → first positional arg
# §05.02  load_stem()         — load .run and .env for a stem
# §05.03  parse_run_file()    — parse mount paths and @include directives
# §05.04  parse_env_file()    — parse KEY=VALUE env file
```

Function headers:
```sh
# §05.03 parse_run_file STEM FILE
parse_run_file() {
```

### Master TOC format (at top of file, after shebang and vim howto)

```sh
# §01  HELP & USAGE
# §02  LOGGING
# §03  CONFIGURATION
# §04  RUN ROOT & PROJECT ROOT
# §05  STEM RESOLUTION
# §06  MOUNT CONSTRUCTION
# §07  ENVIRONMENT CONSTRUCTION
# §08  RUNTIME DETECTION & UID MAPPING
# §09  CONTAINER INVOCATION
# §10  MAIN
```

## Vim navigation howto (embedded in script header)

```sh
# VIM NAVIGATION
# ─────────────────────────────────────────────────────────────
# Section markers use § (U+00A7). To search without typing §,
# add this to .vimrc — then /ss05 finds §05, /ss05.03 finds §05.03:
#   cnoreabbrev ss §
#
# Jump to section:           /§05<CR>   (or: /ss05<CR> with abbrev)
# Jump to subsection:        /§05\.03<CR>
# List all sections:         :g/^# §[0-9]/p
# List subsections of §05:   :g/^# §05\./p
# Jump to word under cursor: yiw/<C-R>0<CR>
#
# Suggested .vimrc mappings:
#   cnoreabbrev ss §
#   nnoremap <Leader>] yiw/<C-R>0<CR>
#   nnoremap <Leader>§ :vimgrep /^# §/ % \| copen<CR>
```

## Consequences
- Every new function added to the script must carry a `§NN.MM` marker and appear in its section's local TOC.
- The master TOC is updated whenever a new `§NN` section is added.
- Section numbers are stable (never renumbered) — they are identifiers, not ordinals. Gaps are acceptable.
- This pattern extends naturally to any large single-file script in this project.
