# Website Audit GitHub Action: SEO, AI search visibility (GEO), security

[![GitHub release](https://img.shields.io/github/v/release/Neocraft-tools/website-audit-action)](https://github.com/Neocraft-tools/website-audit-action/releases)
[![Apify Actor](https://img.shields.io/badge/Apify-website--audit--all--in--one-blue)](https://apify.com/neocraft/website-audit-all-in-one)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

Audit your website after every deploy and **fail the build** when the score is too low, a critical issue appears or the score drops compared with the previous audit. One run checks SEO page by page, AI-search visibility (can ChatGPT, Claude, Perplexity read and cite your site?), security headers and SSL, e-mail DNS (SPF/DMARC), known vulnerabilities of WordPress and other CMS, speed and accessibility, and returns a 0-100 score with prioritized fixes.

This action is a thin, dependency-free wrapper (bash + curl + jq) around the Apify Actor
[neocraft/website-audit-all-in-one](https://apify.com/neocraft/website-audit-all-in-one). It starts a run in **your own Apify account**, waits for it, saves the results as JSON,
writes a readable job summary and exposes the key values as step outputs.

## Quick start

1. Create a free Apify account at <https://apify.com> and copy your API token (**Console → Settings → API & Integrations**).
2. In your GitHub repository: **Settings → Secrets and variables → Actions → New repository secret**, name `APIFY_TOKEN`.
3. Add a step to a workflow:

```yaml
    steps:
      - uses: Neocraft-tools/website-audit-action@v1
        with:
          apify-token: ${{ secrets.APIFY_TOKEN }}
          url: https://www.example.com
          min-score: 70          # fail below 70/100
          fail-on-critical: true # fail on critical issues
          max-score-drop: 5      # fail if the score drops by 5+ points vs the previous audit
```

A complete workflow is in [`examples/audit-after-deploy.yml`](examples/audit-after-deploy.yml).

## Pricing (pay per event, billed by Apify to your account)

**$0.49 per audited site** (first 10 pages included) + **$0.01 per extra page**. Sites that cannot be reached are not charged. With the defaults (1 URL, 10 pages) one run costs $0.49; `max-total-charge-usd: auto` caps it at $0.54.

Prices are those of the [Apify Store page](https://apify.com/neocraft/website-audit-all-in-one) when this README was written; the Store page is the reference.
Platform usage is included in these prices. Apify's free plan includes a monthly credit that covers light use.
Every run is started with a hard spend cap (`max-total-charge-usd`): the Actor stops charging when the cap is reached.
This GitHub Action itself is free and open source; nothing is billed by Neocraft outside Apify.

## Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `apify-token` | yes |  | Your Apify API token (store it as a secret). Runs are billed to this Apify account. |
| `url` | yes |  | URL to audit. Several URLs: separate with commas or new lines (each one is a separate site audit). |
| `max-pages` | no | `10` | Pages crawled per site. 10 are included in the per-site price; each extra page costs $0.01. |
| `min-score` | no | `0` | Fail when the overall score (0-100) of any site is below this value. 0 disables the gate. |
| `fail-on-critical` | no | `true` | Fail when the audit reports at least one critical issue (e.g. actively exploited CMS vulnerability, expired SSL). |
| `max-score-drop` | no | `5` | Fail when the score dropped by at least this many points since the previous audit with the same monitor-id. 0 disables the gate. |
| `monitor-id` | no |  | History key used to compare with the previous audit (stored in your Apify account). Defaults to the repository name. |
| `language` | no | `en` | Report language: en or fr. |
| `pagespeed` | no | `false` | Also query Google PageSpeed Insights (slower). |
| `extra-input` | no |  | Optional JSON object merged into the Actor input (any field of neocraft/website-audit-all-in-one). |
| `max-total-charge-usd` | no | `auto` | Hard spend cap for the run in USD. 'auto' = $0.49 per site + $0.01 per page above 10 + $0.05 margin. |
| `timeout-secs` | no | `1200` | Maximum run time of the Actor in seconds. |
| `output-file` | no | `website-audit.json` | Where to save the full JSON results. |

## Outputs

| Name | Description |
|---|---|
| `passed` | true when all gates passed. |
| `score` | Lowest overall score (0-100) among the audited sites. |
| `critical` | Number of critical issues (all sites). |
| `score-delta` | Lowest score change since the previous audit (0 on the first audit). |
| `summary` | Compact JSON summary per site. |
| `results-file` | Path of the full JSON results. |
| `run-url` | Apify Console URL of the run. |

Every run also sets `run-id`, `run-status` and `item-count`.

## Notes

* The comparison with the previous audit uses a small history stored in **your** Apify account (named key-value store `site-audit-history`), keyed by URL + `monitor-id` (default: the repository name). The first run has no delta.
* The full JSON (findings with step-by-step fixes, per-category scores, report links) is saved to `website-audit.json`.
* A site audit usually takes 1 to 5 minutes; the action starts the run and polls it, so there is no 5-minute HTTP limit.
* The step needs `curl` and `jq`, which are preinstalled on GitHub-hosted Ubuntu and macOS runners.
* Your token is only sent to `api.apify.com`. Keep it in a secret; never paste it in a workflow file.

## Related

* Apify Actor: [website-audit-all-in-one](https://apify.com/neocraft/website-audit-all-in-one) (also usable from the Apify Console, API, Python/Node clients, Make, Zapier, MCP/AI agents).
* More examples (Python, Node.js, curl, AI agents): [Neocraft-tools/apify-examples](https://github.com/Neocraft-tools/apify-examples).
* Other Neocraft actions: [page-change-monitor-action](https://github.com/Neocraft-tools/page-change-monitor-action), [website-screenshot-action](https://github.com/Neocraft-tools/website-screenshot-action), [company-profile-action](https://github.com/Neocraft-tools/company-profile-action), [hiring-tracker-action](https://github.com/Neocraft-tools/hiring-tracker-action).

## Self-test (maintainers)

[`examples/self-test.yml`](examples/self-test.yml) runs this action on cheap inputs (a few cents at most). To enable it,
copy it to `.github/workflows/self-test.yml`, add an `APIFY_TOKEN` secret, and start it from the **Actions** tab
(it only runs on `workflow_dispatch`).

## Support

Open an issue in this repository. Maintained by Xiaoli, an AI assistant, for Neocraft.

## License

[MIT](LICENSE)
