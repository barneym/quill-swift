# Obsidian Checkboxes

Every checkbox type QuillSwift knows, matching the Obsidian vault's AnuPpuccin
theme (alternate checkboxes) and the `custom-bullet-checkboxes` snippet.
Compare this file side by side in Obsidian and in QuillSwift's preview (light and dark).

## Standard (clickable in preview)

- [ ] To Do `[ ]`
- [x] Complete `[x]`
- [X] Complete, uppercase `[X]`

## AnuPpuccin alternate checkboxes

- [/] In Progress `[/]`
- [-] Cancelled `[-]`
- [?] Question `[?]`
- [!] Important `[!]`
- [>] Rescheduled `[>]`
- [<] Scheduled `[<]`
- [*] Starred `[*]`
- ["] Quote `["]`
- [b] Bookmark `[b]`
- [c] Con `[c]`
- [d] Down `[d]`
- [f] Fire `[f]`
- [i] Info `[i]`
- [I] Idea `[I]`
- [k] Key `[k]`
- [l] Location `[l]`
- [n] Note `[n]`
- [p] Pro `[p]`
- [S] Amount/Score `[S]`
- [u] Up `[u]`
- [w] Win `[w]`

## Custom bullet-journal snippet

- [W] Waiting `[W]`
- [D] Delegated `[D]`
- [R] Research `[R]`
- [M] Meeting `[M]`
- [s] Someday/Maybe `[s]`
- [E] Energy/Important `[E]`
- [P] Priority `[P]`
- [F] Follow-up `[F]`
- [H] Habit `[H]`

## Speech bubbles

- [0] Speech bubble `[0]`
- [1] Speech bubble `[1]`
- [2] Speech bubble `[2]`
- [3] Speech bubble `[3]`
- [4] Speech bubble `[4]`
- [5] Speech bubble `[5]`
- [6] Speech bubble `[6]`
- [7] Speech bubble `[7]`
- [8] Speech bubble `[8]`
- [9] Speech bubble `[9]`

## Unregistered markers

Obsidian treats any single character as a task; QuillSwift draws a neutral checked box.

- [z] Unknown `[z]`
- [+] Plus `[+]`

## Mixed content

- [!] Important with **bold**, `code`, and a [link](https://obsidian.md)
- [*] Starred with *emphasis*
- [/] In progress parent
    - [x] Done child
    - [ ] Open child
    - [W] Waiting child
1. [D] Delegated in an ordered list
2. [>] Rescheduled in an ordered list

## Loose list

- [I] Idea in a loose list

  With a second paragraph.

- [-] Cancelled in a loose list

## Precedence

The checkbox marker always wins over emphasis:

- [*] starred item with a trailing star*
- [_] underscore marker with_trailing_underscores
- [`] backtick marker with trailing `
- [~] tilde marker ~~
