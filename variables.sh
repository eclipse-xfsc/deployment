#!/usr/bin/env bash
PROFILE=""
DOMAIN=""
EMAIL=""
DNSTOKEN=""
TENANT=""
DISABLE_EXTERNAL_DNS=false

usage() {
  echo "Usage: $0 --profile <profile> --domain <domain> --email <email> --tenant <tenant> [--dnstoken <token>] [--disable-external-dns]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile|--domain|--email|--dnstoken|--tenant)
      if [[ $# -lt 2 || -z "$2" || "$2" == --* ]]; then
        echo "Fehlender Wert für $1" >&2
        usage
        exit 1
      fi

      case "$1" in
        --profile)  PROFILE="$2" ;;
        --domain)   DOMAIN="$2" ;;
        --email)    EMAIL="$2" ;;
        --dnstoken) DNSTOKEN="$2" ;;
        --tenant)   TENANT="$2" ;;
      esac
      shift 2
      ;;
    --disable-external-dns)
      DISABLE_EXTERNAL_DNS=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown parameter: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$PROFILE" || -z "$DOMAIN" || -z "$EMAIL" || -z "$TENANT" ]]; then
  usage
  exit 1
fi

export PROFILE DOMAIN EMAIL DNSTOKEN TENANT DISABLE_EXTERNAL_DNS