# magento2-sample-REST-setup-bash

Bash script to setup Magento 2 + sample data + enabled REST API setup

Exec this script to setup Magento with a REST API enabled.

_Note: When the scripts asks for password, it would be for mysql's root user_

_Note: not for production, just for testing ;-)_

## Simple usage

```
$ sudo su
$ cd ~ && wget https://raw.githubusercontent.com/bobvanluijt/magento2-sample-REST-setup-bash/master/install.sh && chmod +x install.sh && ./install.sh
```

Notes:
- Tested on Ubuntu 16.04 LTS
- It assumes that the domainname DNS is set (because of letsencrypt)
