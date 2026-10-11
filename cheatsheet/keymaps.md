# Keymap cheat sheet

Open with **Super+Ctrl+Q**.

## Neovim

### Multicursors

Place extra cursors, then type once to edit at every cursor.

| Key | Action |
| --- | --- |
| `Q` | Toggle a cursor at the current position |
| `1Q` | Place a cursor at every match of the last search (`*`, `/pattern`) |
| `{Visual}Q` | Place a cursor on each line of the visual selection |
| `Ctrl-LeftMouse` | Toggle a cursor at the click without moving the primary cursor |
| `q=` | Toggle follow-mode (replay motions at every cursor) |
| `1q=` / `2q=` | Force follow-mode on / off |
| `]C` | Jump to the next cursor |
| `[C` | Jump to the previous cursor |
| `gQ` | Restore the previous set of cursors |
| `g Ctrl-A` | Insert an ascending number at each cursor (`1`, `2`, `3`, …) |
| `Ctrl-L` | Clear all extra cursors **and** stop search highlighting |

Search for a word with `*`, then type `1Q` to put a cursor on every match. Select lines with `V` and type `Q` to edit each line at once.

### Clipboard

`y` stays in Neovim's unnamed register. `<leader>y` yanks to the system clipboard.

| Key | Action |
| --- | --- |
| `<leader>y` | Yank to the system clipboard (takes a motion, like `y`) |
| `{Visual}<leader>y` | Yank the selection to the system clipboard |

### Search highlighting

| Key | Action |
| --- | --- |
| `Ctrl-L` | Stop search highlighting (also clears extra cursors) |
| `:noh` | Stop search highlighting only (`:nohlsearch`) |
