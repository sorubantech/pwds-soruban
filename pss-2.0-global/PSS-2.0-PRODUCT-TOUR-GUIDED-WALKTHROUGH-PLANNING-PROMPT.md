# Enterprise Product Tour / Guided Walkthrough – Product & UX Planning

You are acting as a **Senior Product Manager, Enterprise UX Architect, Product Designer, SaaS Onboarding Specialist, and Full-Stack Software Architect** with **20+ years of experience** designing enterprise SaaS applications and user onboarding experiences.

You have extensive experience designing product tours, guided walkthroughs, contextual help systems, feature discovery, user activation flows, and enterprise application onboarding.

Think like someone who has designed experiences for products such as **Salesforce, HubSpot, Microsoft 365, Slack, Notion, Atlassian, Shopify, Zoho, and other large-scale SaaS applications**.

Your task is to analyze and design a **professional, enterprise-grade Product Tour / Guided Walkthrough system** for our application.

---

# Background

We already have a **Tenant First-Login Setup Wizard**.

That setup wizard is responsible for collecting required tenant configuration such as:

- Company information
- Company logo
- Time zone
- Country
- Currency
- Branding
- Login configuration
- Payment gateway
- Communication configuration
- Other required initial settings

The Product Tour is a **separate experience**.

The Setup Wizard is for **configuration**.

The Product Tour is for **product education and feature discovery**.

Do not mix these two concepts.

---

# What We Mean by Product Tour

Many modern SaaS applications provide a guided demo immediately after onboarding.

The application visually guides the user through important features.

For example:

### Step 1

Highlight a specific feature or navigation item.

The rest of the application becomes visually dimmed/disabled.

A highlighted element remains clearly visible.

A tooltip/popover appears next to the highlighted element explaining:

- What this feature is
- What it does
- Why the user should care
- What they can do with it

The user clicks **Next**.

---

### Step 2

The tour moves to another feature.

For example:

- AI Assistant
- Dashboard
- Tasks
- Reports
- Notifications
- Search
- Quick Actions
- Settings
- Communication
- Any important product capability

The previous highlight disappears and the next target becomes highlighted.

---

# Expected Product Tour Experience

During the tour:

- Background application remains visible.
- A semi-transparent overlay/dimming effect is displayed.
- Only the currently selected feature is highlighted.
- A popover/tooltip explains the feature.
- The user can move through the tour step by step.

Example:

```text
Step 1 of 6
     ↓
Highlight Dashboard
     ↓
Feature explanation
     ↓
Back | Next
```
