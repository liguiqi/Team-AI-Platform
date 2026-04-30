#!/usr/bin/env python3
import argparse
import asyncore
import ipaddress
import os
import signal
import smtplib
import smtpd
import sys
from typing import Iterable


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Local SMTP relay for Casdoor")
    parser.add_argument("--listen-host", default="0.0.0.0")
    parser.add_argument("--listen-port", type=int, default=2525)
    parser.add_argument("--remote-host", default=os.getenv("LOCAL_SMTP_RELAY_REMOTE_HOST"))
    parser.add_argument(
        "--remote-port",
        type=int,
        default=int(os.getenv("LOCAL_SMTP_RELAY_REMOTE_PORT", "465")),
    )
    parser.add_argument("--remote-user", default=os.getenv("LOCAL_SMTP_RELAY_REMOTE_USER"))
    parser.add_argument(
        "--remote-password",
        default=os.getenv("LOCAL_SMTP_RELAY_REMOTE_PASSWORD"),
    )
    parser.add_argument(
        "--remote-ssl-mode",
        default=os.getenv("LOCAL_SMTP_RELAY_REMOTE_SSL_MODE", "Enable"),
    )
    parser.add_argument("--allowed-cidrs", default="127.0.0.0/8,172.16.0.0/12")
    args = parser.parse_args()
    missing = []
    for name in ("remote_host", "remote_user", "remote_password"):
        if not getattr(args, name):
            missing.append(name)
    if missing:
        parser.error(f"missing relay settings: {', '.join(missing)}")
    return args


def parse_networks(cidr_text: str) -> list[ipaddress._BaseNetwork]:
    networks = []
    for item in cidr_text.split(","):
        item = item.strip()
        if item:
            networks.append(ipaddress.ip_network(item, strict=False))
    return networks


def ip_allowed(ip_text: str, networks: Iterable[ipaddress._BaseNetwork]) -> bool:
    ip_obj = ipaddress.ip_address(ip_text)
    return any(ip_obj in network for network in networks)


class RelayServer(smtpd.SMTPServer):
    def __init__(self, localaddr, remoteaddr, *, args: argparse.Namespace):
        super().__init__(localaddr, remoteaddr, decode_data=False)
        self.args = args
        self.allowed_networks = parse_networks(args.allowed_cidrs)

    def process_message(self, peer, mailfrom, rcpttos, data, **kwargs):
        peer_ip = peer[0]
        if not ip_allowed(peer_ip, self.allowed_networks):
            print(f"[WARN] reject peer={peer_ip}", flush=True)
            return "550 relay access denied"

        print(
            f"[INFO] relay peer={peer_ip} from={mailfrom} to={','.join(rcpttos)} bytes={len(data)}",
            flush=True,
        )

        ssl_mode = (self.args.remote_ssl_mode or "Enable").lower()
        if ssl_mode == "disable":
            client = smtplib.SMTP(self.args.remote_host, self.args.remote_port, timeout=30)
        elif self.args.remote_port == 465:
            client = smtplib.SMTP_SSL(self.args.remote_host, self.args.remote_port, timeout=30)
        else:
            client = smtplib.SMTP(self.args.remote_host, self.args.remote_port, timeout=30)
            client.ehlo()
            client.starttls()
            client.ehlo()

        with client:
            client.login(self.args.remote_user, self.args.remote_password)
            client.sendmail(mailfrom, rcpttos, data)

        print("[INFO] relay delivered", flush=True)
        return None


def main() -> int:
    args = parse_args()
    server = RelayServer((args.listen_host, args.listen_port), None, args=args)

    def shutdown(signum, frame):
        del signum, frame
        print("[INFO] relay shutting down", flush=True)
        server.close()
        asyncore.close_all()
        raise SystemExit(0)

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)

    print(
        f"[INFO] relay listening on {args.listen_host}:{args.listen_port} -> "
        f"{args.remote_host}:{args.remote_port} ({args.remote_ssl_mode})",
        flush=True,
    )
    try:
        asyncore.loop()
    except KeyboardInterrupt:
        shutdown(None, None)
    return 0


if __name__ == "__main__":
    sys.exit(main())
