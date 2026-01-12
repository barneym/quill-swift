# Mermaid Diagram Examples

This document showcases various Mermaid diagram types supported by QuillSwift.

## Flowchart

```mermaid
flowchart TD
    A[Start] --> B{Is it working?}
    B -->|Yes| C[Great!]
    B -->|No| D[Debug]
    D --> B
    C --> E[End]
```

## Sequence Diagram

```mermaid
sequenceDiagram
    participant User
    participant App
    participant Server

    User->>App: Open document
    App->>Server: Request file
    Server-->>App: Return content
    App-->>User: Display document

    User->>App: Edit text
    App->>App: Auto-save draft

    User->>App: Save
    App->>Server: Upload file
    Server-->>App: Confirm saved
    App-->>User: Show saved status
```

## Class Diagram

```mermaid
classDiagram
    class MarkdownDocument {
        +String text
        +URL fileURL
        +save()
        +load()
    }

    class MarkdownRenderer {
        +renderHTML(markdown)
        +renderAttributedString(markdown)
    }

    class PreviewView {
        +html: String
        +theme: PreviewTheme
        +refresh()
    }

    MarkdownDocument --> MarkdownRenderer
    MarkdownRenderer --> PreviewView
```

## State Diagram

```mermaid
stateDiagram-v2
    [*] --> Draft
    Draft --> Editing: User types
    Editing --> Draft: Auto-save
    Editing --> Saved: User saves
    Saved --> Editing: User edits
    Saved --> [*]: User closes

    Draft --> [*]: Discard changes
```

## Entity Relationship Diagram

```mermaid
erDiagram
    DOCUMENT ||--o{ DRAFT : has
    DOCUMENT {
        uuid id
        string title
        text content
        datetime created
        datetime modified
    }
    DRAFT {
        uuid id
        text content
        datetime saved
    }
    USER ||--o{ DOCUMENT : owns
    USER {
        uuid id
        string name
        string email
    }
```

## Gantt Chart

```mermaid
gantt
    title QuillSwift Development
    dateFormat  YYYY-MM-DD
    section Core
    Document Model       :done, 2024-01-01, 7d
    Markdown Rendering   :done, 2024-01-08, 14d
    Source Editor        :done, 2024-01-22, 14d
    section Features
    Syntax Highlighting  :done, 2024-02-05, 7d
    Live Preview         :done, 2024-02-12, 14d
    Export Functions     :done, 2024-02-26, 7d
    section Polish
    Theming             :active, 2024-03-05, 7d
    Performance         :2024-03-12, 7d
```

## Pie Chart

```mermaid
pie title Document Types Edited
    "Markdown" : 65
    "Plain Text" : 20
    "Code" : 10
    "Other" : 5
```

## Git Graph

```mermaid
gitGraph
    commit id: "Initial"
    branch develop
    checkout develop
    commit id: "Feature A"
    commit id: "Feature B"
    checkout main
    merge develop id: "v1.0"
    commit id: "Hotfix"
    branch feature-c
    checkout feature-c
    commit id: "WIP"
    checkout main
    merge feature-c id: "v1.1"
```

## Journey Diagram

```mermaid
journey
    title User Editing Experience
    section Opening
      Launch app: 5: User
      Create new doc: 4: User
    section Editing
      Write content: 5: User
      Format text: 4: User
      Add diagrams: 3: User
    section Saving
      Preview result: 5: User
      Export to PDF: 4: User
      Share document: 5: User
```

---

*All diagrams above should render in the preview pane.*
