# Donate Management Commands

Manage live streaming donation (打赏) interactions through the PolyV CLI.

## Overview

The donate commands allow you to:
- Get channel donate configuration settings
- Update donate settings (cash enabled, gift enabled, tips, amounts)
- List donation records with time range filtering

## Commands

### donate config get

Get the donate configuration for a channel.

```bash
polyv-live-cli donate config get -c <channelId> [options]
```

**Required Options:**
- `-c, --channel-id <id>` - Channel ID

**Optional Options:**
- `-o, --output <format>` - Output format: `table` (default) or `json`

**Examples:**
```bash
# Get donate configuration
polyv-live-cli donate config get -c "3151318"

# Get configuration in JSON format
polyv-live-cli donate config get -c "3151318" -o json
```

**Output (table format):**
```
Donate Configuration for Channel: 3151318

Global Setting Enabled: Y
Cash Donate Enabled: Y
Good Donate Enabled: Y
Point Donate Enabled: N
Donate Tips: Thanks for your support!
Cash Min: 0.01
Cash Amounts: 0.88, 6.66, 8.88, 18.88, 66.6, 88.8
Goods:
  - Flower (0) - Enabled
  - Heart (1.99) - Enabled
```

---

### donate config update

Update the donate configuration for a channel.

```bash
polyv-live-cli donate config update -c <channelId> [options]
```

**Required Options:**
- `-c, --channel-id <id>` - Channel ID

**Optional Options:**
- `--cash-enabled <Y|N>` - Enable/disable cash donations
- `--gift-enabled <Y|N>` - Enable/disable gift donations
- `--tips <text>` - Donate tips text to display
- `--amounts <values>` - Comma-separated donation amounts (e.g., "0.88,6.66,8.88")
- `-o, --output <format>` - Output format: `table` (default) or `json`

**Examples:**
```bash
# Enable cash donations
polyv-live-cli donate config update -c "3151318" --cash-enabled Y

# Update with tips and custom amounts
polyv-live-cli donate config update -c "3151318" \
  --tips "Thank you for your support!" \
  --amounts "0.88,6.66,8.88,18.88"

# Update all settings at once
polyv-live-cli donate config update -c "3151318" \
  --cash-enabled Y \
  --gift-enabled Y \
  --tips "Thanks!" \
  --amounts "1,5,10"
```

---

### donate list

List donation records for a channel within a time range.

```bash
polyv-live-cli donate list -c <channelId> --start <timestamp> --end <timestamp> [options]
```

**Required Options:**
- `-c, --channel-id <id>` - Channel ID
- `--start <timestamp>` - Start time (13-digit millisecond timestamp)
- `--end <timestamp>` - End time (13-digit millisecond timestamp)

**Optional Options:**
- `--page <number>` - Page number (default: 1)
- `--size <number>` - Page size (default: 10)
- `-o, --output <format>` - Output format: `table` (default) or `json`

**Examples:**
```bash
# List donations within a time range
polyv-live-cli donate list -c "3151318" \
  --start 1615772426000 \
  --end 1615858826000

# List with pagination
polyv-live-cli donate list -c "3151318" \
  --start 1615772426000 \
  --end 1615858826000 \
  --page 2 \
  --size 20

# JSON output
polyv-live-cli donate list -c "3151318" \
  --start 1615772426000 \
  --end 1615858826000 \
  -o json
```

**Output (table format):**
```
Found 50 donate records
Page: 1, Size: 10
Total pages: 5
┌─────────────────┬────────────────────┬──────────────┬────────┬────────────────────┬────────────┬─────────────────────────┐
│ User ID         │ Nickname           │ Type         │ Amount │ Name               │ Session ID │ Time                    │
├─────────────────┼────────────────────┼──────────────┼────────┼────────────────────┼────────────┼─────────────────────────┤
│ user123         │ Test User          │ Props/Points │ 6.66   │ Flower             │ session001 │ 3/15/2021, 10:00:26 AM  │
│ user456         │ Another User       │ Cash         │ 8.88   │ Cash               │ session001 │ 3/15/2021, 10:16:66 AM  │
└─────────────────┴────────────────────┴──────────────┴────────┴────────────────────┴────────────┴─────────────────────────┘
```

**Output Columns:**
| Column | Description |
|--------|-------------|
| User ID | Viewer user ID |
| Nickname | Viewer nickname |
| Type | Donation type: Props/Points (type 1) or Cash (type 2) |
| Amount | Donation amount |
| Name | Gift name or "Cash" |
| Session ID | Live session ID |
| Time | Donation timestamp |

---

## API Endpoints

| Command | API Endpoint | Method |
|---------|--------------|--------|
| `donate config get` | `/live/v4/channel/donate/get` | GET |
| `donate config update` | `/live/v4/channel/donate/update` | POST |
| `donate list` | `/live/v4/channel/reward/gift-list` | GET |

## Output Formats

All commands support two output formats:

- **table** (default): Human-readable formatted table
- **json**: Machine-readable JSON format for scripting

## Error Handling

The commands provide user-friendly error messages for common issues:

- Missing required parameters (channelId, start/end timestamps)
- Invalid parameter values (Y/N flags, numeric values)
- Invalid time ranges (start must be before end)
- API authentication errors
- API rate limiting

## Related Commands

- [`lottery`](lottery.md) - Manage lottery activities
- [`checkin`](checkin.md) - Manage check-in activities
- [`qa`](qa-questionnaire.md) - Manage Q&A and questionnaires
