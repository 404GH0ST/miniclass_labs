#!/usr/bin/env python3
"""Minimal, intentionally enumerable POP3/IMAP server for an isolated lab."""

import os
import socketserver
import threading


HOST = os.getenv("WRI_MAIL_HOST", "192.168.56.50")
POP3_PORT = int(os.getenv("WRI_POP3_PORT", "110"))
IMAP_PORT = int(os.getenv("WRI_IMAP_PORT", "143"))
USERNAME = "analyst"
PASSWORD = "MailLab-Only-2026"
SSH_USERNAME = "operator"
SSH_PASSWORD = "LlYcvWqWdJKvvnNmlruUY/bb"
POP3_FLAG = os.getenv("WRI_POP3_FLAG", "WRI{deployment_flag_missing}")
IMAP_FLAG = os.getenv("WRI_IMAP_FLAG", "WRI{deployment_flag_missing}")

BASE_MESSAGE = (
    "From: mentor@wri.local\r\n"
    "To: analyst@wri.local\r\n"
    "Subject: Mail service verification\r\n"
    "\r\n"
    "The training mailbox is working.\r\n"
)


def messages_for(protocol, flag):
    return [
        BASE_MESSAGE,
        (
            "From: challenge@wri.local\r\n"
            "To: analyst@wri.local\r\n"
            f"Subject: {protocol} enumeration flag\r\n"
            "\r\n"
            f"Record this flag in the evidence sheet: {flag}\r\n"
        ),
        (
            "From: infrastructure@wri.local\r\n"
            "To: analyst@wri.local\r\n"
            "Subject: SSH training account\r\n"
            "\r\n"
            f"SSH username: {SSH_USERNAME}\r\n"
            f"SSH password: {SSH_PASSWORD}\r\n"
            "Use this account only against the isolated Week 5 target.\r\n"
        ),
    ]


POP3_MESSAGES = messages_for("POP3", POP3_FLAG)
IMAP_MESSAGES = messages_for("IMAP", IMAP_FLAG)


class ReusableThreadingServer(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


class Pop3Handler(socketserver.StreamRequestHandler):
    def send(self, text):
        self.wfile.write((text + "\r\n").encode())

    def handle(self):
        selected_user = None
        authenticated = False
        self.send("+OK WRI CySec POP3 training service ready")

        while line := self.rfile.readline(4096):
            parts = line.decode(errors="replace").strip().split()
            if not parts:
                continue
            command = parts[0].upper()
            argument = parts[1] if len(parts) > 1 else ""

            if command == "CAPA":
                self.send("+OK Capability list follows")
                self.send("USER")
                self.send("UIDL")
                self.send(".")
            elif command == "USER":
                selected_user = argument
                self.send("+OK password required")
            elif command == "PASS":
                authenticated = selected_user == USERNAME and argument == PASSWORD
                if authenticated:
                    self.send("+OK analyst mailbox opened")
                else:
                    self.send("-ERR authentication failed")
            elif command == "STAT" and authenticated:
                size = sum(len(message.encode()) for message in POP3_MESSAGES)
                self.send(f"+OK {len(POP3_MESSAGES)} {size}")
            elif command == "LIST" and authenticated:
                self.send(f"+OK {len(POP3_MESSAGES)} messages")
                for number, message in enumerate(POP3_MESSAGES, 1):
                    self.send(f"{number} {len(message.encode())}")
                self.send(".")
            elif command == "RETR" and authenticated:
                try:
                    message = POP3_MESSAGES[int(argument) - 1]
                except (ValueError, IndexError):
                    self.send("-ERR no such message")
                else:
                    self.send(f"+OK {len(message.encode())} octets")
                    self.wfile.write(message.encode())
                    self.send(".")
            elif command == "QUIT":
                self.send("+OK goodbye")
                break
            elif not authenticated:
                self.send("-ERR authenticate first")
            else:
                self.send("-ERR unsupported training command")


class ImapHandler(socketserver.StreamRequestHandler):
    def send(self, text):
        self.wfile.write((text + "\r\n").encode())

    def handle(self):
        authenticated = False
        self.send("* OK WRI CySec IMAP training service ready")

        while line := self.rfile.readline(4096):
            parts = line.decode(errors="replace").strip().split()
            if len(parts) < 2:
                continue
            tag, command = parts[0], parts[1].upper()
            arguments = parts[2:]

            if command == "CAPABILITY":
                self.send("* CAPABILITY IMAP4rev1 AUTH=PLAIN")
                self.send(f"{tag} OK CAPABILITY completed")
            elif command == "LOGIN" and len(arguments) >= 2:
                username = arguments[0].strip('"')
                password = arguments[1].strip('"')
                if username != USERNAME or password != PASSWORD:
                    self.send(f"{tag} NO authentication failed")
                else:
                    authenticated = True
                    self.send(f"{tag} OK LOGIN completed")
            elif command in {"SELECT", "EXAMINE"} and authenticated:
                self.send(f"* {len(IMAP_MESSAGES)} EXISTS")
                self.send("* 0 RECENT")
                self.send(f"{tag} OK [READ-ONLY] SELECT completed")
            elif command == "SEARCH" and authenticated:
                self.send("* SEARCH " + " ".join(str(index) for index in range(1, len(IMAP_MESSAGES) + 1)))
                self.send(f"{tag} OK SEARCH completed")
            elif command == "FETCH" and authenticated and arguments:
                try:
                    number = int(arguments[0])
                    message = IMAP_MESSAGES[number - 1]
                except (ValueError, IndexError):
                    self.send(f"{tag} NO no such message")
                else:
                    self.send(f"* {number} FETCH (BODY[] {{{len(message.encode())}}}")
                    self.wfile.write(message.encode())
                    self.send(")")
                    self.send(f"{tag} OK FETCH completed")
            elif command == "LOGOUT":
                self.send("* BYE logging out")
                self.send(f"{tag} OK LOGOUT completed")
                break
            elif not authenticated:
                self.send(f"{tag} NO authenticate first")
            else:
                self.send(f"{tag} BAD unsupported training command")


def serve(port, handler):
    with ReusableThreadingServer((HOST, port), handler) as server:
        server.serve_forever()


if __name__ == "__main__":
    pop3 = threading.Thread(target=serve, args=(POP3_PORT, Pop3Handler), daemon=True)
    pop3.start()
    serve(IMAP_PORT, ImapHandler)
