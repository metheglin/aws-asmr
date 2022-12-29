# Aws::ASMR

## Install

```
gem install aws-asmr
gem which aws/asmr

# Set `PATH` generated from command below
gem which aws/asmr | sed -e "s/lib\/aws\/asmr.rb/bin/" | sed "s/^/PATH=/" | sed "s/$/:\$PATH/"

# Only in current shell
. <(gem which aws/asmr | sed -e "s/lib\/aws\/asmr.rb/bin/" | sed "s/^/PATH=/" | sed "s/$/:\$PATH/")

# Set PATH everytime started zsh session
gem which aws/asmr | sed -e "s/lib\/aws\/asmr.rb/bin/" | sed "s/^/PATH=/" | sed "s/$/:\$PATH/" >> ~/.zshrc
```

```
AWS_PROFILE=custodian asmr awesome-app aws sts get-caller-identity
```