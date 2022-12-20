[![Build Status](https://travis-ci.org/jmaslak/Raku-TCP-LowLevel.svg?branch=master)](https://travis-ci.org/jmaslak/Raku-TCP-LowLevel)

NAME
====

TCP::LowLevel - Raku bindings for NativeCall TCP on Linux w/ Non-NativeCall Fallback`

SYNOPSIS
========

SERVER
------

    use TCP::LowLevel;

    react {
      my $server = TCP::LowLevel.new;
      $server-tcp.listen;
      whenever $server-tcp.acceptor -> $conn {
        whenever $conn.Supply -> $msg {
          say "Received: $msg";
        }
      }

      say "Listening on port: " ~ $server.socket-port.result;
    }

CLIENT
------

    use TCP::LowLevel;

    react {
      my $client = TCP::LowLevel.new;
      my $conn   = $client.connect('127.0.0.1', 12345).result;

      $conn.print("Hello!");

      whenever $conn.Supply -> $msg{
        say "Received: $msg";
      }
    }

DESCRIPTION
===========

On Linux, this module utilizes NativeCall to use the low level socket library in an asyncronous way. This allows enhanced functionality, such as the use of the MD5 authentication header option (see internet RFC 2385). When not using Linux, this module is essentially a factory for the built-in asyncronous network libraries, although functionality such as MD5 authentication headers is not available in this mode.

WARNING
=======

This module may experience some interface changes as I determine the best possible interface. I will however try to keep the existing public interface working as documented in this documentation.

ATTRIBUTES
==========

my-host
-------

    my $server = TCP::LowLevel.new(:my-host('127.0.0.1'));

This is the source IP used to create the socket. It defaults to 0.0.0.0, which represents all IPv4 addresses on the system. You can set this to `::` if your host supports IPv6, to allow listenig on both IPv4 and IPv6 addresses.

Setting the value of this attribute is only supported at consturction time as an argument to the constructor.

my-port
-------

    my $server = TCP::LowLevel.new(:my-port(55666));

This is the source port used to create the socket. It defaults to 0, meaning to assign a random source port. This is usually set if you desire to create a listening socket on a static port number.

Setting the value of this attribute is only supported at consturction time as an argument to the constructor.

socket-port
-----------

    my $port = $server.socket-port.result;

This contains a promise that is kept when the source port being actively used is known. This is useful when listening on a random port, to determine what port was selected. Note that this value will not necessaril be the same as the value of `my-port`, as `my-port` may be zero, while this will never return zero.

This value is not settable by the user.

sock
----

This contains the socket object belonging to a current connection. It is not anticipated that this would be used directly.

METHODS
=======

listen
------

    $server.listen;

This creates a listening socket on the address specified by `my-host` and the port specified by `my-port`.

acceptor
--------

    whenever $server.acceptor -> $conn { … }

This, when executed on a listening socket (one which you previously had called `listen()` on) will create a supply of connections, with a new connection emitted for every new connection.

connect
-------

    my $conn = $client.connect('127.0.0.1', 8888).result;

Creates a TCP connection to the destination address and port provided. This returns a promise that when kept will contain the actual connection object.

close
-----

    $server.close;

Closes a listening socket.

add-md5($host, $key)
--------------------

    my $server = TCP::LowLevel.new;
    $client-tcp.add-md5('127.0.0.1', $key);
    $server-tcp.listen;

On Linux systems, this module supports RFC 2385 MD5 TCP authentication, which is often used for BGP connections.

It takes two parameters, the host that the MD5 key applies to and the actual key.

This can be used on inbound or outbound connections.

This will throw an exception if MD5 is not supported on the platform.

supports-md5
------------

    die("No MD5 support") unless TCP::LowLevel.supports-md5;

Returns `True` if MD5 authentication is supported on the platform, `False` otherwise.

USING CONNECTION OBJECTS
========================

The objects returned by the `acceptor` Supply or the `connect()` Promise may be Raku native objects or the wrapper around the Linux networking libraries.

METHODS
-------

### Supply(:$bin?)

    whenever $conn.Supply(:bin) -> $msg { … }

This returns a supply that emits received messages. If `:bin` is `True`, the messages are returned as `buf8` objects, othrwise they are returned as `Str` objects.

### print($msg)

    $conn.print("Hello world!\n");

This sends a `Str` across the TCP session.

### write($msg)

    $conn.write($msg)

This sends a `buf8` across the TCP session.

AUTHOR
======

Joelle Maslak <jmaslak@antelope.net>

COPYRIGHT AND LICENSE
=====================

Copyright © 2018-2022 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

