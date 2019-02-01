#!/bin/bash

#judgement
if [[ -a /etc/supervisor/conf.d/supervisord.conf ]]; then
  exit 0
fi

#supervisor
cat > /etc/supervisor/conf.d/supervisord.conf <<EOF
[supervisord]
nodaemon=true

[program:postfix]
command=/usr/lib/postfix/sbin/master -c /etc/postfix/ -d

[program:rsyslog]
command=/usr/sbin/rsyslogd -n

[program:readlog]
command=/usr/bin/tail -F /var/log/mail.log
stdout_logfile=/dev/fd/1
stdout_logfile_maxbytes=0

EOF

MAIL_DOMAIN=$(echo $MAIL_DOMAINS | awk -F ',' '{ print $1 }')

postconf -e myhostname=$MAIL_DOMAIN
postconf -F '*/*/chroot = n'

############
# SASL SUPPORT FOR CLIENTS
# The following options set parameters needed by Postfix to enable
# Cyrus-SASL support for authentication of mail clients.
############
# /etc/postfix/main.cf
postconf -e smtpd_sasl_auth_enable=yes
postconf -e broken_sasl_auth_clients=yes
postconf -e smtpd_recipient_restrictions=permit_sasl_authenticated,reject_unauth_destination
# smtpd.conf
cat >> /etc/postfix/sasl/smtpd.conf <<EOF
pwcheck_method: auxprop
auxprop_plugin: sasldb
mech_list: PLAIN LOGIN CRAM-MD5 DIGEST-MD5 NTLM
EOF
# sasldb2
while IFS=':' read -r _user _domain _pwd; do
  echo $_pwd | saslpasswd2 -p -c -u $_domain $_user
done < "$MAIL_USERS_FILE"
chown postfix.sasl /etc/sasldb2

############
# Enable TLS
############
if [[ -n "$CERTS_CRT_FILE" && -n "$CERTS_KEY_FILE" && -f "$CERTS_CRT_FILE" && -f "$CERTS_KEY_FILE" ]]; then
  # /etc/postfix/main.cf
  postconf -e smtpd_tls_auth_only=yes
  postconf -e smtpd_tls_cert_file=$CERTS_CRT_FILE
  postconf -e smtpd_tls_key_file=$CERTS_KEY_FILE
  postconf -e smtp_tls_security_level=encrypt
  chmod 400 $CERTS_CRT_FILE $CERTS_KEY_FILE
  # /etc/postfix/master.cf
  postconf -M submission/inet="submission   inet   n   -   n   -   -   smtpd"
  postconf -P "submission/inet/syslog_name=postfix/submission"
  postconf -P "submission/inet/smtpd_tls_security_level=encrypt"
  postconf -P "submission/inet/smtpd_sasl_auth_enable=yes"
  postconf -P "submission/inet/milter_macro_daemon_name=ORIGINATING"
  postconf -P "submission/inet/smtpd_recipient_restrictions=permit_sasl_authenticated,reject_unauth_destination"
fi

#############
# Virtual hosts
#############

if [[ -f /etc/postfix/virtual ]]; then
  postconf -e virtual_alias_domains=$MAIL_DOMAINS
  postconf -e virtual_alias_maps=hash:/etc/postfix/virtual
  postmap /etc/postfix/virtual
fi

#############
# Access control
#############

if [[ -f /etc/postfix/access ]]; then
  postconf -e "smtpd_helo_required=yes"
  postconf -e "smtpd_delay_reject=no"
  postconf -e "smtpd_client_restrictions=check_client_access hash:/etc/postfix/access,reject_invalid_hostname,reject_unauth_pipelining,permit_mynetworks,reject_unauth_destination,permit"
  postmap /etc/postfix/access
fi

#############
# Limits
#############

if [[ -n "$CONNECTION_AUTH_LIMIT_RATE" ]]; then
  postconf -e smtpd_client_auth_rate_limit=$CONNECTION_AUTH_LIMIT_RATE
fi

if [[ -n "$ANVIL_RATE_TIME_UNIT" ]]; then
  postconf -e anvil_rate_time_unit=$ANVIL_RATE_TIME_UNIT
fi

#############
#  opendkim
#############

if [[ -z "$(find /etc/opendkim/domainkeys -iname *.private)" ]]; then
  exit 0
fi
cat >> /etc/supervisor/conf.d/supervisord.conf <<EOF

[program:opendkim]
command=/usr/sbin/opendkim -f
EOF
# /etc/postfix/main.cf
postconf -e milter_protocol=2
postconf -e milter_default_action=accept
postconf -e smtpd_milters=inet:localhost:12301
postconf -e non_smtpd_milters=inet:localhost:12301

cat >> /etc/opendkim.conf <<EOF
AutoRestart             Yes
AutoRestartRate         10/1h
UMask                   002
Syslog                  yes
SyslogSuccess           Yes
LogWhy                  Yes

Canonicalization        relaxed/simple

ExternalIgnoreList      refile:/etc/opendkim/TrustedHosts
InternalHosts           refile:/etc/opendkim/TrustedHosts
KeyTable                refile:/etc/opendkim/KeyTable
SigningTable            refile:/etc/opendkim/SigningTable

Mode                    sv
PidFile                 /var/run/opendkim/opendkim.pid
SignatureAlgorithm      rsa-sha256

UserID                  opendkim:opendkim

Socket                  inet:12301@localhost
EOF
cat >> /etc/default/opendkim <<EOF
SOCKET="inet:12301@localhost"
EOF

cat >> /etc/opendkim/TrustedHosts <<EOF
127.0.0.1
localhost
192.168.0.1/24

*.$MAIL_DOMAIN
EOF
cat >> /etc/opendkim/KeyTable <<EOF
mail._domainkey.$MAIL_DOMAIN $MAIL_DOMAIN:mail:$(find /etc/opendkim/domainkeys -iname *.private)
EOF
cat >> /etc/opendkim/SigningTable <<EOF
*@$MAIL_DOMAIN mail._domainkey.$MAIL_DOMAIN
EOF
chown opendkim:opendkim $(find /etc/opendkim/domainkeys -iname *.private)
chmod 400 $(find /etc/opendkim/domainkeys -iname *.private)
