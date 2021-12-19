$ORIGIN example.com.
$TTL 86400
@	SOA	dns1.example.com.	hostmaster.example.com. (
		2001062501 ; serial
		21600      ; refresh after 6 hours
		3600       ; retry after 1 hour
		604800     ; expire after 1 week
		86400 )    ; minimum TTL of 1 day
;
;
	NS	dns1.example.com.
	NS	dns2.example.com.
dns1	A	10.0.1.1
	AAAA	aaaa:bbbb::1
dns2	A	10.0.1.2
	A	10.0.1.3
	AAAA	aaaa:bbbb::2
;
;
@	MX	10	mail.example.com.
	MX	20	mail2.example.com.
mail	IN	A	10.0.1.5
	IN	AAAA	aaaa:bbbb::5
mail2	IN	A	10.0.1.6
	AAAA	aaaa:bbbb::6
;
;
; This sample zone file illustrates sharing the same IP addresses for multiple services:
;
services  IN	A	10.0.1.10
	  IN	AAAA	aaaa:bbbb::10
		A	10.0.1.11
		AAAA	aaaa:bbbb::11

ftp	IN  CNAME	services.example.com.
www	CNAME	services.example.com.
$ORIGIN level3.example.com.
dns4	A	10.0.4.4
	AAAA	aaaa:bbbb::1
dns5	A	10.0.5.5
	AAAA	aaaa:bbbb::2
@	A	10.0.9.9

;