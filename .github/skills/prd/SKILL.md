---
name: prd
description: >
  Generate a clear, structured Product Requirements Document (PRD) for a feature
  or small product. Use when planning a feature, starting a new project, or when
  explicitly asked to create a PRD or requirements document.
disable-model-invocation: true
---

# PRD Generator Skill

You generate clear, actionable, implementation-ready Product Requirements Documents
(PRDs) that can be safely handed to junior developers or AI agents.

This skill is explicitly invoked via `/prd` and follows a strict, gated workflow.

You do NOT implement code. You only plan.

---

## Usage Contract

When this skill is invoked:

- Always clarify requirements first
- Never begin implementation
- Produce a deterministic, well-structured PRD
- Save the PRD as a markdown file

---

## Step 1: Clarifying Questions (Always Required)

Before writing the PRD, ask 3–5 essential clarifying questions.

Only ask questions that materially affect scope or design.

Focus on:
- Problem / goal
- Target user
- Scope boundaries
- Success criteria
- Technical constraints (if relevant)

### Question Format (Required)

Use multiple-choice questions with lettered options.

Example:

1. What is the primary goal of this feature?  
   A. Improve onboarding  
   B. Increase retention  
   C. Reduce operational overhead  
   D. Other: please specify  

2. Who is the target user?  
   A. New users  
   B. Existing users  
   C. Admins  
   D. All users  

Users should be able to reply with: 1A, 2C, 3B.

Do NOT generate the PRD until answers are received.

---

## Step 2: PRD Structure

Generate the PRD using only the sections below.

---

## 1. Overview

- Brief description of the feature or product
- The problem it solves
- Why this work matters now

---

## 2. Goals & Non-Goals

### Goals
- Specific, measurable outcomes
- Clear success intent

### Non-Goals (Out of Scope)
- Explicit exclusions to prevent scope creep

---

## 3. Target Users

- Primary user personas
- Technical comfort level (low / medium / high)
- Key pain points relevant to this feature

---

## 4. MVP Scope

Use checkboxes.

### In Scope (MVP)
- [ ] Core capability A
- [ ] Core capability B

### Out of Scope (Post-MVP)
- [ ] Advanced workflows
- [ ] Automation or edge cases

Group items by:
- Core functionality
- Technical
- Integrations (if applicable)

---

## 5. User Stories

User stories must be small, focused, and independently implementable.

### Required Format

Title: US-001 – Short descriptive title

Description:  
As a user, I want an action, so that I get a benefit.

Acceptance Criteria:
- [ ] Specific, verifiable condition
- [ ] Another verifiable condition
- [ ] npm run typecheck passes
- [ ] UI stories only: Verify in browser using dev-browser skill

Rules:
- Acceptance criteria must be verifiable
- Avoid vague language such as “works correctly”
- UI-related stories MUST include browser verification

---

## 6. Functional Requirements

Numbered, explicit, and testable.

Examples:
- FR-1: The system must allow users to perform X.
- FR-2: When Y occurs, the system must do Z.

Avoid unnecessary implementation details.

---

## 7. Design & UX Considerations (Optional)

- UI behavior or constraints
- Accessibility requirements
- Existing components to reuse
- Links to mockups if available

---

## 8. Technical Considerations (Optional)

- Known constraints or assumptions
- Dependencies or integrations
- Performance or scalability considerations

---

## 9. Success Criteria

Define what “done” means.

- Functional completeness
- User experience expectations
- Measurable outcomes where possible

Use checklists when appropriate.

---

## 10. Implementation Phases (High-Level)

Break work into 2–4 phases maximum.

Each phase includes:
- Goal
- Deliverables (checkboxes)
- Validation criteria

This is sequencing, not a task breakdown.

---

## 11. Risks & Mitigations

List 3–5 realistic risks.

For each risk:
- Risk: description
- Mitigation: concrete action or constraint

---

## 12. Open Questions

Unresolved items that should be revisited later.

---

## Output Rules

- Format: Markdown
- Location: /tasks/
- Filename: prd-feature-name.md (kebab-case)
- Clearly label assumptions if information is missing
- Do NOT implement code

---

## Final Checklist (Before Saving)

- [ ] Clarifying questions were asked and answered
- [ ] Scope boundaries are explicit
- [ ] User stories are small and verifiable
- [ ] Acceptance criteria are concrete
- [ ] Success criteria are defined
- [ ] Risks and mitigations included
- [ ] File saved to /tasks/prd-feature-name.md
