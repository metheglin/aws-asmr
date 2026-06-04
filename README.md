# Aws::ASMR

`ASMR` stands for "Assume Role", obviously!! This is a command line utility for people in the hell of aws assume_role.

## Install

```
gem "aws-asmr"
gem "rexml" # ox, oga, libxml, nokogiri or rexml
```

```
bundle exec asmr
```

## Command Example

In the example below, you can run command `aws sts get-caller-identity` with assumed role `arn:aws:iam::0000:role/AwesomeRole` on specified aws account `custodian`.

If active *MFA* device detected on the IAM account(`custodian`), it'll prompt `MFA token code`. Please check and type the successful code and you'll see the process goes on. Once you went through the MFA, the credentials to assume role are cached on local. At the next command on the same *ARN*, you can skip MFA unless cache is expired.

Regardless that MFA is enabled or not, temporary credentials `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SECRET_TOKEN` are set in the current command when assume_role was successful, without `export` environment variables.  
In the case below, you'll run a command like `AWS_ACCESS_KEY_ID=xxxx AWS_SECRET_ACCESS_KEY=yyyy AWS_SECRET_TOKEN=zzzz aws sts get-caller-identity`  
This means those variables are only effective for the subsequential command(`aws sts get-caller-identity`). So it is safe and you can run commands idempotently (If you export those environment variables, the same command for assume_role would never be successful in the same shell session).

```
AWS_PROFILE=custodian asmr --name=arn:aws:iam::0000:role/AwesomeRole aws sts get-caller-identity
```

Of course you can set `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` respectively to perform assume_role, instead of profile.

```
AWS_ACCESS_KEY_ID=xxxx AWS_SECRET_ACCESS_KEY=yyyy asmr --name=arn:aws:iam::0000:role/AwesomeRole aws sts get-caller-identity
```

To specify ARN (or alias name of assumed role), you MUST set `name` option with a form like `--name=<arn>` NOT a form like `--name <arn>`. For short version, `-n<arn>` works, `-n <arn>` doesn't. You must be wasting time for this pitfall, sorry!  
This is due to a development circumstance. This tool is supposed to run 2 commands. One is assume_role, and the other is subsequential(this is main though) command. To safely separate options for assume_role and subsequential commands, all components of the `asmr` args must be start with `-`. Curse my programming ability!

```
asmr --name=arn:aws:iam::0000:role/AwesomeRole
asmr -narn:aws:iam::0000:role/AwesomeRole
```

Of course you can set options for subsequential command.

```
asmr --name=arn:aws:iam::0000:role/AwesomeRole aws ec2 describe-instances --filter '[{"Name":"instance-state-name","Values":["stopped"]}]'
```

Unfortunatelly you need quote and appropriate escape to run piped command as subsequential.

```
asmr --name=arn:aws:iam::0000:role/AwesomeRole "aws sts get-caller-identity | grep Arn"
```

Without subsequential command, it just prints environment variables for assume_role.

```
AWS_PROFILE=custodian asmr --name=arn:aws:iam::0000:role/AwesomeRole
# AWS_ACCESS_KEY_ID=xxxx
# AWS_SECRET_ACCESS_KEY=yyyy
# AWS_SECRET_TOKEN=zzzz
```

You can define aliases as you like at `~/.aws-asmr/alias` (default).  
Here is the example of alias file. `arn` is the only required attribute.

```
[awesome-app-staging]
arn = arn:aws:iam::0001:role/AwesomeRole
profile = custodian
region = ap-northeast-1

[awesome-app-production]
arn = arn:aws:iam::0002:role/AwesomeRole
access_key_id = xxxx
secret_access_key = yyyy

# [commented-awesome-app-test]
# arn = test
```

`region` is optional and is only used by `asmr-login` (see below) to pick the console landing region.

Then, you can choose one of the alias.

```
asmr aws sts get-caller-identity
  # Choose alias listed on the shell
```

Or you can specify alias name.

```
asmr --name=awesome-app-staging aws sts get-caller-identity
```

## Web Login (AWS Management Console)

The companion command `asmr-login` opens the **AWS Management Console** in your browser as the assumed role, using the [AWS federation endpoint](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_enable-console-custom-url.html). This is handy when you want a *browser* session for a role you normally only use from the CLI.

```
asmr-login --name=awesome-app-staging
```

It assumes the role exactly like `asmr` does — sharing the same alias resolution (`--name`/`-n`), MFA prompt and credential cache — then exchanges the temporary credentials for a sign-in token at `https://signin.aws.amazon.com/federation` and opens the resulting console URL in your default browser. On a headless host where no browser opener is available, the URL is printed instead (it is valid for 15 minutes — treat it as a secret).

### Landing region

The console page you land on is derived from the `region` of the chosen alias. Add `region` to the alias:

```
[my-awesome-project]
arn = arn:aws:iam::xxxx:role/AdminRole
profile = smcdk-prejp
region = ap-northeast-1
```

Then `asmr-login --name=my-awesome-project` opens the console home of `ap-northeast-1`. When the alias has no `region` (or you pass an ARN directly), it falls back to the global console home (`https://console.aws.amazon.com/`).

### Session duration

The console session duration (seconds, 900-43200) is set via the alias's optional `session_duration`. When omitted, it defaults to 43200 (12h).

```
[my-awesome-project]
arn = arn:aws:iam::xxxx:role/AdminRole
profile = smcdk-prejp
region = ap-northeast-1
session_duration = 3600
```

Note: the requested duration must be **less than the assumed role's maximum session duration** (1 hour by default). When the federation endpoint rejects it (e.g. the role's max is shorter, or you reached the role via role chaining), `asmr-login` automatically retries *without* it, falling back to the lifetime of the temporary credentials. To get a full 12-hour console session, raise the role's *Maximum session duration* in IAM accordingly.
