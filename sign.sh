#!/bin/sh

# This script signs a Windows executable using osslsigncode with a YubiKey.
# It creates a dual signature: SHA-1 for legacy compatibility and SHA-256 with RFC 3161 timestamp.
# It uses OpenSSL3, OpenSC, connected YubiKey, exported certificate from YubiKey access and requires a patched version of osslsigncode.

# Installation (https://www.pjrc.com/how-to-cross-compile-and-sign-windows-exe-on-linux-with-yubikey-token/)
# sudo apt install yubikey-manager osslsigncode ykcs11 libengine-pkcs11-openssl opensc pcscd

# Patched osslsigncode: https://github.com/naviter/osslsigncode.git

# Config
NAME="NAVITER, d.o.o."
URI="http://naviter.com"
TIMESERVER="http://timestamp.digicert.com"
PKCS11_MODULE="/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so"
CERTS="./cert.pem"
KEY="pkcs11:pin-value=xxxxxxxx"

# Input validation
INPUT=$1
if [ -z "$INPUT" ]; then
  echo "Usage: $0 <input-file>"
  exit 1
fi
if [ ! -f "$INPUT" ]; then
  echo "Error: Input file '$INPUT' not found."
  exit 1
fi
INPUT_TEMP="temp.exe"
OUTPUT="signed.exe"

# Check if YubiKey is connected
if ! opensc-tool -l | grep -q YubiKey; then
  echo "🔌 YubiKey not detected. Please insert it and try again."
  exit 1
fi

# Remove previous executable
rm -rf $INPUT_TEMP $OUTPUT

# Step 1: SHA-1 signature (legacy compatibility)
./osslsigncode sign \
  -pkcs11module $PKCS11_MODULE \
  -certs $CERTS \
  -key $KEY \
  -h sha1 \
  -n "$NAME" \
  -i $URI \
  -t $TIMESERVER \
  -in $INPUT \
  -out $INPUT_TEMP || exit 1

# Step 2: SHA-256 dual-signature with RFC 3161 timestamp
./osslsigncode sign \
  -pkcs11module $PKCS11_MODULE \
  -certs $CERTS \
  -key $KEY \
  -h sha256 \
  -nest \
  -n "$NAME" \
  -i $URI \
  -ts $TIMESERVER \
  -in $INPUT_TEMP \
  -out $OUTPUT || exit 1

# Step 3: Clean up
rm -rf $INPUT_TEMP
echo "✅ Successfully signed $INPUT with SHA-1 and SHA-256 signatures."
echo "🔒 The signed file is: $OUTPUT"

exit 0
