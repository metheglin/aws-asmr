# Aws::ASMR

`ASMR` stands for "Assume Role", obviously!! This is a command line utility for people in the hell of aws assume_role.

## Install

Only gem(ruby package) install is supported now, sorry!

```
gem install aws-asmr
gem which aws/asmr

# Set `PATH` generated from command below
gem which aws/asmr | sed -e "s/lib\/aws\/asmr.rb/bin/" | sed "s/^/PATH=/" | sed "s/$/:\$PATH/"

# Only in current shell
. <(gem which aws/asmr | sed -e "s/lib\/aws\/asmr.rb/bin/" | sed "s/^/PATH=/" | sed "s/$/:\$PATH/")

# Set PATH everytime started zsh session
gem which aws/asmr | sed -e "s/lib\/aws\/asmr.rb/bin/" | sed "s/^/PATH=/" | sed "s/$/:\$PATH/" >> ~/.zshrc

asmr --version
```

## Command Example

In the example below, you can run command `aws sts get-caller-identity` with assumed role `arn:aws:iam::0000:role/AwesomeRole` on specified aws account `custodian`.

If active *MFA* device detected on the IAM account(`custodian`), it'll prompt `MFA token code`. Please check and type the successful code and you'll see the process goes on. Once you went through the MFA, the credentials to assume role are cached on local. At the next command on the same *ARN*, you can skip MFA unless cache is expired.

Regardless that MFA is enabled or not, temporary credentials `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SECRET_TOKEN` are set in the current command when assume_role was successful, without `export` environment variables.  
In the case below, you'll run a command like `AWS_ACCESS_KEY_ID=xxxx AWS_SECRET_ACCESS_KEY=yyyy AWS_SECRET_TOKEN=zzzz aws sts get-caller-identity`  
This means those variables are only effective for the subsequential command(`aws sts get-caller-identity`). So this is safe and you can run commands idempotently (If you export those environment variables, the same command for assume_role would never be successful in the same shell session).

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

[awesome-app-production]
arn = arn:aws:iam::0002:role/AwesomeRole
access_key_id = xxxx
secret_access_key = yyyy

# [commented-awesome-app-test]
# arn = test
```

Then, you can choose one of the alias.

```
asmr aws sts get-caller-identity
  # Choose alias listed on the shell
```

Or you can specify alias name.

```
asmr --name=awesome-app-staging aws sts get-caller-identity
```
