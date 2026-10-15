#!/usr/bin/env python3
"""Servidor de mentira de Supabase Realtime (WebSocket + protocolo Phoenix «vsn 1.0.0») para probar godot/game/online/realtime.gd y world_sync.gd sin red ni cuenta.
Sólo biblioteca estándar (asyncio): no hace falta instalar nada. Hace lo justo:
  · apretón de manos WebSocket en /realtime/v1/websocket?apikey=…&vsn=1.0.0 (rechaza si la apikey no es la esperada)
  · phx_join / phx_leave / heartbeat / access_token, con respuestas «phx_reply»
  · canales PRIVADOS: sólo entra quien trae un token «user:<id>» (cuenta con correo) y el tema empieza con «realtime:world:»; con otro token (p. ej. «anon») contesta «sin permiso»,
    como las políticas de realtime.messages (supabase/migrations/20261012000000_realtime_private.sql)
  · broadcast: reenvía a los demás del canal (a uno mismo sólo si config.broadcast.self = true)
  · presence: track → presence_diff para todos; al entrar manda presence_state; al irse manda la baja
  · ganchos de prueba: evento «__test_drop» (corta el socket sin avisar), «__test_stats» (devuelve contadores) y «__test_kick» (phx_close del canal)
  · red «de teléfono» opcional (--lag y --jitter en ms): cada broadcast le llega a cada uno con una demora de lag + azar(0, jitter), en orden (como un 4G)
Uso: python3 tools/online/mock_realtime.py [--port 0] [--apikey testkey] [--lag 0] [--jitter 0]   (imprime «PORT <n>» al arrancar)"""
import argparse
import asyncio
import base64
import hashlib
import json
import random
import struct
import sys
import urllib.parse

GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'


class Member:
    def __init__(self, client, key, self_echo):
        self.client = client
        self.key = key
        self.self_echo = self_echo
        self.meta = None
        self.ref = 0


LAG = 0.0
JITTER = 0.0


class Client:
    _n = 0

    def __init__(self, reader, writer):
        Client._n += 1
        self.id = Client._n
        self.reader = reader
        self.writer = writer
        self.token = ''
        self.topics = set()

    @property
    def uid(self):
        return self.token[5:] if self.token.startswith('user:') else ''

    async def send_json(self, obj):
        data = json.dumps(obj, separators=(',', ':')).encode()
        if (LAG > 0 or JITTER > 0) and obj.get('event') == 'broadcast':
            loop = asyncio.get_running_loop()
            due = max(getattr(self, '_last_due', 0.0), loop.time() + LAG + random.uniform(0.0, JITTER))
            self._last_due = due
            if not hasattr(self, '_q'):
                self._q = asyncio.Queue()
                asyncio.ensure_future(self._pump())
            await self._q.put((due, data))
            return
        await self.send_frame(1, data)

    async def _pump(self):
        loop = asyncio.get_running_loop()
        while True:
            due, data = await self._q.get()
            wait = due - loop.time()
            if wait > 0:
                await asyncio.sleep(wait)
            try:
                await self.send_frame(1, data)
            except Exception:
                return

    async def send_frame(self, opcode, payload):
        n = len(payload)
        head = bytes([0x80 | opcode])
        if n < 126:
            head += bytes([n])
        elif n < 65536:
            head += bytes([126]) + struct.pack('>H', n)
        else:
            head += bytes([127]) + struct.pack('>Q', n)
        try:
            self.writer.write(head + payload)
            await self.writer.drain()
        except Exception:
            pass


class Server:
    def __init__(self, apikey):
        self.apikey = apikey
        self.topics = {}  # tema → {Client: Member}
        self.stats = {'joins': 0, 'denied': 0, 'broadcasts_in': 0, 'broadcasts_out': 0, 'heartbeats': 0, 'connections': 0, 'closed': 0}
        self.per_topic = {}  # tema → mensajes de broadcast recibidos

    async def read_frame(self, reader):
        msg = b''
        op = None
        while True:
            h = await reader.readexactly(2)
            fin = h[0] & 0x80
            opcode = h[0] & 0x0F
            masked = h[1] & 0x80
            n = h[1] & 0x7F
            if n == 126:
                n = struct.unpack('>H', await reader.readexactly(2))[0]
            elif n == 127:
                n = struct.unpack('>Q', await reader.readexactly(8))[0]
            mask = await reader.readexactly(4) if masked else b''
            data = await reader.readexactly(n) if n else b''
            if masked:
                data = bytes(b ^ mask[i % 4] for i, b in enumerate(data))
            if opcode in (8, 9, 10):
                return opcode, data
            if op is None:
                op = opcode
            msg += data
            if fin:
                return op, msg

    async def handle(self, reader, writer):
        try:
            head = await reader.readuntil(b'\r\n\r\n')
        except Exception:
            writer.close()
            return
        lines = head.decode('latin1').split('\r\n')
        path = lines[0].split(' ')[1] if len(lines[0].split(' ')) > 1 else ''
        hdr = {}
        for ln in lines[1:]:
            if ':' in ln:
                k, v = ln.split(':', 1)
                hdr[k.strip().lower()] = v.strip()
        u = urllib.parse.urlparse(path)
        q = urllib.parse.parse_qs(u.query)
        if u.path != '/realtime/v1/websocket' or q.get('apikey', [''])[0] != self.apikey or 'sec-websocket-key' not in hdr:
            writer.write(b'HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\nConnection: close\r\n\r\n')
            await writer.drain()
            writer.close()
            return
        acc = base64.b64encode(hashlib.sha1((hdr['sec-websocket-key'] + GUID).encode()).digest()).decode()
        writer.write(('HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: %s\r\n\r\n' % acc).encode())
        await writer.drain()
        c = Client(reader, writer)
        self.stats['connections'] += 1
        try:
            while True:
                op, data = await self.read_frame(reader)
                if op == 8:
                    await c.send_frame(8, data[:2])
                    break
                if op == 9:
                    await c.send_frame(10, data)
                    continue
                if op in (1, 2):
                    try:
                        m = json.loads(data.decode())
                    except Exception:
                        continue
                    if isinstance(m, dict):
                        await self.on_message(c, m)
        except (asyncio.IncompleteReadError, ConnectionError, OSError):
            pass
        finally:
            await self.drop(c)
            try:
                writer.close()
            except Exception:
                pass

    async def drop(self, c):
        self.stats['closed'] += 1
        for t in list(c.topics):
            await self.leave(c, t, notify=True)

    async def reply(self, c, m, status='ok', response=None):
        await c.send_json({'topic': m.get('topic'), 'event': 'phx_reply', 'ref': m.get('ref'), 'payload': {'status': status, 'response': response or {}}})

    async def on_message(self, c, m):
        topic = m.get('topic', '')
        ev = m.get('event', '')
        payload = m.get('payload') or {}
        if topic == 'phoenix' and ev == 'heartbeat':
            self.stats['heartbeats'] += 1
            if LAG > 0:
                await asyncio.sleep(LAG)  # (ida y vuelta: el latido también cruza la red «de teléfono»; LAG por tramo, sin el azar)
            await self.reply(c, m)
            return
        if ev == '__test_drop':
            c.writer.transport.abort()  # se corta sin cerrar bien (como una caída de red)
            return
        if ev == '__test_stats':
            await self.reply(c, m, 'ok', dict(self.stats, per_topic=self.per_topic, topics={t: len(ms) for t, ms in self.topics.items()}))
            return
        if ev == '__test_kick':
            for t, members in list(self.topics.items()):
                if t == topic:
                    for mem in list(members.values()):
                        await mem.client.send_json({'topic': t, 'event': 'phx_close', 'payload': {}, 'ref': None})
            return
        if ev == 'phx_join':
            await self.join(c, m, topic, payload)
        elif ev == 'phx_leave':
            await self.leave(c, topic, notify=True)
            await self.reply(c, m)
        elif ev == 'access_token':
            c.token = str(payload.get('access_token', ''))
            await self.reply(c, m)
        elif ev == 'broadcast':
            mem = self.topics.get(topic, {}).get(c)
            if mem is None:
                return
            self.stats['broadcasts_in'] += 1
            self.per_topic[topic] = self.per_topic.get(topic, 0) + 1
            for other in list(self.topics[topic].values()):
                if other.client is c and not other.self_echo:
                    continue
                self.stats['broadcasts_out'] += 1
                await other.client.send_json({'topic': topic, 'event': 'broadcast', 'payload': payload, 'ref': None})
        elif ev == 'presence':
            mem = self.topics.get(topic, {}).get(c)
            if mem is None or payload.get('event') != 'track':
                return
            mem.ref += 1
            mem.meta = dict(payload.get('payload') or {}, phx_ref=str(mem.ref))
            await self.fan(topic, 'presence_diff', {'joins': {mem.key: {'metas': [mem.meta]}}, 'leaves': {}})
            await self.reply(c, m)

    async def join(self, c, m, topic, payload):
        cfg = payload.get('config') or {}
        tok = str(payload.get('access_token', ''))
        c.token = tok or c.token
        private = bool(cfg.get('private', False))
        if private and (not c.uid or not topic.startswith('realtime:world:')):
            self.stats['denied'] += 1
            await self.reply(c, m, 'error', {'reason': 'You do not have permissions to read from this Channel topic: %s' % topic})
            return
        key = str((cfg.get('presence') or {}).get('key', '')) or ('anon%d' % c.id)
        self_echo = bool((cfg.get('broadcast') or {}).get('self', False))
        members = self.topics.setdefault(topic, {})
        members[c] = Member(c, key, self_echo)
        c.topics.add(topic)
        self.stats['joins'] += 1
        await self.reply(c, m, 'ok', {'postgres_changes': []})
        state = {mem.key: {'metas': [mem.meta]} for mem in members.values() if mem.meta is not None}
        await c.send_json({'topic': topic, 'event': 'presence_state', 'payload': state, 'ref': None})

    async def leave(self, c, topic, notify):
        members = self.topics.get(topic)
        if not members or c not in members:
            return
        mem = members.pop(c)
        c.topics.discard(topic)
        if not members:
            del self.topics[topic]
        elif notify and mem.meta is not None:
            await self.fan(topic, 'presence_diff', {'joins': {}, 'leaves': {mem.key: {'metas': [mem.meta]}}})

    async def fan(self, topic, event, payload):
        for mem in list(self.topics.get(topic, {}).values()):
            await mem.client.send_json({'topic': topic, 'event': event, 'payload': payload, 'ref': None})


async def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--port', type=int, default=0)
    ap.add_argument('--apikey', default='testkey')
    ap.add_argument('--lag', type=float, default=0.0)
    ap.add_argument('--jitter', type=float, default=0.0)
    a = ap.parse_args()
    global LAG, JITTER
    LAG = a.lag / 1000.0
    JITTER = a.jitter / 1000.0
    srv = Server(a.apikey)
    server = await asyncio.start_server(srv.handle, '127.0.0.1', a.port)
    port = server.sockets[0].getsockname()[1]
    print('PORT %d' % port, flush=True)
    async with server:
        await server.serve_forever()


if __name__ == '__main__':
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        sys.exit(0)
