---
stepsCompleted:
  - step-01-init
  - step-02-discovery
  - step-02b-vision
  - step-02c-executive-summary
  - step-03-success
  - step-04-journeys
  - step-05-domain
  - step-06-innovation
  - step-07-project-type
  - step-08-scoping
  - step-09-functional
  - step-10-nonfunctional
  - step-11-polish
  - step-12-complete
inputDocuments:
  - _bmad-output/planning-artifacts/product-brief-open-agent-sdk-swift.md
  - _bmad-output/planning-artifacts/product-brief-open-agent-sdk-swift-distillate.md
  - docs/product-plan.md
  - _bmad-output/project-context.md
documentCounts:
  briefs: 2
  research: 0
  projectDocs: 1
  projectContext: 1
classification:
  projectType: desktop_app
  domain: consumer_ai_photo_management
  complexity: medium
  projectContext: greenfield
workflowType: 'prd'
---

# Product Requirements Document - AI Photo Agent (macOS)

**Author:** Nick
**Date:** 2026-04-14

## Executive Summary

**Product Vision:**

A native macOS application that replaces an entire professional photo toolchain with natural language commands. Users manage, organize, edit, and process their Apple Photos library by describing what they want — the AI agent plans the work, executes it with full transparency, and waits for user approval on critical operations.

**Target Users:** Mac users with large photo libraries (1,000+ photos) who find Apple Photos inadequate for intelligent organization, deduplication, and batch processing. They want professional-grade results without learning professional-grade tools.

**Problem:** Photo libraries grow unmanageably large while the tools to manage them remain either too basic (Apple Photos) or too complex (Lightroom, Photoshop). Users accumulate thousands of photos but lack a practical way to organize, deduplicate, rename, or enhance them at scale. Existing solutions like PowerPhotos ($30) and PhotoSweeper rely on rule-based matching — no AI, no understanding of photo content, no natural language interaction.

**Why Now:** Multimodal LLMs (Claude, GPT-4o) have reached the capability threshold where AI can genuinely understand photo content — not just detect faces and objects, but comprehend scenes, quality, context, and user intent. This creates a product window that didn't exist 12 months ago.

**Built On:** OpenAgentSDKSwift — the first real-world application constructed on the SDK, validating its agent loop, tool execution, session management, and streaming capabilities in a consumer-facing product.

### What Makes This Special

**Natural Language as the Interface.** This is not a chat app that happens to work with photos. It's an agent workspace where users express goals ("find all blurry photos and delete the duplicates"), and the agent autonomously plans a multi-step workflow: scan the library, analyze each photo for quality and similarity, group results, present for review, and execute approved changes.

**Agent Transparency and Control.** Every AI photo tool on the market is a black box — users press a button and hope. This app shows the agent's reasoning, surfaces what it found and why, and requires explicit approval before destructive operations. Users stay in control while the agent does the heavy lifting.

**SDK Validation as Strategic Asset.** As the flagship application built on OpenAgentSDKSwift, this product demonstrates that the SDK can power a real consumer application — not just developer examples. This creates a flywheel: SDK improvements benefit the app, and app requirements drive SDK evolution.

**Competitive Positioning:**
- vs Apple Photos: AI intelligence vs basic organization
- vs PowerPhotos/PhotoSweeper: Agent-driven vs rule-based
- vs Claude Desktop: Purpose-built photo agent vs general chat
- vs Lightroom: Natural language vs complex UI

## Project Classification

| Dimension | Classification |
|-----------|---------------|
| **Project Type** | Desktop Application (native macOS, SwiftUI) |
| **Domain** | Consumer AI / Photo Management |
| **Complexity** | Medium — AI infrastructure handled by SDK; complexity in PhotoKit integration, image analysis pipeline, and user trust |
| **Context** | Greenfield product built on brownfield SDK (OpenAgentSDKSwift) |
| **Distribution** | Direct website download (DMG, notarized) — not Mac App Store |

## Success Criteria

### User Success

- **Aha Moment:** User types a natural language command (e.g., "find all duplicate photos") and receives meaningful analysis results within 60 seconds
- **Trust Building:** User approves the agent's first batch operation (delete/rename/move) without anxiety
- **Habit Formation:** User opens the app at least once per week to process photos (sustained need, not novelty trial)
- **Task Completion Rate:** 90% of natural language commands are correctly understood and executed without rephrasing

### Business Success

**3 Months (Validation):**
- 100+ downloads (website distribution)
- 10+ paying users (validates willingness to pay)
- Daily personal use — the app replaces existing photo management tools for the founding team

**6 Months (Growth):**
- 500+ downloads
- 50+ paying users
- At least 1 user spontaneously recommends it to someone else

### Technical Success

- **SDK Capability Validation:** Complete end-to-end run of agent loop, tool execution, streaming, session management, custom tools, and approval workflow
- **Performance:** 1,000 photos analyzed within 5 minutes (including API call latency)
- **Stability:** Process 5,000+ photos without crashes or data loss
- **PhotoKit Integration:** Correctly read and write Apple Photos library without data corruption

### Measurable Outcomes

| Metric | MVP Target | 6-Month Target |
|--------|-----------|----------------|
| First aha completion rate | >80% | >95% |
| Monthly active users | 20 | 200 |
| Paying users | 10 | 50 |
| Photos processed per month | 1,000 | 50,000 |
| App crash rate | <2% | <0.5% |

## User Journeys

### Journey 1: Zhang — "Too Many Photos, Can't Manage Them"

**Opening:** Zhang is a 30-year-old product manager with 15,000 photos on his MacBook. Every time he opens Photos it's chaos — travel photos mixed with screenshots, duplicates everywhere, titles all start with IMG_. He tried manual organization once, gave up after 2 hours.

**Trigger:** A friend recommends the app — "just tell it what to do and it handles it." Zhang downloads it, skeptical.

**Step 1 — First Launch:**
- System requests Photos library access → Zhang hesitates, sees read-only permission explanation → approves
- Main screen shows a clean input field: "What would you like to do with your photos?"

**Step 2 — First Command:**
- Zhang types: "Help me find all duplicate photos"
- Agent starts working, showing real-time progress:
  - "Scanning your photo library... 3,200 scanned"
  - "Analyzing image similarity... found 47 potential duplicate groups"
  - "Confirming duplicates with AI... 34 groups confirmed"
- Zhang watches the progress — feels like "this thing is actually doing work"

**Step 3 — Review Results:**
- Agent displays 34 duplicate groups with side-by-side comparison and explanation for each match
- Zhang browses several groups — accuracy is impressive (burst shots, copies across folders)
- Clicks "Approve All" to remove duplicates

**Climax:** 3 minutes later, 34 duplicate groups resolved. Zhang's photo library feels "cleaner" for the first time. Trust begins.

**Resolution:** Zhang types "Rename last year's National Day photos" — another success. Decides to use it weekly.

**Capabilities Required:** PhotoKit read access, natural language parsing, smart deduplication engine, AI visual similarity analysis, real-time progress display, batch operation preview and approval

### Journey 2: Li — "Organize Albums by Theme"

**Opening:** Li is a travel blogger with 30,000 photos spanning 5 years of trips. She wants albums organized by destination and theme, but Photos auto-categorization is useless — it groups "beach" and "snow mountain" both as "landscape."

**Trigger:** Needs to organize photos for a new blog post, grouped by city and theme.

**Step 1:**
- Li types: "Organize all my travel photos into albums by city and theme"
- Agent responds: "I'll analyze ~30,000 photos by city and theme. This will take 15-20 minutes. Start?"

**Step 2 — Agent Analyzing:**
- Real-time progress display
- Discovers: Beijing 1,200, Tokyo 800, Paris 600... plus themes like "food," "architecture," "street photography"
- Agent asks a question mid-process: "300 photos can't be matched to a city (indoor/close-up shots). Should I try categorizing them by theme instead?"

**Step 3 — Review:**
- 15 suggested albums displayed with cover photo and count
- Li adjusts a few: merges "Tokyo food" and "Osaka food" into "Japan food"
- Approves creation

**Climax:** 15 smart albums created instantly — 5 years of photos organized for the first time. Agent even separated "sunset" from "sunrise" — Li is impressed.

**Resolution:** Li recommends the app to fellow travel bloggers.

**Capabilities Required:** Large-scale photo analysis, AI scene recognition, geo/time clustering, interactive category adjustment, batch album creation, mid-process clarification

### Journey 3: Wang — "I Don't Trust AI Touching My Photos"

**Opening:** Wang is a 45-year-old engineer, skeptical of AI. But he has 8,000 family photos to organize — did 500 manually in two days. His wife is pushing him to finish.

**Trigger:** Wife says "try this AI tool, stop doing it manually."

**Step 1 — Cautious Start:**
- Wang sees photo library access request, immediately suspicious
- App shows clear privacy notice: photos analyzed in-session only, sent to LLM API for understanding, never stored on third-party servers
- Wang decides to try a small, safe task first

**Step 2 — Small-Scale Test:**
- Wang types: "Find all blurry photos in my library" (a read-only task, no deletion)
- Agent scans without modifying anything
- Displays 23 blurry photos with blur reason (camera shake, missed focus, motion blur)

**Step 3 — Building Trust:**
- Wang checks several — accuracy is good
- Sees that every operation requires his approval, agent never auto-deletes
- Starts to relax, tries a bolder task: "Rename last month's family gathering photos"

**Climax:** Renaming results are precise — "IMG_9021.jpg" becomes "2026-03 Family Gathering - Xiao Ming Blowing Candles.jpg". Wang's first "AI actually understands my photos" moment.

**Resolution:** Wang doesn't delete anything (chooses conservative approach), but starts using the app to analyze and understand his library. Trust builds gradually.

**Capabilities Required:** Privacy transparency, read-only analysis mode, detailed result explanations, progressive permission control, non-destructive operations by default, undo mechanism

### Journey 4: Alex — "API Key Config and Model Switching"

**Opening:** Alex is a developer and early OpenAgentSDKSwift user. He wants to use his own API keys and compare photo analysis quality across models.

**Step 1:**
- Opens settings, enters Anthropic API Key
- Also configures an OpenAI-compatible DeepSeek key as fallback
- Sets Claude as default for photo analysis, DeepSeek for simple tasks (cost savings)

**Step 2:**
- Processing 5,000 photos when Claude API hits rate limit
- App auto-falls back to DeepSeek, continues processing
- Completion shows cost report: Claude $2.30 + DeepSeek $0.40 = $2.70 total

**Capabilities Required:** Multi-provider API key management, default model selection, automatic failover, cost tracking and reporting, model comparison

### Journey Requirements Summary

| Journey | Core Capabilities Revealed |
|---------|---------------------------|
| Zhang — Deduplication | Dedup engine, real-time progress, batch approval |
| Li — Smart Albums | Large-scale analysis, scene recognition, interactive categorization |
| Wang — Trust Building | Privacy transparency, read-only mode, progressive trust |
| Alex — Model Config | Multi-provider, failover, cost tracking |

## Domain-Specific Requirements

### Privacy & Data Safety

- **Transparency First:** App must clearly communicate what data is sent to LLM APIs, for what purpose, and what the provider's data retention policy is
- **No Third-Party Storage:** Photos analyzed in-session only; no photos stored on any third-party server beyond the LLM API call
- **Local-First Caching:** All thumbnails, metadata caches, and analysis results stored locally on device
- **Consent Before Upload:** User must explicitly approve before any photo is sent to an external API

### PhotoKit API Constraints

- **Read-Only Default:** App starts with read-only access; write operations require explicit user upgrade
- **Metadata Limitations:** Some photo metadata fields are read-only via PhotoKit; app must handle gracefully
- **Performance at Scale:** PhotoKit queries on 10,000+ photos require pagination and background fetching
- **Sandbox Boundaries:** App must operate within macOS sandbox constraints for file access

### Data Integrity (Critical)

- **All Write Operations Reversible:** Every modification (rename, delete, move, metadata change) must be undoable
- **Pre-Operation Backup:** Batch operations automatically snapshot affected metadata before execution
- **Rollback on Failure:** If a batch operation fails mid-way, automatically rollback completed items
- **Never Modify Original Files:** Agent operates on Photos library metadata and organization, never overwrites original image files

### LLM Cost Management

- **Pre-Execution Cost Estimate:** Before large operations, display estimated API cost based on photo count and selected model
- **Smart Batching:** Use local algorithms (perceptual hashing, metadata analysis) to pre-filter before sending to LLM
- **Rate Limit Handling:** Graceful degradation when API rate limits are hit (queue, retry, fallback to alternate provider)
- **Cost Dashboard:** Track and display cumulative API spending per session/week/month

### macOS Distribution Requirements

- **Apple Developer Signing:** App signed with Developer ID certificate
- **Notarization:** All builds submitted for Apple notarization (required for Gatekeeper bypass)
- **Hardened Runtime:** Compatible with hardened runtime requirements
- **Entitlements:** Properly declare `com.apple.security.personal-information.photos` entitlement

## Innovation & Novel Patterns

### Detected Innovation Areas

**1. Agent-Native Photo Management**
Traditional photo tools follow a "user operates → tool executes" model. This product inverts the paradigm: **user expresses intent → agent autonomously plans and executes**. Users don't need to know "how to deduplicate" — they say "clean up my duplicate photos" and the agent handles it. This is a paradigm shift from "tool" to "intelligent agent."

**2. Transparent Agent Execution**
All AI photo tools on the market (including Google Photos AI categorization) are black boxes. Users don't know how the AI made its decisions. This product makes the agent's reasoning fully visible — why were these two photos flagged as duplicates? Why this name? Why this grouping? Users can see the "why," which is how trust is built.

**3. SDK-Powered Consumer App**
Most AI desktop apps either wrap the OpenAI SDK for simple chat or build agent logic from scratch. This product uses a purpose-built Agent SDK (OpenAgentSDKSwift) to power a consumer application, proving that "an Agent SDK isn't just a developer tool — it can drive a real consumer-grade product."

### Market Context & Competitive Landscape

| Competitor | Approach | Limitation |
|-----------|----------|------------|
| Apple Photos | Rule-based auto-categorization | No AI understanding, rigid categories |
| PowerPhotos | Database-style duplicate matching | No visual AI, no natural language |
| PhotoSweeper | Perceptual hashing for dedup | Single-purpose, no agent intelligence |
| Claude Desktop | General AI chat | Not purpose-built for photo management |
| Google Photos | Cloud AI classification | Privacy concerns, no local control |

**Market Gap:** No product combines AI agent capabilities + PhotoKit integration + natural language interface + transparent execution.

### Validation Approach

- **MVP Validation:** 10 users complete their first dedup or rename task with 90%+ success rate
- **Differentiation Validation:** Users spontaneously mention "this is better than PowerPhotos because..." (proves differentiation is perceived)
- **SDK Validation:** Complete agent loop runs without failure in production environment

## Desktop Application Specific Requirements

### Platform Support

- **Minimum Version:** macOS 15+ (Sequoia) — aligns with developer environment and latest SwiftUI APIs
- **Architecture:** Apple Silicon (arm64) only for MVP; Intel (x86_64) as growth-phase addition if demand exists
- **No iOS/iPadOS:** PhotoKit behavior differs significantly on iOS; desktop-first experience
- **No Windows/Linux:** PhotoKit is Apple-only; cross-platform would require a fundamentally different architecture

### System Integration

**PhotoKit Integration (Core):**
- Read access: Browse photo libraries, albums, smart albums, folders
- Write access: Create/delete albums, modify photo metadata (title, description, keywords), move photos between albums
- Asset management: Access full-resolution images and thumbnails for AI analysis
- Library monitoring: Detect changes to the library made externally (e.g., user adds photos via iPhone sync)

**macOS Native Features:**
- Drag-and-drop: Accept photo files/folders from Finder into the app
- Finder Quick Action (Post-MVP): Right-click photos → "Analyze with [App Name]"
- Menu bar icon (Post-MVP): Quick access to recent tasks and status
- Notification Center: Alert when long-running tasks complete
- Spotlight indexing (Post-MVP): Make processed photo metadata searchable

### Update Strategy

- **Auto-Update:** Sparkle 2 framework (industry standard for non-App Store Mac apps)
- **Update Channel:** Stable releases via website RSS/appcast feed
- **Delta Updates:** Support delta updates to minimize download size
- **Manual Check:** Menu option to check for updates

### Offline Capabilities

- **Offline Mode:** App launches and displays cached photo library data when no internet
- **Local Operations:** Perceptual hashing (pHash), metadata analysis, library browsing work offline
- **Clear Offline Indicator:** UI shows when LLM-dependent features are unavailable
- **Offline Queue (Post-MVP):** Queue natural language commands for execution when connectivity returns

### Implementation Considerations

**SwiftUI + AppKit Bridge:**
- SwiftUI for primary UI (leverages macOS 15+ APIs)
- AppKit interop where needed (PhotoKit operations, menu bar, dock integration)
- No UIKit — macOS only

**SDK Integration Architecture:**
- OpenAgentSDKSwift as a Swift Package Manager dependency
- Custom SDK tools for PhotoKit operations (read library, modify metadata, manage albums)
- Custom SDK tools for image analysis pipeline (thumbnail generation, local hashing, API dispatch)
- Agent streaming via `AsyncStream<SDKMessage>` piped to SwiftUI views

**Performance:**
- Background thread for all PhotoKit and image processing operations
- Thumbnail cache to avoid re-processing
- Pagination for large libraries (load 100 photos at a time)
- Memory budget: cap at 500MB for photo processing pipeline

## Project Scoping & Phased Development

### MVP Strategy & Philosophy

**MVP Approach:** Problem-Solving MVP — validate the core hypothesis: **"Users will use natural language to let an AI Agent manage their photos, and will pay for it."**

The MVP is not the product with the fewest features — it's the product that learns the fastest. We need the minimum experience that lets users say "this is better than PowerPhotos."

**Core Hypothesis:** Natural language + AI Agent is more efficient at managing photo libraries than traditional toolchains.

**Validation Signal:** 10 users complete their first dedup or rename task, and at least 5 spontaneously perform a second operation.

### MVP Feature Set (Phase 1)

**Core User Journeys Supported:**
- Journey 1 (Zhang): Deduplication — most common photo management need, fastest to validate value
- Journey 3 (Wang): Trust building — read-only analysis + progressive trust, the on-ramp for all users
- Journey 4 (Alex) partial: API Key configuration — basic multi-provider support

**Must-Have Capabilities:**

| # | Capability | Why Must-Have |
|---|-----------|--------------|
| 1 | PhotoKit read access | No photo data = no product |
| 2 | Natural language input → Agent execution | Core differentiator; without this, the product doesn't exist |
| 3 | Smart deduplication (local pHash + LLM confirmation) | Highest-frequency need, fastest value validation |
| 4 | AI-powered renaming | Second highest-frequency need, demonstrates AI understanding |
| 5 | Agent execution visualization | Core of trust building — users must see what the agent is doing |
| 6 | User approval for destructive operations | Safety baseline — without this, users won't use the app |
| 7 | API Key management (Anthropic + OpenAI-compatible) | BYOK is the business model foundation |
| 8 | Cost estimate (show projected spend before execution) | Users need to know the cost before their first operation |

**Explicitly Deferred from MVP:**
- Smart album creation (Journey 2) — valuable but complex; dedup and renaming validate the core hypothesis first
- Drag-and-drop — useful but not the core interaction
- Menu bar / Finder integration — system integration is nice-to-have
- Offline queue — edge case
- Intel Mac support — testing cost not justified for MVP

### Post-MVP Features

**Phase 2 (Growth — Months 4-6):**
- Smart album creation by event/theme/people
- Photo quality detection (blur, overexposure)
- Batch editing commands
- Drag-and-drop file/folder support
- Processing history with undo
- Intel Mac support (if demand exists)

**Phase 3 (Expansion — Months 7-12):**
- Menu bar quick access + Finder Quick Action
- Local model support (Ollama, privacy-first)
- MCP server integration
- Multi-language support
- iCloud Photo Library deep integration
- Multi-agent collaboration

### Risk Mitigation Strategy

**Technical Risks:**

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| PhotoKit API limitations exceed expectations | Medium | High | MVP starts read-only; write operations as second milestone |
| LLM visual understanding inaccurate | Medium | High | Local pHash pre-filter + LLM only for final confirmation, reducing error surface |
| Performance issues with large libraries (10,000+) | Medium | Medium | Paginated loading + background processing + progress display, no UI blocking |
| API costs exceed user expectations | Low | High | Mandatory cost estimate before execution, user can cancel |

**Market Risks:**

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Users distrust AI touching photos | High | High | Read-only analysis first, all operations require approval, transparent execution |
| BYOK model too high barrier | High | Medium | Clear API key setup guide, consider built-in credits in growth phase |
| Major tech company enters this space | Low | High | Niche focus + macOS native advantage; big players won't bother with this niche |

**Resource Risks:**

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Solo developer bandwidth limited | High | Medium | Strict MVP scope control, Phase 2 delivered one feature at a time by priority |
| SDK bugs block app development | Medium | High | App development drives SDK improvements, creating a positive feedback loop |

## Functional Requirements

### Photo Library Access

- FR1: User can grant the app read access to their Apple Photos library
- FR2: User can browse their complete photo library including albums, smart albums, and folders
- FR3: User can view photo thumbnails and metadata (date, title, description, keywords, location)
- FR4: System can detect external changes to the photo library (e.g., new photos synced from iPhone)
- FR5: System can paginate through large photo libraries without blocking the UI
- FR6: User can grant the app write access to modify photo metadata and create/delete albums
- FR7: System can access full-resolution photo assets for AI analysis

### Natural Language Interaction

- FR8: User can input natural language commands to instruct the agent (e.g., "find all duplicate photos")
- FR9: System can parse natural language commands into actionable agent tasks
- FR10: System can ask clarifying questions when the user's intent is ambiguous
- FR11: User can view and continue previous conversation sessions
- FR12: System can handle multi-turn conversations for complex photo management tasks

### Agent Execution & Visualization

- FR13: System can execute multi-step agent workflows autonomously based on user commands
- FR14: User can view real-time agent execution progress (which step, how many photos processed, current action)
- FR15: User can view the agent's reasoning for each decision (why flagged as duplicate, why this name suggested)
- FR16: System can stream agent execution updates to the UI without blocking user interaction
- FR17: User can cancel an in-progress agent task at any time

### Photo Analysis — Deduplication

- FR18: User can request duplicate photo detection across their entire library
- FR19: System can detect visually similar photos using local perceptual hashing algorithms
- FR20: System can use LLM-based analysis to confirm whether visually similar photos are true duplicates
- FR21: User can review duplicate groups with side-by-side comparison and AI explanation for each match
- FR22: User can approve or reject individual duplicate groups before any deletion occurs
- FR23: User can batch-approve or batch-reject all suggested duplicate removals

### Photo Analysis — AI Renaming

- FR24: User can request AI-powered renaming for selected photos or entire albums
- FR25: System can analyze photo content and generate descriptive titles in the user's preferred language
- FR26: User can review suggested names before they are applied
- FR27: User can modify individual suggested names before approval
- FR28: System can rename photos in batch after user approval

### Photo Analysis — Smart Albums (Post-MVP)

- FR29: User can request automatic album creation organized by event, theme, or people
- FR30: System can cluster photos by visual similarity, time proximity, and geographic location
- FR31: User can interactively adjust suggested album groupings before creation
- FR32: System can create albums in the Apple Photos library after user approval

### User Control & Safety

- FR33: System requires explicit user approval before any destructive operation (delete, move, rename)
- FR34: User can undo any batch operation within a configurable time window
- FR35: System creates a metadata snapshot before any batch modification for rollback purposes
- FR36: System automatically rolls back completed items if a batch operation fails mid-execution
- FR37: User can operate in read-only analysis mode without any write operations
- FR38: System never modifies original image files — only metadata and organization

### Privacy & Transparency

- FR39: System displays a clear privacy notice explaining what data is sent to LLM APIs
- FR40: User can see which specific photos were sent for LLM analysis and why
- FR41: System does not store user photos on any third-party server beyond the LLM API call
- FR42: All local caches (thumbnails, analysis results) are stored on-device only

### Provider & Cost Management

- FR43: User can configure API keys for multiple LLM providers (Anthropic, OpenAI-compatible)
- FR44: User can select a default provider for photo analysis tasks
- FR45: User can configure a fallback provider for automatic failover when the primary provider is unavailable
- FR46: System displays a cost estimate before executing large-scale analysis tasks
- FR47: System tracks and displays cumulative API spending per session and per month
- FR48: System gracefully handles API rate limits by queuing, retrying, or falling back

### App Infrastructure

- FR49: System checks for and installs app updates automatically via Sparkle framework
- FR50: System can launch and display cached photo library data when offline
- FR51: System clearly indicates when LLM-dependent features are unavailable due to no internet
- FR52: Local operations (browsing, perceptual hashing, metadata analysis) work without internet

## Non-Functional Requirements

### Performance

- NFR1: App launches to interactive state within 3 seconds on Apple Silicon Mac
- NFR2: Photo library browsing scrolls at 60fps with thumbnail grid view
- NFR3: Agent execution progress updates appear in UI within 500ms of event
- NFR4: Perceptual hashing processes 100 photos per minute on Apple Silicon
- NFR5: Library scan of 10,000 photos completes initial metadata indexing within 60 seconds
- NFR6: Memory usage stays below 500MB during photo processing operations
- NFR7: UI remains responsive (no spinning cursor) during all background agent tasks
- NFR8: Photo thumbnail grid loads next page within 200ms when scrolling

### Security

- NFR9: API keys are stored in macOS Keychain, never in plaintext or config files
- NFR10: Photo data sent to LLM APIs uses HTTPS/TLS encryption in transit
- NFR11: Local analysis cache is stored in app's sandbox container, inaccessible to other apps
- NFR12: App does not log or cache full-resolution photo data after analysis completes
- NFR13: User can clear all local caches and analysis history from settings
- NFR14: App binary is signed with Apple Developer ID and notarized by Apple

### Data Integrity

- NFR15: Zero tolerance for photo file corruption — app never writes to original image files
- NFR16: Batch operations create metadata backup before execution; rollback completes within 5 seconds
- NFR17: App handles unexpected termination (crash, force-quit) without losing in-progress metadata changes
- NFR18: Library scan detects and reports inconsistencies in photo library state

### Integration Quality

- NFR19: PhotoKit operations handle permission changes gracefully (user revokes access mid-session)
- NFR20: LLM API calls implement exponential backoff with max 3 retries before reporting failure
- NFR21: Provider failover completes within 10 seconds of primary provider failure
- NFR22: Sparkle auto-update checks occur once per day, do not interrupt active agent tasks
- NFR23: App remains functional when PhotoKit returns partial results (e.g., iCloud photos not yet downloaded)
