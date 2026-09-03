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

To specify ARN (or alias name of assumed role), set the `name` option in any of the usual forms. Option parsing stops at the first argument that is not an option (or at a literal `--`), and everything from there on is the subsequential command, including its own options such as `--filter`.

```
asmr --name=arn:aws:iam::0000:role/AwesomeRole
asmr --name arn:aws:iam::0000:role/AwesomeRole
asmr -narn:aws:iam::0000:role/AwesomeRole
asmr -n arn:aws:iam::0000:role/AwesomeRole
asmr -n arn:aws:iam::0000:role/AwesomeRole -- aws sts get-caller-identity
```

Of course you can set options for subsequential command.

```
asmr --name=arn:aws:iam::0000:role/AwesomeRole aws ec2 describe-instances --filter '[{"Name":"instance-state-name","Values":["stopped"]}]'
```

When the subsequential command is given as several arguments, it is executed directly (no shell in between): each argument reaches the command exactly as your shell handed it to `asmr`, so quotes, spaces and `$` in arguments need no extra escaping. Note that your shell still interprets `|`, `&&` and redirects *before* `asmr` runs, so in `asmr aws s3 ls | grep foo` only `aws s3 ls` gets the credentials (which is usually what you want).

To run a whole pipeline as the assumed role, pass it as a single argument; a single argument is run through `sh`, so pipes, redirects and variable expansion work inside it.

```
asmr --name=arn:aws:iam::0000:role/AwesomeRole "aws sts get-caller-identity | grep Arn"
asmr --name=arn:aws:iam::0000:role/AwesomeRole 'echo $AWS_ACCESS_KEY_ID'
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

## Pin a role to a directory (`asmr local`)

Following the `rbenv local` convention, you can pin an alias (or a role ARN) to a directory. `asmr local NAME` writes the name to `.asmr` in the current directory; from then on, `asmr` and `asmr-login` run there **without `--name`** assume that role instead of asking you to choose one. The nearest `.asmr` in the current directory or any of its parents wins, so pinning a project root covers its subdirectories.

```
cd ~/src/awesome-app
asmr local awesome-app-staging   # writes ./.asmr
asmr aws sts get-caller-identity # assumes awesome-app-staging, no prompt
asmr-login                       # opens the console as awesome-app-staging
```

`asmr local` refuses a name that is neither an alias defined in `~/.aws-asmr/alias` nor a role ARN, the same way rbenv refuses a version that is not installed. A pin whose alias was deleted later fails with a message pointing at the `.asmr` file.

```
asmr local            # prints the name pinned in the current directory
asmr local --unset    # removes ./.asmr
```

`--name` always takes precedence over the pin. Note that pinning is by directory, not by shell: entering a pinned directory silently switches the role, so be careful with production aliases (checking `asmr local` before a destructive command is cheap). Like `.ruby-version`, `.asmr` is yours to commit or ignore.

## Session duration

The lifetime of the temporary credentials (seconds, 900-43200) is set via the alias's optional `session_duration`. It is passed as `DurationSeconds` to `assume_role`, so a longer value means fewer MFA prompts: the cached credentials stay valid until they expire.

```
[my-awesome-project]
arn = arn:aws:iam::xxxx:role/AdminRole
profile = smcdk-prejp
session_duration = 43200
```

When omitted, the role's default (1 hour) applies. The value must not exceed the role's *Maximum session duration* in IAM, and it cannot exceed 1 hour when the credentials used to assume the role are themselves temporary (role chaining). When STS rejects it, `asmr` retries without `session_duration` and tells you so, **except** when an MFA code was just consumed: a TOTP code cannot be reused, so `asmr` fails with guidance instead of asking you for another code. A change to `session_duration` only takes effect after the currently cached credentials expire (or after `asmr --clear`).

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

The console session duration is the alias's `session_duration` described above; it is sent as `SessionDuration` to the federation endpoint as well. When omitted, `asmr-login` requests 43200 (12h).

Note: the requested duration must be **less than the assumed role's maximum session duration** (1 hour by default). When the federation endpoint rejects it (e.g. the role's max is shorter, or you reached the role via role chaining), `asmr-login` automatically retries *without* it, falling back to the lifetime of the temporary credentials. To get a full 12-hour console session, raise the role's *Maximum session duration* in IAM and set `session_duration = 43200`.
