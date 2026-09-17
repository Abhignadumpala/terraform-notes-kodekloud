# 📘 Module 6.3: Programmatic Access — Using the AWS CLI

> [6.1](../module-06.1-introduction-to-iam/README.md) and [6.2](../module-06.2-demo-iam/README.md) covered console access and programmatic access as IAM concepts. This lesson is programmatic access in practice — talking to AWS from a terminal instead of a browser.

---

## Introduction

Back in [6.1](../module-06.1-introduction-to-iam/README.md#two-kinds-of-access) I noted that an IAM user can get two kinds of access: console (username + password) and programmatic (access key ID + secret access key). Everything in [6.2](../module-06.2-demo-iam/README.md) used the console. This lesson uses the other kind — the **AWS CLI**, driven from an access key instead of a browser login.

This matters for more than convenience: Terraform's AWS provider authenticates the exact same way a manually-run CLI command does. Getting the CLI configured and working is really a rehearsal for getting Terraform's credentials working.

---

## Installing the AWS CLI

The AWS CLI is a single tool that talks to any AWS service from a terminal — Linux, macOS, or Windows PowerShell. It's currently on major version 2.

On Linux:

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

Then confirm it installed and check the version:

```bash
aws --version
```

```
aws-cli/2.36.19 Python/3.14.6 Linux/7.0.0-31-generic exe/x86_64.ubuntu.26
```

macOS and Windows both ship a graphical installer from the same download page, if I'd rather not use the terminal for this step.

Worth making sure the install location ends up on my system `PATH` — that's what lets me type `aws` from any directory instead of the full install path.

---

## Configuring the AWS CLI

Once installed, the CLI needs credentials before it can do anything. `aws configure` walks through the four things it needs:

```bash
aws configure
```

```
AWS Access Key ID [None]: AKIAI44QH8DHBEXAMPLE
AWS Secret Access Key [None]: je7MtGbClwBF/2Zp9Utk/h3yCo8nvbEXAMPLEKEY
Default region name [None]: us-west-2
Default output format [None]: json
```

- **Access key ID + secret access key** — the programmatic credential pair from [6.1](../module-06.1-introduction-to-iam/README.md), generated for an IAM user.
- **Default region** — which AWS region commands run against when I don't specify one explicitly.
- **Default output format** — `json`, `yaml`, `text`, or `table`.

This writes two files into a hidden `.aws` folder in my home directory:

```bash
cat ~/.aws/config
```

```
[default]
region = us-west-2
output = json
```

```bash
cat ~/.aws/credentials
```

```
[default]
aws_access_key_id = AKIAI44QH8DHBEXAMPLE
aws_secret_access_key = je7MtGbClwBF/2Zp9Utk/h3yCo8nvbEXAMPLEKEY
```

Anyone with read access to `~/.aws/credentials` effectively has that IAM user's permissions — same risk as a leaked password, so it stays out of version control and off of anything shared.

---

## Using the AWS CLI

Every AWS CLI command follows the same shape:

```
aws  <service>  <sub-command>  [options/parameters]
```

To create an IAM user named `lucy` from the terminal instead of the console:

```bash
aws iam create-user --user-name lucy
```

```json
{
    "User": {
        "UserName": "lucy",
        "Tags": [],
        "CreateDate": "2026-09-17T10:15:00Z",
        "UserId": "h9r2sc5br8ss7uzhs2qm",
        "Path": "/",
        "Arn": "arn:aws:iam::000000000000:user/lucy"
    }
}
```

`iam` is the service, `create-user` is the sub-command, `--user-name lucy` is the parameter. The response confirms what got created and hands back the user's ARN — the same identifier I'd see on her user page in the console. Every other AWS resource follows this same `aws <service> <sub-command>` pattern; only the service name and parameters change.

---

## Accessing Help

The CLI documents itself — I don't need to leave the terminal to look up a command:

```bash
aws help              # everything the CLI can do
aws iam help          # everything under the IAM service
aws iam create-user help   # exactly what create-user takes
```

Appending `help` to any command, at any level, prints the usage and every available parameter for that level.

---

## Summary

- ✅ Programmatic access means an access key ID + secret access key, used by the CLI (or by Terraform's AWS provider) instead of a console login
- ✅ Install the CLI once per machine; `aws --version` confirms it's on the `PATH` and working
- ✅ `aws configure` writes the access key pair, default region, and output format into `~/.aws/credentials` and `~/.aws/config`
- ✅ Every command follows `aws <service> <sub-command> [options]` — same shape regardless of which AWS service I'm calling
- ✅ `aws help`, `aws <service> help`, and `aws <service> <sub-command> help` cover documentation for every level of a command

---

## Key Takeaway

**The AWS CLI is programmatic access made usable — the same access key from an IAM user, now driving commands from a terminal instead of clicks in a console.**

- ✅ One install, then `aws configure` once per set of credentials
- ✅ `~/.aws/credentials` holds the actual secret — treat it like a password, never commit it
- ⚠️ This is the same authentication path Terraform's AWS provider uses — a working `aws configure` here means Terraform has what it needs too, without any extra credential setup

---

## Practice & Next Steps

Run `aws configure` with a real IAM user's access key, then `aws iam create-user --user-name <name>` and confirm the new user shows up in the console. Try `aws iam create-user help` to see what other parameters exist beyond `--user-name`.

Next up in Module 6: wiring IAM users, groups, policies, and roles into Terraform itself — `aws_iam_user`, `aws_iam_group`, `aws_iam_policy`, and `aws_iam_role` as resource blocks, using the exact credentials configured here.
