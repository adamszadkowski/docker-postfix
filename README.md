docker-postfix
==============

This is a fork from [catatnight/docker-postfix](https://github.com/catatnight/docker-postfix).

run postfix with smtp authentication (sasldb) in a docker container.
TLS and OpenDKIM support are optional.

## Requirement
+ Docker 1.0

## Usage

Example docker-compose.yml

```yaml
version: '3.7'

services:
  postfix:
    image: klyman/postfix:0.4
    environment:
      - MAIL_DOMAIN=example.com
      - MAIL_USERS_FILE=/run/secrets/mail_users
      - CERTS_CRT_FILE=/run/secrets/mail_crt
      - CERTS_KEY_FILE=/run/secrets/mail_key
      - CONNECTION_AUTH_LIMIT_RATE=3
      - ANVIL_RATE_TIME_UNIT=1d
    configs:
      - source: virtual_addresses
        target: /etc/postfix/virtual
      - source: access_control
        target: /etc/postfix/access
    ports:
      - target: 25
        published: 25
        protocol: tcp
        mode: host
      - target: 587
        published: 587
        protocol: tcp
        mode: host
    secrets:
      - mail_users
      - mail_crt
      - mail_key

configs:
  virtual_addresses:
    file: ./config/virtual
  access_control:
    file: ./config/access

secrets:
  mail_users:
    external: true
  mail_crt:
    external: true
  mail_key:
    external: true
```

## Note
+ Login credential should be set to (`username@mail.example.com`, `password`) in Smtp Client
+ You can assign the port of MTA on the host machine to one other than 25 ([postfix how-to](http://www.postfix.org/MULTI_INSTANCE_README.html))
+ Read the reference below to find out how to generate domain keys and add public key to the domain's DNS records

## Reference
+ [Postfix SASL Howto](http://www.postfix.org/SASL_README.html)
+ [How To Install and Configure DKIM with Postfix on Debian Wheezy](https://www.digitalocean.com/community/articles/how-to-install-and-configure-dkim-with-postfix-on-debian-wheezy)
+ TBD
