#!/usr/bin/env perl

use strict;
use warnings;

print <DATA>;

__DATA__
<?xml version="1.0" encoding="UTF-8"?>
<document title="SSLScan Results" version="1.9.0-win" web="http://www.titania.co.uk">
 <ssltest host="www.nic.se" port="443" time="2012-06-12 08:16:45 +0000">
  <cipher status="accepted" sslversion="SSLv3" bits="256" cipher="DHE-RSA-AES256-SHA" kx="DH" au="RSA" enc="AES(256)" mac="SHA1" />
  <cipher status="accepted" sslversion="SSLv3" bits="256" cipher="AES256-SHA" kx="RSA" au="RSA" enc="AES(256)" mac="SHA1" />
  <cipher status="accepted" sslversion="SSLv3" bits="128" cipher="DHE-RSA-AES128-SHA" kx="DH" au="RSA" enc="AES(128)" mac="SHA1" />
  <cipher status="accepted" sslversion="SSLv3" bits="128" cipher="AES128-SHA" kx="RSA" au="RSA" enc="AES(128)" mac="SHA1" />
  <cipher status="accepted" sslversion="SSLv3" bits="168" cipher="EDH-RSA-DES-CBC3-SHA" kx="DH" au="RSA" enc="3DES(168)" mac="SHA1" />
  <cipher status="accepted" sslversion="SSLv3" bits="168" cipher="DES-CBC3-SHA" kx="RSA" au="RSA" enc="3DES(168)" mac="SHA1" />
  <cipher status="accepted" sslversion="TLSv1" bits="256" cipher="DHE-RSA-AES256-SHA" kx="DH" au="RSA" enc="AES(256)" mac="SHA1" />
  <cipher status="accepted" sslversion="TLSv1" bits="256" cipher="AES256-SHA" kx="RSA" au="RSA" enc="AES(256)" mac="SHA1" />
  <cipher status="accepted" sslversion="TLSv1" bits="128" cipher="DHE-RSA-AES128-SHA" kx="DH" au="RSA" enc="AES(128)" mac="SHA1" />
  <cipher status="accepted" sslversion="TLSv1" bits="128" cipher="AES128-SHA" kx="RSA" au="RSA" enc="AES(128)" mac="SHA1" />
  <cipher status="accepted" sslversion="TLSv1" bits="168" cipher="EDH-RSA-DES-CBC3-SHA" kx="DH" au="RSA" enc="3DES(168)" mac="SHA1" />
  <cipher status="accepted" sslversion="TLSv1" bits="168" cipher="DES-CBC3-SHA" kx="RSA" au="RSA" enc="3DES(168)" mac="SHA1" />
  <defaultcipher sslversion="TLSv1" bits="168" cipher="DES-CBC3-SHA" kx="RSA" au="RSA" enc="3DES(168)" mac="SHA1" />
  <defaultcipher sslversion="SSLv3" bits="256" cipher="DHE-RSA-AES256-SHA" kx="RSA" au="RSA" enc="3DES(168)" mac="MD5" />
  <defaultcipher sslversion="TLSv1" bits="256" cipher="DHE-RSA-AES256-SHA" kx="RSA" au="RSA" enc="3DES(168)" mac="MD5" />
  <certificate>
   <version>2</version>
   <serial>4294967295</serial>
   <signature-algorithm>sha1WithRSAEncryption</signature-algorithm>
   <issuer>/C=US/O=Thawte, Inc./CN=Thawte SSL CA</issuer>
   <not-valid-before>Aug 30 00:00:00 2011 GMT</not-valid-before>
   <not-valid-after>Aug 29 23:59:59 2012 GMT</not-valid-after>
   <subject>/C=SE/ST=Stockholm/L=Stockholm/O=Internet Infrastructure Foundation/CN=iis.se</subject>
   <pk-algorithm>rsaEncryption</pk-algorithm>
   <pk error="false" type="RSA" bits="2048">
    Modulus (2048 bit):
        00:c5:a8:92:e5:e2:05:76:e9:fd:e5:89:51:f6:b4:
        56:d4:1d:c7:4a:f8:3a:93:c3:ad:52:24:b6:46:c7:
        77:fe:2d:68:10:d1:0d:2e:62:a5:87:3f:81:3b:10:
        a2:45:9b:de:7c:c3:d7:a5:20:d2:84:3b:47:c4:75:
        9b:2f:7e:e1:31:4b:00:88:d0:a0:ba:83:24:90:7f:
        1a:10:4b:5f:a3:eb:6e:30:88:19:40:e3:46:e5:90:
        3a:0f:eb:6f:55:6d:96:5c:cf:1c:c3:08:63:1f:b6:
        82:68:6e:f5:41:ad:80:82:92:e6:63:59:1c:c7:12:
        6e:c9:28:f6:1d:fe:4b:7a:60:b4:d4:db:81:05:06:
        fe:10:0f:76:68:cb:6a:14:57:a8:a7:66:e1:fd:59:
        78:f4:71:98:c2:4c:97:40:ef:2c:b9:a3:19:dd:86:
        90:1d:36:26:c1:35:53:77:7c:c2:dd:a6:1c:3c:50:
        15:ea:dd:a6:98:35:94:dc:1a:e0:57:26:4d:b8:c8:
        1f:8b:9c:bb:5c:bd:48:a8:cd:1c:8a:d7:9d:5e:4f:
        90:06:e1:3a:ac:50:52:c0:23:a3:7c:0e:35:7d:71:
        8a:cd:19:fe:29:21:8f:4b:44:68:9f:bd:72:15:f8:
        1e:3d:33:0f:1d:ca:72:d4:1b:f9:3f:7a:bc:f9:28:
        a6:23
    Exponent: 65537 (0x10001)
   </pk>
   <X509v3-Extensions>
    <extension name="X509v3 Subject Alternative Name"><![CDATA[DNS:www.iis.se, DNS:iis.se]]></extension>
    <extension name="X509v3 Basic Constraints" level="critical"><![CDATA[CA:FALSE]]></extension>
    <extension name="X509v3 CRL Distribution Points"><![CDATA[URI:http://svr-ov-crl.thawte.com/ThawteOV.crl
]]></extension>
    <extension name="X509v3 Extended Key Usage"><![CDATA[TLS Web Server Authentication, TLS Web Client Authentication]]></extension>
    <extension name="Authority Information Access"><![CDATA[OCSP - URI:http://ocsp.thawte.com
]]></extension>
   </X509v3-Extensions>
  </certificate>
  <renegotiation supported="0" secure="0" />
 </ssltest>
</document>
