# MetaTrader 5 Heartbeat

A MetaTrader 5 Expert Advisor that sends a recurring heartbeat ping to [healthchecks.io](https://healthchecks.io) from directly inside the MT5 terminal. Attach it to any spare chart and it will confirm your terminal is alive every N minutes — no external Python process or scheduled task required.

---

## What it does

- Sends a `/start` + success ping to healthchecks.io on every interval tick
- On any network failure or non-200 HTTP response, immediately sends an explicit `/fail` ping for active alerting
- Tracks consecutive fail streaks and total successful pings in the MT5 journal
- Logs a reminder to whitelist the URL in MT5 settings on the first failure
- Resets the interval timer only on successful pings — a failed ping retries on the next tick rather than silently waiting a full interval
- Prints a stop summary (total pings sent, last fail streak, stop reason) to the journal on deinit

---

## Installation

1. In MetaTrader 5 open the **MQL5 Editor** (F4)
2. Copy `MT5-HB-HC.mq5` into `MQL5\Experts\`
3. Press **F7** to compile — confirm zero errors in the Errors tab
4. Back in MT5, open a **separate spare chart** (any symbol/timeframe — it does not trade)
5. Drag the EA from the Navigator onto that chart
6. In the **Inputs** tab set your `PingURL` (see Setup below)
7. Click OK — the EA starts immediately

> **Attach to a dedicated chart only.** Do not attach it to a chart already running a trading EA.

---

## Required: whitelist the ping URL in MT5

MT5 blocks all outbound HTTP by default. You must whitelist the domain before the EA can reach healthchecks.io:

1. **Tools → Options → Expert Advisors**
2. Check **Allow WebRequest for listed URL**
3. Click **+** and add: `https://hc-ping.com`
4. Click OK

If this step is skipped, every ping will fail with `err: 4014` and the EA will print a reminder in the journal.

---

## Setup

### 1. Get your healthchecks.io ping URL

1. Sign up or log in at [healthchecks.io](https://healthchecks.io)
2. Create a new check — set **Period** to match your `IntervalMinutes` (default: `5 minutes`) and **Grace** to `1–2 minutes`
3. Copy the ping URL — it looks like:
   ```
   https://hc-ping.com/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   ```

### 2. Set the PingURL input

In the EA Inputs dialog, replace `YOUR-UUID-HERE` with your actual UUID:

```
Before: https://hc-ping.com/YOUR-UUID-HERE
After:  https://hc-ping.com/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

The EA validates the URL on startup and will refuse to run (`INIT_PARAMETERS_INCORRECT`) if it does not contain `hc-ping.com`.

---

## Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `PingURL` | `https://hc-ping.com/YOUR-UUID-HERE` | **Required.** Your full healthchecks.io ping URL |
| `IntervalMinutes` | `5` | Ping interval in minutes (minimum: 1) |
| `PingOnStart` | `true` | Send a ping immediately when the EA attaches |

---

## Journal output

```
2026.05.23 21:00:00  Heartbeat started | Interval: 5 min | URL: https://hc-ping.com/xxxx...
2026.05.23 21:00:00  Heartbeat OK | 2026.05.23 21:00 | Total: 1
2026.05.23 21:05:00  Heartbeat OK | 2026.05.23 21:05 | Total: 2
2026.05.23 21:10:00  Heartbeat FAILED | err: 4014 | streak: 1 | 2026.05.23 21:10
2026.05.23 21:10:00   >> Ensure 'https://hc-ping.com/xxxx...' is whitelisted: Tools > Options > Expert Advisors
2026.05.23 21:15:00  Heartbeat OK | 2026.05.23 21:15 | Total: 3
2026.05.23 21:15:00  Heartbeat stopped | Reason: EA removed | Total pings sent: 3 | Last fail streak: 1
```

The EA logs on the first ping and every 100th ping after that during normal operation to avoid flooding the journal.

---

## How healthchecks.io alerting works

healthchecks.io monitors your check in two ways:

- **Missed heartbeat** — if no ping arrives within Period + Grace, the check goes `Late` then `Down` and triggers your configured alert (email, Telegram, PagerDuty, etc.)
- **Explicit `/fail` ping** — if the EA catches a network error or receives a non-200 response, it immediately hits `https://hc-ping.com/<UUID>/fail`, marking the check `Down` right away without waiting for the grace period to expire

The EA also sends a `/start` ping before each success ping. This lets healthchecks.io measure the duration of each ping cycle and alert you if a ping takes longer than expected — useful for detecting a hung or overloaded terminal.

---

## License

Copyright (C) 2026 minn0x  
Licensed under the [GNU General Public License v3.0](LICENSE)
