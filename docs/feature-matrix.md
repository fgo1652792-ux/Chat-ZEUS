# Feature matrix

Status reflects the shipped source and the evidence linked in the [progress report](IMPLEMENTATION_PROGRESS.md). Provider contract fixtures exercise production request formats. Paid live validation requires a user-supplied credential.

| Feature | UI | Engine | Provider / Prerequisites | Tests | Platforms | Status | Known limitations |
| --- | --- | --- | --- | --- | --- | --- | --- |
| C01 محادثة جديدة | Conversations | Local SQLite + Flutter | Local; model provider for generation | Chromium onboarding and new conversation | See phase evidence | tested | — |
| C02 حفظ بعد restart | Conversations | Local SQLite + Flutter | Local; model provider for generation | Chromium reload and SQLite persistence | See phase evidence | tested | — |
| C03 محادثات متعددة | Conversations | Local SQLite + Flutter | Local; model provider for generation | Conversation ownership fixture | See phase evidence | tested | — |
| C04 تغيير النموذج | Conversations | Local SQLite + Flutter | Local; model provider for generation | App analysis and related tests | See phase evidence | implemented | See current platform coverage in the progress report. |
| C05 حفظ المسودة | Conversations | Local SQLite + Flutter | Local; model provider for generation | App analysis and related tests | See phase evidence | implemented | See current platform coverage in the progress report. |
| C06 إصلاح reconnect | Conversations | Local SQLite + Flutter | Local; model provider for generation | See related phase evidence | See phase evidence | partial | Interrupted state and retry are available. Provider stream cursor replay remains pending. |
| C07 Stop | Conversations | Local SQLite + Flutter | Local; model provider for generation | Loopback HTTP cancellation and partial SQLite history | See phase evidence | tested | — |
| C08 Retry | Conversations | Local SQLite + Flutter | Local; model provider for generation | App analysis and related tests | See phase evidence | implemented | See current platform coverage in the progress report. |
| C09 Edit | Conversations | Local SQLite + Flutter | Local; model provider for generation | Edited branch fixture | See phase evidence | tested | — |
| C10 Branch | Conversations | Local SQLite + Flutter | Local; model provider for generation | Branch isolation fixture | See phase evidence | tested | — |
| C11 Search | Conversations | Local SQLite + Flutter | Local; model provider for generation | SQLite history search fixture | See phase evidence | tested | — |
| C12 Archive | Conversations | Local SQLite + Flutter | Local; model provider for generation | App analysis and related tests | See phase evidence | implemented | See current platform coverage in the progress report. |
| C13 Export | Conversations | Local SQLite + Flutter | Local; model provider for generation | App analysis and related tests | See phase evidence | implemented | See current platform coverage in the progress report. |
| C14 Share | Conversations | Local SQLite + Flutter | Local; model provider for generation | App analysis and related tests | See phase evidence | implemented | See current platform coverage in the progress report. |
| C15 Delete | Conversations | Local SQLite + Flutter | Local; model provider for generation | See related phase evidence | See phase evidence | partial | Trash supports restore. Permanent deletion from the UI remains pending. |
| C16 Undo delete | Conversations | Local SQLite + Flutter | Local; model provider for generation | Trash and restore fixture | See phase evidence | tested | — |
| C17 Rename | Conversations | Local SQLite + Flutter | Local; model provider for generation | App analysis and related tests | See phase evidence | implemented | See current platform coverage in the progress report. |
| C18 Favorites | Conversations | Local SQLite + Flutter | Local; model provider for generation | App analysis and related tests | See phase evidence | implemented | See current platform coverage in the progress report. |
| C19 Project move | Conversations | Local SQLite + Flutter | Local; model provider for generation | App analysis and related tests | See phase evidence | implemented | See current platform coverage in the progress report. |
| C20 Per-message provider/model info | Conversations | Local SQLite + Flutter | Local; model provider for generation | App analysis and related tests | See phase evidence | implemented | See current platform coverage in the progress report. |
| P01 ربط OpenAI | Providers and model picker | Provider adapters | A compatible provider connection | Protocol or platform integration | See phase evidence | needs_key | Live provider or device validation pending. |
| P02 ربط Claude | Providers and model picker | Provider adapters | A compatible provider connection | Protocol or platform integration | See phase evidence | needs_key | Live provider or device validation pending. |
| P03 ربط Gemini | Providers and model picker | Provider adapters | A compatible provider connection | Protocol or platform integration | See phase evidence | needs_key | Live provider or device validation pending. |
| P04 ربط OpenRouter | Providers and model picker | Provider adapters | A compatible provider connection | Protocol or platform integration | See phase evidence | needs_key | Live provider or device validation pending. |
| P05 ربط xAI | Providers and model picker | Provider adapters | A compatible provider connection | Protocol or platform integration | See phase evidence | needs_key | Live provider or device validation pending. |
| P06 DeepSeek | Providers and model picker | Provider adapters | A compatible provider connection | Protocol or platform integration | See phase evidence | needs_key | Live provider or device validation pending. |
| P07 OpenAI-compatible | Providers and model picker | Provider adapters | A compatible provider connection | Protocol or platform integration | See phase evidence | needs_key | Live provider or device validation pending. |
| P08 Ollama | Providers and model picker | Provider adapters | A compatible provider connection | Protocol or platform integration | See phase evidence | needs_key | Live provider or device validation pending. |
| P09 Test key | Providers and model picker | Provider adapters | A compatible provider connection | Protocol or platform integration | See phase evidence | needs_key | Live provider or device validation pending. |
| P10 Discover models | Providers and model picker | Provider adapters | A compatible provider connection | App analysis and related tests | See phase evidence | implemented | See current platform coverage in the progress report. |
| P11 Manual model ID | Providers and model picker | Provider adapters | A compatible provider connection | App analysis and related tests | See phase evidence | implemented | See current platform coverage in the progress report. |
| P12 Capability gating | Providers and model picker | Provider adapters | A compatible provider connection | See related phase evidence | See phase evidence | partial | Discovery exposes provider metadata. Full capability gating remains pending. |
| P13 Native SSE | Providers and model picker | Provider adapters | A compatible provider connection | Loopback SSE contract | See phase evidence | tested | — |
| P14 Stream first chunk before complete | Providers and model picker | Provider adapters | A compatible provider connection | Loopback early UTF-8 delta and UI test | See phase evidence | tested | — |
| P15 Tool stream | Providers and model picker | Provider adapters | A compatible provider connection | See related phase evidence | See phase evidence | partial | Manual MCP tool calls exist. Native provider tool deltas remain pending. |
| P16 Cancel actual network | Providers and model picker | Provider adapters | A compatible provider connection | Loopback cancellation contract | See phase evidence | tested | — |
| P17 429 retry policy | Providers and model picker | Provider adapters | A compatible provider connection | See related phase evidence | See phase evidence | partial | HTTP 429 exposes the retry delay. Automatic replay remains pending. |
| P18 Usage metadata | Providers and model picker | Provider adapters | A compatible provider connection | NDJSON usage contract | See phase evidence | tested | — |
| P19 Provider fallback with consent | Providers and model picker | Provider adapters | A compatible provider connection | See related phase evidence | See phase evidence | partial | Manual provider switch prompts before sharing conversation context. |
| P20 Secure persisted key | Providers and model picker | Provider adapters | A compatible provider connection | See related phase evidence | See phase evidence | partial | Device secure storage and web session-only storage are wired. Signed-device persistence is pending. |
| R01 Headings/lists | Message renderer | Typed Flutter widgets | Supported input format | Rich message widget fixture | See phase evidence | tested | — |
| R02 Tables | Message renderer | Typed Flutter widgets | Supported input format | Rich message widget fixture | See phase evidence | tested | — |
| R03 Code syntax | Message renderer | Typed Flutter widgets | Supported input format | Code card widget fixture | See phase evidence | tested | — |
| R04 Code copying | Message renderer | Typed Flutter widgets | Supported input format | App analysis and related tests | See phase evidence | implemented | See current platform coverage in the progress report. |
| R05 Checklists | Message renderer | Typed Flutter widgets | Supported input format | App analysis and related tests | See phase evidence | implemented | See current platform coverage in the progress report. |
| R06 LaTeX | Message renderer | Typed Flutter widgets | Supported input format | App analysis and related tests | See phase evidence | implemented | See current platform coverage in the progress report. |
| R07 Mermaid | Message renderer | Typed Flutter widgets | Supported input format | See related phase evidence | See phase evidence | partial | Safe flowchart subset. Other Mermaid syntax remains readable source. |
| R08 Charts | Message renderer | Typed Flutter widgets | Supported input format | Bar chart widget fixture | See phase evidence | tested | — |
| R09 Source citations | Message renderer | Typed Flutter widgets | Supported input format | See related phase evidence | See phase evidence | partial | Research results preserve source URLs. Inline claim-to-source mapping remains pending. |
| R10 SVG safe | — | — | — | — | — | pending | Implementation pending. |
| R11 Image gallery | Message renderer | Typed Flutter widgets | Supported input format | See related phase evidence | See phase evidence | partial | Local Image Studio gallery. Rich-message gallery blocks remain pending. |
| R12 Audio playback | — | — | — | — | — | pending | Implementation pending. |
| R13 PDF preview | Message renderer | Typed Flutter widgets | Supported input format | See related phase evidence | See phase evidence | partial | PDF preview is available from conversation attachments. |
| R14 Files artifacts | Message renderer | Typed Flutter widgets | Supported input format | See related phase evidence | See phase evidence | partial | Existing files, Markdown exports and generated images are available. Other generated formats remain pending. |
| R15 Input widget | — | — | — | — | — | pending | Implementation pending. |
| R16 Interactive selection | — | — | — | — | — | pending | Implementation pending. |
| R17 Editable writing block | — | — | — | — | — | pending | Implementation pending. |
| R18 Error fallback | — | — | — | — | — | pending | Implementation pending. |
| R19 RTL rendering | Message renderer | Typed Flutter widgets | Supported input format | RTL large text widget fixture | See phase evidence | tested | — |
| R20 Secure HTML sandbox | Message renderer | Typed Flutter widgets | Supported input format | See related phase evidence | See phase evidence | partial | Model HTML is never executed. Executable HTML preview is pending. |
| M01 Image upload | Attachments, audio, or Image Studio | Media and platform adapters | Platform permissions or a compatible model | See related phase evidence | See phase evidence | partial | Local image attachment or explicit OpenAI Image Studio input. Inline vision attachments remain pending. |
| M02 Camera | — | — | — | — | — | pending | Implementation pending. |
| M03 Screenshot paste | — | — | — | — | — | pending | Implementation pending. |
| M04 Vision request | Attachments, audio, or Image Studio | Media and platform adapters | Platform permissions or a compatible model | Protocol or platform integration | See phase evidence | needs_key | Live provider or device validation pending. |
| M05 Image generate | Attachments, audio, or Image Studio | Media and platform adapters | Platform permissions or a compatible model | Protocol or platform integration | See phase evidence | needs_key | Live provider or device validation pending. |
| M06 Image edit | Attachments, audio, or Image Studio | Media and platform adapters | Platform permissions or a compatible model | Protocol or platform integration | See phase evidence | needs_key | Live provider or device validation pending. |
| M07 STT | Attachments, audio, or Image Studio | Media and platform adapters | Platform permissions or a compatible model | Protocol or platform integration | See phase evidence | needs_key | Live provider or device validation pending. |
| M08 TTS | Attachments, audio, or Image Studio | Media and platform adapters | Platform permissions or a compatible model | Protocol or platform integration | See phase evidence | needs_key | Live provider or device validation pending. |
| M09 Streaming voice | — | — | — | — | — | pending | Implementation pending. |
| M10 Interrupt voice | — | — | — | — | — | pending | Implementation pending. |
| M11 Video analysis | — | — | — | — | — | pending | Implementation pending. |
| M12 Video output when supported | — | — | — | — | — | pending | Implementation pending. |
| M13 PDF parse | Attachments, audio, or Image Studio | Media and platform adapters | Platform permissions or a compatible model | App analysis and related tests | See phase evidence | implemented | See current platform coverage in the progress report. |
| M14 DOCX parse | — | — | — | — | — | pending | Implementation pending. |
| M15 XLSX parse | — | — | — | — | — | pending | Implementation pending. |
| M16 ZIP/file safety | Attachments, audio, or Image Studio | Media and platform adapters | Platform permissions or a compatible model | Type signatures, size and isolation fixture | See phase evidence | tested | — |
| M17 Multi-attachment | Attachments, audio, or Image Studio | Media and platform adapters | Platform permissions or a compatible model | See related phase evidence | See phase evidence | partial | Multiple local files. Text is sent after insertion into the draft. |
| M18 Long file indexing | — | — | — | — | — | pending | Implementation pending. |
| M19 File citations | Attachments, audio, or Image Studio | Media and platform adapters | Platform permissions or a compatible model | App analysis and related tests | See phase evidence | implemented | See current platform coverage in the progress report. |
| M20 Background upload progress | Attachments, audio, or Image Studio | Media and platform adapters | Platform permissions or a compatible model | See related phase evidence | See phase evidence | partial | File import progress indicator. Background uploads remain pending. |
| A01 Search BYOK | Research, MCP, or Hub | Bounded adapters | Brave Search, a compatible MCP endpoint, or Zeus Hub | Protocol or platform integration | See phase evidence | needs_key | Live provider or device validation pending. |
| A02 Citations verified | Research, MCP, or Hub | Bounded adapters | Brave Search, a compatible MCP endpoint, or Zeus Hub | See related phase evidence | See phase evidence | partial | Source URLs come from search result responses. Claim verification remains pending. |
| A03 Deep research plan | Research, MCP, or Hub | Bounded adapters | Brave Search, a compatible MCP endpoint, or Zeus Hub | See related phase evidence | See phase evidence | partial | Multi-query plan and progress. Automated deep-research synthesis remains pending. |
| A04 Source reading | Research, MCP, or Hub | Bounded adapters | Brave Search, a compatible MCP endpoint, or Zeus Hub | See related phase evidence | See phase evidence | partial | Source URLs open externally. Page extraction is pending. |
| A05 File RAG | Research, MCP, or Hub | Bounded adapters | Brave Search, a compatible MCP endpoint, or Zeus Hub | See related phase evidence | See phase evidence | partial | Project notes are included as context. Indexed retrieval remains pending. |
| A06 Local code sandbox | — | — | — | — | — | pending | Implementation pending. |
| A07 Chart calculation | Research, MCP, or Hub | Bounded adapters | Brave Search, a compatible MCP endpoint, or Zeus Hub | See related phase evidence | See phase evidence | partial | Bar charts render bounded numeric data. Analysis pipeline is pending. |
| A08 DOCX creation | — | — | — | — | — | pending | Implementation pending. |
| A09 PDF creation | — | — | — | — | — | pending | Implementation pending. |
| A10 XLSX creation | — | — | — | — | — | pending | Implementation pending. |
| A11 PPTX creation | — | — | — | — | — | pending | Implementation pending. |
| A12 Tool schema | Research, MCP, or Hub | Bounded adapters | Brave Search, a compatible MCP endpoint, or Zeus Hub | MCP requested argument contract | See phase evidence | tested | — |
| A13 Approval prompts | Research, MCP, or Hub | Bounded adapters | Brave Search, a compatible MCP endpoint, or Zeus Hub | App analysis and related tests | See phase evidence | implemented | See current platform coverage in the progress report. |
| A14 Parallel tool handling | — | — | — | — | — | pending | Implementation pending. |
| A15 MCP client | Research, MCP, or Hub | Bounded adapters | Brave Search, a compatible MCP endpoint, or Zeus Hub | MCP session and tool invocation contract | See phase evidence | tested | — |
| A16 OAuth connectors | — | — | — | — | — | pending | Implementation pending. |
| A17 Browser sandbox | — | — | — | — | — | pending | Implementation pending. |
| A18 Scheduled jobs | Research, MCP, or Hub | Bounded adapters | Brave Search, a compatible MCP endpoint, or Zeus Hub | App analysis and related tests | See phase evidence | implemented | See current platform coverage in the progress report. |
| A19 Resume task | Research, MCP, or Hub | Bounded adapters | Brave Search, a compatible MCP endpoint, or Zeus Hub | See related phase evidence | See phase evidence | partial | Durable summary jobs and results. General agent checkpoints are pending. |
| A20 Workflow builder | — | — | — | — | — | pending | Implementation pending. |
| S01 Project create | Workspace and Hub | SQLite or PostgreSQL | Hub required for server-side features | App analysis and related tests | See phase evidence | implemented | See current platform coverage in the progress report. |
| S02 Project instructions | Workspace and Hub | SQLite or PostgreSQL | Hub required for server-side features | Scoped project context fixture | See phase evidence | tested | — |
| S03 Project files | — | — | — | — | — | pending | Implementation pending. |
| S04 Personal memory | Workspace and Hub | SQLite or PostgreSQL | Hub required for server-side features | See related phase evidence | See phase evidence | partial | Explicit project memory is available. Personal memory outside project scope remains pending. |
| S05 Memory delete | Workspace and Hub | SQLite or PostgreSQL | Hub required for server-side features | Memory deletion fixture | See phase evidence | tested | — |
| S06 Temporary chat | Workspace and Hub | SQLite or PostgreSQL | Hub required for server-side features | App analysis and related tests | See phase evidence | implemented | See current platform coverage in the progress report. |
| S07 Custom assistant | — | — | — | — | — | pending | Implementation pending. |
| S08 Assistant import/export | — | — | — | — | — | pending | Implementation pending. |
| S09 Self-host auth | Workspace and Hub | SQLite or PostgreSQL | Hub required for server-side features | Hub session and registration contract | See phase evidence | tested | — |
| S10 Cross-device sync | Workspace and Hub | SQLite or PostgreSQL | Hub required for server-side features | See related phase evidence | See phase evidence | partial | Selected conversation upload and import. Background two-way sync remains pending. |
| S11 Conflict resolve | Workspace and Hub | SQLite or PostgreSQL | Hub required for server-side features | See related phase evidence | See phase evidence | partial | Server detects write conflicts. Client offers explicit import and preserves existing local copies. |
| S12 Offline history | Workspace and Hub | SQLite or PostgreSQL | Hub required for server-side features | App analysis and related tests | See phase evidence | implemented | See current platform coverage in the progress report. |
| S13 Local backups | — | — | — | — | — | pending | Implementation pending. |
| S14 Encrypted export | — | — | — | — | — | pending | Implementation pending. |
| S15 Share link permissions | — | — | — | — | — | pending | Implementation pending. |
| S16 Revocation | Workspace and Hub | SQLite or PostgreSQL | Hub required for server-side features | See related phase evidence | See phase evidence | partial | Hub session revocation is available. Shared links remain pending. |
| S17 Notifications | — | — | — | — | — | pending | Implementation pending. |
| S18 Data erasure | Workspace and Hub | SQLite or PostgreSQL | Hub required for server-side features | Authenticated account deletion route implemented; two-account isolation contract | See phase evidence | tested | — |
| S19 Versioned migrations | Workspace and Hub | SQLite or PostgreSQL | Hub required for server-side features | Schema 1 upgrade fixture | See phase evidence | tested | — |
| S20 Per-user isolation | Workspace and Hub | SQLite or PostgreSQL | Hub required for server-side features | Hub PostgreSQL two-account isolation | See phase evidence | tested | — |
| D01 Genuine glass surface | App and build workflows | Original UI package and CI | Available device/toolchain | 202 reference tests and iPhone/iPad smoke on Phase 01 | See phase evidence | tested | — |
| D02 Shader fallback | App and build workflows | Original UI package and CI | Available device/toolchain | Reference renderer fallback tests | See phase evidence | tested | — |
| D03 Dock press/drag | App and build workflows | Original UI package and CI | Available device/toolchain | Original dock tests | See phase evidence | tested | — |
| D04 Modal spring | App and build workflows | Original UI package and CI | Available device/toolchain | Original modal suite | See phase evidence | tested | — |
| D05 Dark/light | App and build workflows | Original UI package and CI | Available device/toolchain | App analysis and related tests | See phase evidence | implemented | See current platform coverage in the progress report. |
| D06 RTL/LTR | App and build workflows | Original UI package and CI | Available device/toolchain | RTL with large text and default English chat tests | See phase evidence | tested | — |
| D07 iPad sidebar | App and build workflows | Original UI package and CI | Available device/toolchain | Phase 01 iPad screenshot and integration | See phase evidence | tested | — |
| D08 Android layout | App and build workflows | Original UI package and CI | Available device/toolchain | See related phase evidence | See phase evidence | partial | Android platform shell exists. Runtime layout confirmation is tracked in CI. |
| D09 Desktop keyboard | App and build workflows | Original UI package and CI | Available device/toolchain | See related phase evidence | See phase evidence | partial | Desktop Flutter controls are available. Dedicated shortcut testing remains pending. |
| D10 Accessibility semantics | App and build workflows | Original UI package and CI | Available device/toolchain | Original glass semantics tests and browser accessibility tree | See phase evidence | tested | — |
| D11 Reduce motion | App and build workflows | Original UI package and CI | Available device/toolchain | Original motion suite and frontend setting | See phase evidence | tested | — |
| D12 Quality setting | App and build workflows | Original UI package and CI | Available device/toolchain | App analysis and related tests | See phase evidence | implemented | See current platform coverage in the progress report. |
| D13 Theme persistence | App and build workflows | Original UI package and CI | Available device/toolchain | App analysis and related tests | See phase evidence | implemented | See current platform coverage in the progress report. |
| D14 Screen rotation | App and build workflows | Original UI package and CI | Available device/toolchain | See related phase evidence | See phase evidence | partial | Responsive layouts exist. Device rotation verification remains pending. |
| D15 First-run onboarding | App and build workflows | Original UI package and CI | Available device/toolchain | Chromium onboarding | See phase evidence | tested | — |
| D16 Low memory test | — | — | — | — | — | pending | Implementation pending. |
| D17 Widget/golden tests | App and build workflows | Original UI package and CI | Available device/toolchain | Flutter unit and widget tests | See phase evidence | tested | — |
| D18 iOS unsigned build | App and build workflows | Original UI package and CI | Available device/toolchain | Verified Phase 01 IPA with Payload and SHA-256 | See phase evidence | tested | — |
| D19 Android build | App and build workflows | Original UI package and CI | Available device/toolchain | See related phase evidence | See phase evidence | partial | Android build workflow. See release report for verified artifacts. |
| D20 Self-host Docker startup | App and build workflows | Original UI package and CI | Available device/toolchain | See related phase evidence | See phase evidence | partial | Docker Compose definition and PostgreSQL integration tests. See release report for container smoke. |
