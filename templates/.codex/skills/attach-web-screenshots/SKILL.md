---
name: attach-web-screenshots
description: "Use after implementing a web UI feature to capture browser screenshots at all Tailwind breakpoints and attach them to the open PR."
---

# Attach Screenshots

Take screenshots of the running app and attach them to the current branch's open PR.

Screenshots are stored under `docs/screenshots/<branch-name>/` so each branch has its own folder. A scheduled GitHub Actions workflow automatically cleans up folders for merged branches.

## Steps

1. **Identify the PR** — find the open PR for the current branch:

   ```bash
   gh pr view --json number,url,headRefName
   ```

   Record `headRefName` as `<branch>` (e.g. `feat/lexify-t8w`).

2. **Identify what to screenshot** — from the bead description, plan, or user input, determine which URLs to visit and what to call each one (e.g. "Full-page mode", "Modal mode", "Mobile view").

3. **Ensure the preview server is running** — the app must be live at a known port. Check if it is already running; if not, look at `package.json` scripts or the project README to find the right preview command and start it in the background. Common patterns: `npm run preview`, `vite preview`, a mock-mode flag like `VITE_USE_MOCKS=true`. Wait a couple of seconds after starting before navigating.

4. **Inject auth (if the route is protected)** — use `initScript` in `navigate_page` to monkey-patch `window.fetch` before MSW or any other interceptor. Check the project's auth API (e.g. a `/auth/me` or `/api/session` endpoint) and the app's User type to know what shape to return. The pattern:

   ```js
   const orig = window.fetch;
   window.fetch = async function (input, init) {
     const url =
       typeof input === "string"
         ? input
         : input instanceof URL
           ? input.href
           : (input && input.url) || "";
     if (url.includes("<auth-endpoint>")) {
       return new Response(
         JSON.stringify({ /* fields matching the app's User shape */ }),
         { status: 200, headers: { "Content-Type": "application/json" } },
       );
     }
     return orig.apply(this, arguments);
   };
   ```

5. **Take screenshots at all breakpoints** — for each URL, capture at every Tailwind CSS default breakpoint:

   | Label | Tailwind prefix | Width (px) | Height (px) |
   | ----- | --------------- | ---------- | ----------- |
   | base  | (none)          | 390        | 844         |
   | sm    | `sm:`           | 640        | 900         |
   | md    | `md:`           | 768        | 1024        |
   | lg    | `lg:`           | 1024       | 768         |
   | xl    | `xl:`           | 1280       | 800         |
   | 2xl   | `2xl:`          | 1536       | 864         |

   For each breakpoint:
   - Open in an isolated Chrome DevTools context with `new_page`
   - Resize the viewport with `resize_page` to the breakpoint dimensions
   - Navigate using `navigate_page` with the `initScript` above if auth is needed
   - Wait for the key content with `wait_for`
   - Save with `take_screenshot` to `/tmp/<slug>-<label>.png` (e.g. `home-lg.png`)
   - Use `fullPage: true` for full-page views; omit it (viewport only) for modal/overlay views

6. **Commit to the branch** — store under `docs/screenshots/<branch>/`. Sanitize the branch name (replace `/` with `-`) so it stays a single flat folder:

   ```bash
   BRANCH=$(git rev-parse --abbrev-ref HEAD | tr '/' '-')
   mkdir -p "docs/screenshots/$BRANCH"
   cp /tmp/<slug>-base.png /tmp/<slug>-sm.png /tmp/<slug>-md.png /tmp/<slug>-lg.png /tmp/<slug>-xl.png /tmp/<slug>-2xl.png "docs/screenshots/$BRANCH/"
   git add docs/screenshots/
   git commit -m "docs: add screenshots for PR"
   git push
   ```

7. **Post the PR comment** — use the template below. Group by feature/URL, with breakpoints as a sub-row. Keep it brief.

## Comment template

```
## Screenshots

### <Label> (`<path>`)

| base (390px) | sm (640px) | md (768px) | lg (1024px) | xl (1280px) | 2xl (1536px) |
|---|---|---|---|---|---|
| [base](<blob-url>/<slug>-base.png) | [sm](<blob-url>/<slug>-sm.png) | [md](<blob-url>/<slug>-md.png) | [lg](<blob-url>/<slug>-lg.png) | [xl](<blob-url>/<slug>-xl.png) | [2xl](<blob-url>/<slug>-2xl.png) |

### <Label> (`<path>`)

| base (390px) | sm (640px) | md (768px) | lg (1024px) | xl (1280px) | 2xl (1536px) |
|---|---|---|---|---|---|
| [base](<blob-url>/<slug>-base.png) | [sm](<blob-url>/<slug>-sm.png) | [md](<blob-url>/<slug>-md.png) | [lg](<blob-url>/<slug>-lg.png) | [xl](<blob-url>/<slug>-xl.png) | [2xl](<blob-url>/<slug>-2xl.png) |
```

Where `<blob-url>` = `https://github.com/<owner>/<repo>/blob/<branch>/docs/screenshots/<branch-sanitized>`.

Post with:

```bash
gh pr comment <number> --body "..."
```

8. **Close all browser pages** — after posting the PR comment, close every page opened during this session. This is the final step — always run it before reporting the task as done:

   ```
   close_page(<pageId>)  # repeat for each page opened via new_page
   ```

   The last remaining page cannot be closed — leave it. Track page IDs from `new_page` responses throughout the session.

## Notes

- For **public repos** you can use `raw.githubusercontent.com` URLs and the images will render inline. For **private repos** they won't — use the `blob/` URL format above so reviewers can click through to view them on GitHub.
- If the page redirects to login, the `initScript` fetch mock handles auth. Match the mock response to the app's auth endpoint and `User` shape (check the project's types or API handler).
- Use a fresh `isolatedContext` name per invocation to avoid state leaking from prior browser sessions.
- One screenshot per distinct UI state is enough. Don't over-capture.
- Stale folders (merged branches) are cleaned up automatically by `.github/workflows/cleanup-screenshots.yml`.
