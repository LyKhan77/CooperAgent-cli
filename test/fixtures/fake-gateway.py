#!/usr/bin/env python3
"""Gateway tiruan untuk uji setup.

Menyajikan kontrak /v1/models yang sama bentuknya dengan gateway sungguhan.
Ada supaya uji tidak menunjuk ke produksi: hasil uji yang bergantung pada
keadaan server bukan uji, melainkan pemantauan.

Angka bawaannya SAMA dengan produksi per 2 September 2026 -- uji di sini
memeriksa perilaku, bukan kepekaan terhadap nilai. Yang memeriksa kepekaan
adalah test-contract-from-gateway.sh, dan ia memakai angka yang sengaja beda.
"""
import json, sys
from http.server import BaseHTTPRequestHandler, HTTPServer

C = {"object": "list",
     "data": [{"id": "intercon-agent", "object": "model",
               "context_window": 131072, "max_tokens": 12288}],
     "cooperagent": {"contract_version": 1, "model_id": "intercon-agent",
                     "context_window": 131072, "max_tokens": 12288,
                     "compaction": {"threshold_percent": 80, "threshold_tokens": 104857},
                     "context_source": "upstream", "endpoints": [], "upstreams": []}}

class H(BaseHTTPRequestHandler):
    def do_GET(self):
        b = json.dumps(C).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)
    def log_message(self, *a):
        pass

HTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
