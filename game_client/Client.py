__author__ = 'wchill'

import asyncore
import socket


class Client(asyncore.dispatcher):
    def __init__(self, host, port):
        asyncore.dispatcher.__init__(self)
        self.create_socket(socket.AF_INET, socket.SOCK_STREAM)
        self.connect((host, port))

        # initialize buffer for partial reads
        self.buffer = ''

        # initialize hash table for event handlers
        self.handlers = {}

    def handle_connect(self):
        print 'Connected to', self.host

    def handle_close(self):
        self.close()

    def handle_write(self):
        self.send('')

    def handle_read(self):
        # initialize 8kb buffer
        read = self.recv(8192)
        if not read:
            self.close()
            return
        self.buffer += read
        sp = self.buffer.split('\n')
        if len(sp) > 1:
            last_shot = None
            last_hit = None
            last_reload = None
            if self.buffer[:-1] == '\n':
                self.buffer = ''
            else:
                self.buffer = sp[-1]
                sp = sp[:-1]
            for event in sp:
                if event[0] == 'F':
                    last_shot = event
                    last_hit, last_reload = self.put(last_hit, last_reload)
                elif event[0] == 'A':
                    last_hit = event
                    last_shot, last_reload = self.put(last_shot, last_reload)
                elif event[0] == 'R':
                    last_reload = event
                    last_shot, last_hit = self.put(last_shot, last_hit)
                else:
                    self.queue.put(event)
            self.put(last_shot, last_hit, last_reload)

    def event(self, event_type, event_data):
        if event_type not in self.handlers:
            print 'No handler for event %s! (%s)' % event_type, event_data
            return
        self.handlers[event_type](event_data)

    def add_handler(self, event_type, event_handler):
        self.handlers[event_type] = event_handler
        print 'Added handler for event %s' % event_type

    def put(self, e1=None, e2=None, e3=None):
        if e1 is not None:
            self.queue.put(e1)
            e1 = None
        if e2 is not None:
            self.queue.put(e2)
            e2 = None
        if e3 is not None:
            self.queue.put(e3)
            e3 = None
        return e1, e2
