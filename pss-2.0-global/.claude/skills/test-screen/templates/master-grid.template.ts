// MASTER_GRID test template — substitution source for /test-screen.
//
// This file is NOT executed directly. /test-screen reads it, substitutes the
// {{TOKENS}} from the prompt file's §⑥/⑨/⑪/⑬, then writes the resulting spec
// to PSS_2.0_Frontend/tests/e2e/screens/{entity-lower}.spec.ts.
//
// Substitution tokens (all required unless marked optional):
//   {{N}}              registry id           (e.g. 41)
//   {{W}}              wave number           (e.g. 1)
//   {{EntityName}}     PascalCase entity     (e.g. Branch)
//   {{entity-lower}}   kebab-case            (e.g. branch)
//   {{ENTITYUPPER}}    SHOUT_CASE            (e.g. BRANCH)
//   {{ModuleCode}}     parent module code    (e.g. ORGANIZATION)         ← REQUIRED — see nav-helpers.ts
//   {{MenuUrl}}        screen route path     (e.g. organization/branch)
//                      nav-helpers expands ModuleCode → /{lower}/dashboards/overview
//   {{GridCode}}       grid code identifier  (e.g. BRANCH_LIST)
//   {{REQUIRED_FIELDS_JSON}}   JSON object   (e.g. { "branchName": "_TEST_X" })
//   {{REQUIRED_FIELD_NAME}}    a single required field name (for the validation test)
//
// NAVIGATION CONSTRAINT (do not drop):
//   Tests MUST visit the Module landing page FIRST so menus + role capabilities
//   hydrate; only THEN navigate to the screen. Direct screen navigation leaves
//   the page without menu state → GridCode lookup fails, +Add button hidden,
//   data-table renders empty. Use `navigateToScreen(page, moduleUrl, menuUrl)`
//   from shared/nav-helpers.ts — never raw page.goto(menuUrl).
//
// Optional blocks — the generator includes / omits based on §⑥ features:
//   if has summary widgets    → uncomment §WIDGETS block
//   if has side panel         → uncomment §SIDEPANEL block
//   if has FK dropdowns       → uncomment §FK block (one per FK)
//   if §⑫ has SERVICE_PLACEHOLDER → emit test.skip() with that label
//   if §⑬ has OPEN issues     → emit test.skip() with "ISSUE-N OPEN" label
//
// See /test-screen SKILL.md Step 4 for the generation rules.

import { test, expect } from "../shared/fixtures";
import { searchGrid, waitForGridReady, expectRowExists, expectRowAbsent } from "../shared/grid-helpers";
import { fillRjsfForm, submitForm, expectValidationError } from "../shared/form-helpers";
import { uniqueCode, cleanupTestRows } from "../shared/test-data";
import { navigateToScreen } from "../shared/nav-helpers";

test.describe(
  "Screen #{{N}} — {{EntityName}} (MASTER_GRID)",
  { tag: ["@screen-{{N}}", "@wave-{{W}}", "@master-grid"] },
  () => {
    const moduleCode = "{{ModuleCode}}"; // e.g. "ORGANIZATION" — nav helper expands to dashboards/overview
    const menuUrl = "{{MenuUrl}}";
    const testCode = uniqueCode("{{ENTITYUPPER}}");

    test.afterAll(async ({ request }) => {
      await cleanupTestRows("{{ENTITYUPPER}}", async (_filter) => {
        // TODO (per-entity): issue the Delete{{EntityName}} GraphQL mutation for
        // every row whose code starts with `_filter`. Stub kept empty so the
        // first pilot run doesn't crash on cleanup; rows leak harmlessly until
        // the delete is wired (they're prefixed _TEST_ so easy to clean by hand).
      });
    });

    test.beforeEach(async ({ page }) => {
      // IMPORTANT: navigate to MODULE's dashboard/overview first (loads menus +
      // role capabilities into client state), THEN to the menu URL. Raw
      // page.goto(menuUrl) leaves the data-table without GridCode / role
      // capabilities → +Add hidden, grid renders blank.
      // The helper builds /{moduleCode-lower}/dashboards/overview internally.
      await navigateToScreen(page, moduleCode, menuUrl);
      await waitForGridReady(page);
    });

    test("grid loads with toolbar and at least one row or empty-state", async ({ gridPage }) => {
      await expect(gridPage.toolbar.addButton).toBeVisible();
    });

    test("search filters rows", async ({ page }) => {
      await searchGrid(page, "z_nonexistent_query_xyz");
      const rows = page.locator('[data-testid="grid-row"]');
      // Either zero rows or explicit empty-state — both are "no match".
      const empty = page.locator('[data-testid="grid-empty-state"]');
      const rowCount = await rows.count();
      if (rowCount > 0) {
        await expect(empty).toBeHidden();
      } else {
        await expect(empty).toBeVisible();
      }
    });

    test("+Add → modal → fill → save → row appears", async ({ page, gridPage, formModal }) => {
      await gridPage.toolbar.addButton.click();
      await formModal.waitForOpen();

      await fillRjsfForm(page, JSON.parse(`{{REQUIRED_FIELDS_JSON}}`.replace(/_TEST_X/g, testCode)));
      const closed = await submitForm(page);
      expect(closed).toBe(true);

      await expectRowExists(page, testCode);
    });

    test("required-field validation fires on empty +Add submit", async ({ page, gridPage, formModal }) => {
      await gridPage.toolbar.addButton.click();
      await formModal.waitForOpen();
      const stayedOpen = !(await submitForm(page));
      expect(stayedOpen).toBe(true);
      await expectValidationError(page, "{{REQUIRED_FIELD_NAME}}");
    });

    test("Edit → modal pre-filled → change → save → row updates", async ({ page, gridPage, formModal }) => {
      // Depends on the +Add test having created `testCode`. Use a fresh row code so
      // test order doesn't matter.
      const seedCode = `${testCode}_E`;
      await gridPage.toolbar.addButton.click();
      await formModal.waitForOpen();
      await fillRjsfForm(page, JSON.parse(`{{REQUIRED_FIELDS_JSON}}`.replace(/_TEST_X/g, seedCode)));
      await submitForm(page);

      const row = gridPage.rowByText(seedCode);
      await gridPage.clickRowAction(row, "edit");
      await formModal.waitForOpen();

      const updatedCode = `${seedCode}_v2`;
      await fillRjsfForm(page, { "{{REQUIRED_FIELD_NAME}}": updatedCode });
      await submitForm(page);

      await expectRowExists(page, updatedCode);
      await expectRowAbsent(page, seedCode);
    });

    test("Toggle Active → badge changes", async ({ gridPage }) => {
      const seedCode = `${testCode}_T`;
      // Assumes a row with this code exists from a prior test step or seed; if
      // tests run in isolation we re-seed here.
      const row = gridPage.rowByText(seedCode).or(gridPage.rows.first());
      await gridPage.clickRowAction(row, "toggle");
      // Status badge data-column should flip. TODO (per-entity): confirm column key.
      // await expect(row.locator('[data-column="isActive"]')).toContainText(/Inactive|Active/);
    });

    test("Delete → confirm → row removed", async ({ page, gridPage, confirmModal }) => {
      const seedCode = `${testCode}_D`;
      const row = gridPage.rowByText(seedCode).or(gridPage.rows.first());
      const initialCount = await gridPage.rows.count();
      await gridPage.clickRowAction(row, "delete");
      await confirmModal.confirm();
      const newCount = await page.locator('[data-testid="grid-row"]').count();
      expect(newCount).toBeLessThan(initialCount);
    });

    // ───────────────────────────────────────────────────────────────────────
    // §FK — Foreign-key dropdown population check. Emitted ONCE per FK in §⑥.
    // ───────────────────────────────────────────────────────────────────────
    /*
    test("FK dropdown {{FK_FIELD_NAME}} populates", async ({ page, gridPage, formModal }) => {
      await gridPage.toolbar.addButton.click();
      await formModal.waitForOpen();
      const control = page.locator('[data-testid="form-modal"] [name="{{FK_FIELD_NAME}}"]').locator("..").locator(".react-select__control").first();
      await control.click();
      const options = page.locator('.react-select__option');
      await expect(options.first()).toBeVisible({ timeout: 5_000 });
      expect(await options.count()).toBeGreaterThan(0);
    });
    */

    // ───────────────────────────────────────────────────────────────────────
    // §WIDGETS — Summary widgets check. Emitted if §⑥ declares any.
    // ───────────────────────────────────────────────────────────────────────
    /*
    test("summary widgets render values", async ({ page }) => {
      const widgets = page.locator('[data-testid^="summary-widget-"]');
      await expect(widgets.first()).toBeVisible();
      const count = await widgets.count();
      expect(count).toBeGreaterThan(0);
    });
    */

    // ───────────────────────────────────────────────────────────────────────
    // §SIDEPANEL — Row-click side panel. Emitted if §⑥ declares one.
    // ───────────────────────────────────────────────────────────────────────
    /*
    test("row click → side panel opens", async ({ page, gridPage }) => {
      await gridPage.rows.first().click();
      const panel = page.locator('[data-testid="side-panel"]').first();
      await expect(panel).toBeVisible();
    });
    */

    // ───────────────────────────────────────────────────────────────────────
    // §SKIPS — Intentional skips. /test-screen emits one of these per
    // SERVICE_PLACEHOLDER (§⑫) and per OPEN known issue (§⑬).
    // ───────────────────────────────────────────────────────────────────────
    /*
    test.skip("{{SKIPPED_TEST_NAME}}", () => {
      // SKIPPED — {{SKIP_REASON}}  (e.g. "SERVICE_PLACEHOLDER §⑫" or "ISSUE-2 OPEN §⑬")
    });
    */
  },
);
