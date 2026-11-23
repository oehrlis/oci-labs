# Runbook - ACE credit report

The ACE tenancy runs on yearly Oracle ACE credits, not on a paid contract. `tools/oci_cost_report.sh` shows once a
month how much of the credit year is used, what is left, where the credits go and which compute and database
resources exist. It only reads (Usage API, Search, IAM, Organizations) and changes nothing in OCI.

## Run

```bash
make cost-report                       # report on stdout
make cost-report-notes                 # write ~/notes/costs/YYYY-MM.md
make cost-report-notes COST_ARGS=--yes # overwrite this month's report
tools/oci_cost_report.sh --notes --dry-run
```

Defaults: profile `ACE`, 5000 credits, credit year from 09-09. Change them per call with `--profile`, `--credits` and
`--year-start`, or with the environment variables `OCI_COST_PROFILE`, `ACE_CREDITS` and `ACE_YEAR_START`.
`NOTES_DIR` moves the target directory of `--notes`.

The report goes to stdout or to `~/notes`, never into this repository: it carries tenancy names, compartments and
resource names. `--out FILE` writes elsewhere; an existing file is only replaced with `--yes`.

## Content

| Section | Source | Meaning |
| --- | --- | --- |
| Credit year | Usage API, daily cost | Used, left, average of the last 30 days, forecast to the end of the credit year |
| Promotion | Organizations API | Promotions of the subscription as the API reports them |
| Cost per month | Usage API | Monthly sums within the credit year |
| Top resources | Usage API + Search | Cost per resource, dominant SKU, current state; `weg` = resource no longer exists |
| Compute and databases | Search | Instances, Autonomous Databases, DB systems and similar with state and cost of the last 30 days |

The forecast uses the average of the last 30 days, not of the whole year, so a lab started last week shows up at once.
A warning line appears when the forecast exceeds the credits, with the day they run out.

## Limits

- Cost is list price in the tenancy currency. The Usage API lags by a few hours; the last day can be incomplete.
- The API does not report the ACE credit amount or the remaining balance. The ACE subscription shows a single
  promotion whose amount does not match the yearly ACE credits, while its expiry follows the ACE year. The report
  shows both and computes with `--credits`; the balance Oracle holds is in the console under Billing & Cost
  Management > Subscriptions.
- Daily data comes in windows of 90 days, because the Usage API accepts at most 93 days per daily request.
- Stopped resources that still cost money are listed by name - Autonomous Databases "for Developers", for example,
  keep billing while stopped.
