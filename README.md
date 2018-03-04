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
version: '3.1'

services:
  postfix:
    image: klyman/postfix:0.1
    environment:
      - MAIL_DOMAIN=example.com
      - MAIL_USERS_FILE=/run/secrets/mail_users
      - CERTS_CRT_FILE=/run/secrets/mail_crt
      - CERTS_KEY_FILE=/run/secrets/mail_key
    volumes:
      - ./config/virtual:/etc/postfix/virtual
    ports:
      - "25:25"
      - "587:587"
    secrets:
      - mail_users
      - mail_crt
      - mail_key

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
