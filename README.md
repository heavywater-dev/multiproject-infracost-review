# Multiproject Infracost Review Action

GitHub Action for automatically generating infrastructure cost reports for multiproject CDKTF applications using Infracost.

## V1 - for TypeScript CDKTF projects, future adaptation for other languages is planned

## Description

This Action automatically:

- Generates Terraform plans for all CDKTF projects in your repository
- Calculates infrastructure costs using Infracost
- Compares costs between base branch and PR
- Automatically publishes detailed reports in PR comments

## Quick Start

### Requirements

- Repository with CDKTF projects
- Each project must contain a `cdktf.json` file
- Infracost API key ([get free](https://infracost.io/signup/))

### Basic Example

```yaml
name: Cost Review
on:
  pull_request:
    branches: [main]

jobs:
  cost-review:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v5

      - name: Run Infracost Review
        uses: heavywater-dev/multiproject-infracost-review@v1
        with:
          infracost-api-key: ${{ secrets.INFRACOST_API_KEY }}
          github-token: ${{ secrets.GITHUB_TOKEN }}
          github-repository: ${{ github.repository }}
          pull-request-base: ${{ github.event.pull_request.base.ref }}
          pull-request-number: ${{ github.event.pull_request.number }}
          path: infra
```

## Input Parameters

| Parameter             | Required | Default | Description                                 | Example                                     |
| --------------------- | -------- | ------- | ------------------------------------------- | ------------------------------------------- |
| `infracost-api-key`   | ✅       | -       | Infracost API key                           | `${{ secrets.INFRACOST_API_KEY }}`          |
| `github-token`        | ✅       | -       | GitHub token for comments                   | `${{ secrets.GITHUB_TOKEN }}`               |
| `github-repository`   | ✅       | -       | Repository in owner/repo format             | `${{ github.repository }}`                  |
| `pull-request-base`   | ✅       | -       | Base branch for pull request                | `${{ github.event.pull_request.base.ref }}` |
| `pull-request-number` | ✅       | -       | Pull request number                         | `${{ github.event.pull_request.number }}`   |
| `path`                | ❌       | `infra` | Path to projects directory                  | `infra`                                     |
| `cdktf`               | ❌       | `true`  | Use CDKTF (true) or plain Terraform (false) | `true`, `false`                             |

## Project Structure

Action expects the following structure:

```text
repository/
├── infra/                    # Infrastructure directory (path)
│   ├── project1/
│   │   ├── cdktf.json       # CDKTF configuration
│   │   ├── package.json
│   │   └── src/
│   ├── project2/
│   │   ├── cdktf.json
│   │   ├── package.json
│   │   └── src/
│   └── ...
└── .github/
    └── workflows/
        └── cost-review.yml   # Your workflow
```

## Setup

### 1. Create Infracost API Key

1. Sign up at [infracost.io](https://infracost.io/signup/)
2. Get API key from [dashboard](https://dashboard.infracost.io/)
3. Add key to GitHub Secrets as `INFRACOST_API_KEY`

### 2. Configure Workflow

Create file `.github/workflows/cost-review.yml`:

```yaml
name: Infrastructure Cost Review

on:
  pull_request:
    branches: [main]
    paths: ['infra/**'] # Run only on infrastructure changes

permissions:
  contents: read
  pull-requests: write

jobs:
  cost-review:
    runs-on: ubuntu-latest
    name: Review Infrastructure Costs

    steps:
      - name: Checkout repository
        uses: actions/checkout@v5
        with:
          # Full history needed for base branch comparison
          fetch-depth: 0

      - name: Run multiproject cost review
        uses: heavywater-dev/multiproject-infracost-review@v1
        with:
          infracost-api-key: ${{ secrets.INFRACOST_API_KEY }}
          github-token: ${{ secrets.GITHUB_TOKEN }}
          github-repository: ${{ github.repository }}
          pull-request-base: ${{ github.event.pull_request.base.ref }}
          pull-request-number: ${{ github.event.pull_request.number }}
          path: infra
```

### 3. Configure Permissions

Ensure in repository settings:

- Actions have read access to contents
- Actions can write comments to PRs

## How It Works

1. **Checkout base branch** - retrieves code from PR target branch
2. **Generate baseline plans** - creates Terraform plans for all CDKTF projects
3. **Calculate baseline costs** - uses Infracost to estimate current costs
4. **Checkout PR branch** - switches to branch with changes
5. **Generate PR plans** - creates plans for modified infrastructure
6. **Calculate PR costs** - estimates costs after changes
7. **Compare and report** - generates diff and publishes to PR comment

## Example Output

Action will create a comment in PR similar to:

```markdown
## 💰 Infracost Report

### Overall Summary

Monthly cost will **increase** by **$123.45** 📈

| Project     | Stack      | Previous | New     | Diff    |
| ----------- | ---------- | -------- | ------- | ------- |
| api-service | production | $45.67   | $67.89  | +$22.22 |
| database    | production | $100.78  | $156.34 | +$55.56 |

### Details

- **2 projects** processed
- **3 stacks** analyzed
- **Cost increase**: $123.45/month
```

## License

ISC

## Support

For questions and bug reports use [GitHub Issues](https://github.com/heavywater-dev/multiproject-infracost-review/issues).
