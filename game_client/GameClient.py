__author__ = 'wchill'

from twisted.internet import reactor, protocol
from twisted.protocols.basic import LineReceiver
from Queue import Queue

class GameClient(LineReceiver):

    def __init__(self, queue, listeners):
        self.delimiter = '\n'
        self.buffer = ''
        self.queue = queue
        self.listeners = listeners

    def connectionMade(self):
        print "Connection to server made"

    def lineReceived(self, line):
        event = line.split('\t')
        if event[0] in self.listeners:
            self.listeners[event[0]](event, self.queue)

    def connectionLost(self, reason):
        print "Connection to server lost: {0}".format(reason)



class GameFactory(protocol.ClientFactory):
    protocol = GameClient

    def __init__(self, queue=Queue(), listeners=None):
        self.queue = queue
        if listeners is None:
            listeners = {}
        self.listeners = listeners

    def clientConnectionFailed(self, connector, reason):
        print "Connection to server failed: {0}".format(reason)
        reactor.stop()

    def clientConnectionLost(self, connector, reason):
        print "Connection to server lost: {0}".format(reason)
        reactor.stop()

    def setQueue(self, queue):
        self.queue = queue

    def setListeners(self, listeners):
        self.listeners = listeners

    def buildProtocol(self, addr):
        return GameClient(self.queue, self.listeners)

def event_test(event, queue):
    print event

def event_attacked(event, queue):
    print event

def event_fire(event, queue):
    print event

def event_reload(event, queue):
    print event

def event_connect(event, queue):
    print event

def main():
    q = Queue()
    listeners = {'A': event_attacked, 'F': event_fire, 'R': event_reload, 'C': event_connect}
    f = GameFactory(q, listeners)
    reactor.connectTCP("hostname", 50000, f)
    reactor.run()

# this only runs if the module was *not* imported
if __name__ == '__main__':
    main()