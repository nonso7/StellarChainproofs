#!/usr/bin/env node
import "dotenv/config";
import { program } from "commander";
import chalk from "chalk";
import ora from "ora";
import * as fs from "fs";
import * as path from "path";
import {
  scan,
  generateMarkdownReport,
  generateJSONReport,
  generateTableReport,
  isSlitherAvailable,
} from "@chainproof/core";
import type { ScanConfig } from "@chainproof/core";

// ─── ASCII Banner ─────────────────────────────────────────────────────────────

function printBanner() {
  console.log(
    chalk.cyan(`
  ██████╗██╗  ██╗ █████╗ ██╗███╗   ██╗██████╗ ██████╗  ██████╗  ██████╗ ███████╗
 ██╔════╝██║  ██║██╔══██╗██║████╗  ██║██╔══██╗██╔══██╗██╔═══██╗██╔═══██╗██╔════╝
 ██║     ███████║███████║██║██╔██╗ ██║██████╔╝██████╔╝██║   ██║██║   ██║█████╗
 ██║     ██╔══██║██╔══██║██║██║╚██╗██║██╔═══╝ ██╔══██╗██║   ██║██║   ██║██╔══╝
 ╚██████╗██║  ██║██║  ██║██║██║ ╚████║██║     ██║  ██║╚██████╔╝╚██████╔╝██║
  ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝╚═╝     ╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚═╝
`)
  );
  console.log(
    chalk.gray("  Smart Contract Audit Copilot — vulnerability scanner + gas advisor\n")
  );
}

// ─── scan command ─────────────────────────────────────────────────────────────

program
  .name("chainproof")
  .description("Smart contract security scanner and audit report generator")
  .version("0.1.0");

program
  .command("scan <targets...>")
  .description("Scan one or more .sol files or directories")
  .option("--no-slither", "Skip Slither analysis even if installed")
  .option("--no-llm", "Skip LLM enhancement of findings")
  .option(
    "--api-key <key>",
    "Anthropic API key (or set ANTHROPIC_API_KEY env var)"
  )
  .option(
    "--min-severity <level>",
    "Minimum severity to report: critical|high|medium|low|info",
    "low"
  )
  .option(
    "--format <format>",
    "Output format: table|json|markdown",
    "table"
  )
  .option("--output <file>", "Write report to file instead of stdout")
  .action(
    async (
      targets: string[],
      opts: {
        slither: boolean;
        llm: boolean;
        apiKey?: string;
        minSeverity: string;
        format: string;
        output?: string;
      }
    ) => {
      printBanner();

      const apiKey = opts.apiKey ?? process.env.ANTHROPIC_API_KEY;
      const useLLM = opts.llm && !!apiKey;

      if (opts.llm && !apiKey) {
        console.warn(
          chalk.yellow(
            "  ⚠️  LLM enhancement disabled — no API key found.\n" +
            "     Set ANTHROPIC_API_KEY or pass --api-key <key>\n"
          )
        );
      }

      const slitherAvailable = isSlitherAvailable();
      const useSlither = opts.slither && slitherAvailable;

      if (opts.slither && !slitherAvailable) {
        console.warn(
          chalk.yellow(
            "  ⚠️  Slither not found. Install with: pip install slither-analyzer\n"
          )
        );
      }

      console.log(
        chalk.gray(
          `  Targets  : ${targets.join(", ")}\n` +
          `  Slither  : ${useSlither ? chalk.green("enabled") : chalk.gray("disabled")}\n` +
          `  LLM      : ${useLLM ? chalk.green("enabled") : chalk.gray("disabled")}\n` +
          `  Severity : ${opts.minSeverity}+\n`
        )
      );

      const spinner = ora("Scanning contracts...").start();

      const config: ScanConfig = {
        targets,
        useSlither,
        useLLM,
        apiKey,
        minSeverity: opts.minSeverity as ScanConfig["minSeverity"],
        outputFormat: opts.format as ScanConfig["outputFormat"],
      };

      let result;
      try {
        result = await scan(config);
        spinner.succeed(`Scanned ${result.files.length} file(s)`);
      } catch (err) {
        spinner.fail("Scan failed");
        console.error(chalk.red(`\n  Error: ${err}`));
        process.exit(1);
      }

      // ── Generate report ────────────────────────────────────────────────────
      let report: string;
      switch (opts.format) {
        case "json":
          report = generateJSONReport(result);
          break;
        case "markdown":
          report = generateMarkdownReport(result);
          break;
        default:
          report = generateTableReport(result);
      }

      if (opts.output) {
        fs.writeFileSync(opts.output, report, "utf-8");
        console.log(chalk.green(`\n  ✅ Report written to ${opts.output}`));
      } else {
        console.log(report);
      }

      // ── Markdown also auto-saved when piped to file ───────────────────────
      if (!opts.output && opts.format === "table") {
        const mdPath = path.join(process.cwd(), "chainproof-report.md");
        fs.writeFileSync(mdPath, generateMarkdownReport(result), "utf-8");
        console.log(
          chalk.gray(`\n  💾 Full report saved to ${mdPath}`)
        );
      }

      // ── Exit code: non-zero if critical/high found ─────────────────────────
      const { critical, high } = result.summary;
      if (critical > 0 || high > 0) {
        console.log(
          chalk.red(
            `\n  ❌ ${critical} critical, ${high} high severity issues found.\n` +
            "     Resolve these before deploying to mainnet.\n"
          )
        );
        process.exit(1);
      } else if (result.summary.total > 0) {
        console.log(
          chalk.yellow(`\n  ⚠️  ${result.summary.total} findings. Review before deploying.\n`)
        );
      } else {
        console.log(chalk.green("\n  ✅ No issues detected. Stay safe out there.\n"));
      }
    }
  );

// ─── check command (fast pass/fail for CI) ────────────────────────────────────

program
  .command("check <targets...>")
  .description("Fast pass/fail check — exits 1 if critical/high issues found")
  .option("--no-slither", "Skip Slither")
  .option("--api-key <key>", "Anthropic API key")
  .action(async (targets: string[], opts: { slither: boolean; apiKey?: string }) => {
    const spinner = ora("Running security check...").start();

    const config: ScanConfig = {
      targets,
      useSlither: opts.slither && isSlitherAvailable(),
      useLLM: false,
      minSeverity: "high",
    };

    try {
      const result = await scan(config);
      const { critical, high } = result.summary;

      if (critical > 0 || high > 0) {
        spinner.fail(
          `FAIL — ${critical} critical, ${high} high severity issues found`
        );
        result.files.forEach((f) => {
          f.findings.forEach((finding) => {
            if (finding.severity === "critical" || finding.severity === "high") {
              console.error(
                chalk.red(
                  `  [${finding.severity.toUpperCase()}] ${finding.file}:${finding.line} — ${finding.title}`
                )
              );
            }
          });
        });
        process.exit(1);
      } else {
        spinner.succeed(`PASS — ${result.files.length} file(s) checked, no critical/high issues`);
        process.exit(0);
      }
    } catch (err) {
      spinner.fail(`Check failed: ${err}`);
      process.exit(1);
    }
  });

// ─── init command — generate .chainproofrc config ────────────────────────────

program
  .command("init")
  .description("Create a .chainproofrc.json config file in the current directory")
  .action(() => {
    const config = {
      targets: ["contracts/"],
      useSlither: true,
      useLLM: true,
      minSeverity: "low",
      outputFormat: "markdown",
      output: "audit-report.md",
    };
    const configPath = path.join(process.cwd(), ".chainproofrc.json");
    if (fs.existsSync(configPath)) {
      console.log(chalk.yellow("  ⚠️  .chainproofrc.json already exists"));
      process.exit(0);
    }
    fs.writeFileSync(configPath, JSON.stringify(config, null, 2), "utf-8");
    console.log(chalk.green("  ✅ Created .chainproofrc.json"));
    console.log(chalk.gray("  Edit it to configure your targets and options."));
  });

program.parse();
