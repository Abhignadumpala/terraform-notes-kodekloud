# 📘 Module 9.2: Debugging

> In this note, I explore how to enable and use debugging in Terraform to troubleshoot and resolve issues. When Terraform errors occur, the first step is to review the log output. Terraform's error messages during provisioning are helpful, but sometimes I need to dive deeper for an internal view.

---

## Overview

Terraform lets me increase the debugging output by setting the environment variable `TF_LOG` to one of the available log levels. The supported log levels are: `TRACE`, `DEBUG`, `INFO`, `WARN`, and `ERROR` — with `TRACE` giving the most detailed output. There's also `JSON`, which gives the same detail as `TRACE` but writes each line as JSON so a script can read it.

> 💡 For the most verbose logging, I use `TF_LOG=TRACE`. This is useful when facing complex issues that need insight into Terraform's inner workings.

Official docs: [Debugging Terraform](https://developer.hashicorp.com/terraform/internals/debugging).

---

## Enabling Debugging

To enable the trace log level, I set the `TF_LOG` environment variable like this:

```bash
# export TF_LOG=<log_level>
$ export TF_LOG=TRACE
```

After setting this variable, running any Terraform command produces detailed logs at the selected level. For example, a `terraform plan` run with `TF_LOG` set to `TRACE` can output hundreds or even thousands of lines, capturing every internal step Terraform and its plugins take. A small plan on my machine gave 461 lines.

Below is an example output from running `terraform plan` with `TRACE` logging:

```plaintext
$ terraform plan
2026-09-23T21:41:46.317+0100 [INFO]  Terraform version: 1.16.1
2026-09-23T21:41:46.318+0100 [INFO]  Go runtime version: go1.26.4
2026-09-23T21:41:46.318+0100 [INFO]  CLI args: []string{"terraform", "plan"}
2026-09-23T21:41:46.318+0100 [DEBUG] Attempting to open CLI config file: /home/sri-abhi/.terraformrc
2026-09-23T21:41:46.318+0100 [INFO]  Loading CLI configuration from /home/sri-abhi/.terraformrc
2026-09-23T21:41:46.318+0100 [DEBUG] ignoring non-existing provider search directory terraform.d/plugins
2026-09-23T21:41:46.318+0100 [DEBUG] ignoring non-existing provider search directory /home/sri-abhi/.terraform.d/plugins
2026-09-23T21:41:46.318+0100 [INFO]  CLI command args: []string{"plan"}
----
2026-09-23T21:41:46.388+0100 [INFO]  backend/local: starting Plan operation
2026-09-23T21:41:46.388+0100 [TRACE] statemgr.Filesystem: read snapshot with lineage "da28fb75-4fc6-a34d-5d18-416b170a0b90" serial 7
2026-09-23T21:41:46.389+0100 [INFO]  provider: configuring client automatic mTLS
2026-09-23T21:41:46.404+0100 [DEBUG] provider: starting plugin: path=.terraform/providers/registry.terraform.io/hashicorp/random/3.9.1/linux_amd64/terraform-provider-random_v3.9.1_x5
```

Each line shows the time, the log level in brackets, and the message.

---

## Logs for Terraform Only or the Provider Only

`TF_LOG` turns on logs for everything. I can also turn on logs for just one part, using the same log levels:

- **`TF_LOG_CORE`** — logs from Terraform itself only
- **`TF_LOG_PROVIDER`** — logs from the provider plugins only (like the AWS provider)

```bash
$ export TF_LOG_PROVIDER=TRACE
```

This helps when the problem is clearly on the provider side, like an error coming back from AWS.

---

## Logging to a File

If I want to keep these logs in a file for later review or to include them in bug reports, I set the environment variable `TF_LOG_PATH` to the file path:

```bash
$ export TF_LOG_PATH=/tmp/terraform.log
```

All generated logs are then written to that file instead of the screen.

> ⚠️ `TF_LOG_PATH` only works when `TF_LOG` is also set. I tested it with only `TF_LOG_PATH` set — Terraform created the file but left it empty.

To quickly check the beginning of the log file, I use:

```bash
$ head -10 /tmp/terraform.log
```

An example snippet from the log file:

```plaintext
2026-09-23T21:41:46.489+0100 [INFO]  Terraform version: 1.16.1
2026-09-23T21:41:46.489+0100 [DEBUG] using github.com/hashicorp/go-tfe v1.110.0
2026-09-23T21:41:46.489+0100 [DEBUG] using github.com/hashicorp/hcl/v2 v2.24.0
2026-09-23T21:41:46.489+0100 [DEBUG] using github.com/hashicorp/terraform-svchost v0.2.1
2026-09-23T21:41:46.489+0100 [DEBUG] using github.com/zclconf/go-cty v1.18.1
2026-09-23T21:41:46.489+0100 [INFO]  Go runtime version: go1.26.4
2026-09-23T21:41:46.489+0100 [INFO]  CLI args: []string{"terraform", "plan"}
2026-09-23T21:41:46.489+0100 [TRACE] Stdout is not a terminal
2026-09-23T21:41:46.489+0100 [TRACE] Stderr is not a terminal
2026-09-23T21:41:46.489+0100 [TRACE] Stdin is not a terminal
```

---

## Disabling Debug Logs

To completely disable the debugging output, I unset the environment variables:

```bash
$ unset TF_LOG
$ unset TF_LOG_PATH
```

> ⚠️ I unset these variables when I no longer need detailed logs, since verbose logging can expose sensitive information and slow things down.

---

## Summary Table

| Variable | Action | Description |
|----------|--------|-------------|
| `TF_LOG` | Turn on logs | Sets the log level: `TRACE`, `DEBUG`, `INFO`, `WARN`, `ERROR`, or `JSON` |
| `TF_LOG_CORE` | Terraform-only logs | Logs from Terraform itself, same levels as `TF_LOG` |
| `TF_LOG_PROVIDER` | Provider-only logs | Logs from provider plugins, same levels as `TF_LOG` |
| `TF_LOG_PATH` | Save logs to a file | Writes logs to the given file; needs `TF_LOG` set too |

---

## Summary

- ✅ `TF_LOG` turns on Terraform's detailed logs
- ✅ `TRACE` gives the most detail — I start there for hard problems
- ✅ `TF_LOG_CORE` and `TF_LOG_PROVIDER` narrow the logs to Terraform or the provider
- ✅ `TF_LOG_PATH` saves logs to a file, but only when `TF_LOG` is also set
- ✅ `unset TF_LOG` and `unset TF_LOG_PATH` turn logging off

---

## Key Takeaway

**When an error message isn't enough, I set `TF_LOG=TRACE` and `TF_LOG_PATH` to a file, run the command again, and search the log file.**

- ✅ Logs stay on for the whole shell session until I unset them
- ⚠️ Detailed logs can contain sensitive values — I check them before sharing

---

## Practice & Next Steps

Run `terraform plan` in any lab folder with `TF_LOG=TRACE` and `TF_LOG_PATH=/tmp/terraform.log`, then search the file with `grep '\[ERROR\]\|\[WARN\]' /tmp/terraform.log`. Try the same with `TF_LOG=DEBUG` and compare how many lines each level writes.

Next up: [9.3: Terraform Import](../module-09.3-terraform-import/README.md).
