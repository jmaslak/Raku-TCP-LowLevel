use v6;

#
# Copyright © 2018-2022 Joelle Maslak
# All Rights Reserved - See License
#
# Some of this is "borrowed" from https://docs.perl6.org/language/nativecall .
# I do not have copyright to that, so those portions are not subject to my
# copyright.
#

use StrictClass;
unit class TCP::LowLevel:ver<0.1.1>:auth<zef:jmaslak> does StrictClass;

use if;
use TCP::LowLevel::Socket-Linux:if($*KERNEL.name eq 'linux');

our $linux = $*KERNEL.name eq 'linux';

#
# Public attributes
#
has Str:D     $.my-host     is rw = '0.0.0.0';
has UInt:D    $.my-port     is rw = 0;
has Promise:D $.socket-port = Promise.new;
has           $.sock        is rw;
has Str:D     %!md5;

# Aliases for socket-(port|host)
method socket-host { return $.my-host }

method listen(-->Nil) {
    if $linux {
        $!sock = TCP::LowLevel::Socket-Linux.new(:$.my-host, :$.my-port);
        for %!md5.keys -> $key { $!sock.add-md5($key, %!md5{$key}) }

        $!sock.socket.sink;
        $!sock.set-reuseaddr;
        $!sock.bind;
        $!sock.listen;

        $!socket-port.keep($!sock.find-bound-port);
    } else {
        $!sock = IO::Socket::Async.listen($.my-host, $.my-port);
    }
}

# Start accepting connections
method acceptor(-->Supply:D) {
    if $linux {
        return $!sock.acceptor;
    } else {
        my $supply = Supplier::Preserving.new();
        
        my $tap = $!sock.tap( { $supply.emit($_) } );

        await $tap.socket-port;
        $!socket-port.keep( $tap.socket-port.result );

        return $supply.Supply();
    }
}

method connect(Str:D $host, Int:D $port -->Promise) {
    if $linux {
        $!sock = TCP::LowLevel::Socket-Linux.new(:$.my-host, :$.my-port);
        for %!md5.keys -> $key { $!sock.add-md5($key, %!md5{$key}) }
        return $!sock.connect($host, $port);
    } else {
        return IO::Socket::Async.connect($host, $port);
    }
}

method close(-->Nil) {
    $!sock.close;
}

method add-md5(Str:D $host, Str $MD5 -->Nil) {
    if ! $linux { die("Cannot configure MD5 on this operating system") }

    %!md5{ $host.fc } = $MD5;
}

method supports-md5(-->Bool:D) {
    return False if ! $linux;
    return TCP::LowLevel::Socket-Linux.supports-md5;
}

=begin pod

=head1 NAME

TCP::LowLevel - Raku bindings for NativeCall TCP on Linux w/ Non-NativeCall Fallback`

=head1 SYNOPSIS

=head2 SERVER

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

=head2 CLIENT

  use TCP::LowLevel;

  react {
    my $client = TCP::LowLevel.new;
    my $conn   = $client.connect('127.0.0.1', 12345).result;

    $conn.print("Hello!");

    whenever $conn.Supply -> $msg{
      say "Received: $msg";
    }
  }

=head1 DESCRIPTION

On Linux, this module utilizes NativeCall to use the low level socket library
in an asyncronous way.  This allows enhanced functionality, such as the use
of the MD5 authentication header option (see internet RFC 2385).  When not
using Linux, this module is essentially a factory for the built-in asyncronous
network libraries, although functionality such as MD5 authentication headers
is not available in this mode.

=head1 WARNING

This module may experience some interface changes as I determine the best
possible interface. I will however try to keep the existing public interface
working as documented in this documentation.

=head1 ATTRIBUTES

=head2 my-host

  my $server = TCP::LowLevel.new(:my-host('127.0.0.1'));

This is the source IP used to create the socket.  It defaults to 0.0.0.0,
which represents all IPv4 addresses on the system.  You can set this to C<::>
if your host supports IPv6, to allow listenig on both IPv4 and IPv6 addresses.

Setting the value of this attribute is only supported at consturction time as
an argument to the constructor.

=head2 my-port

  my $server = TCP::LowLevel.new(:my-port(55666));

This is the source port used to create the socket.  It defaults to 0, meaning
to assign a random source port.  This is usually set if you desire to create
a listening socket on a static port number.

Setting the value of this attribute is only supported at consturction time as
an argument to the constructor.

=head2 socket-port

  my $port = $server.socket-port.result;

This contains a promise that is kept when the source port being actively used
is known.  This is useful when listening on a random port, to determine what
port was selected.  Note that this value will not necessaril be the same as
the value of C<my-port>, as C<my-port> may be zero, while this will never
return zero.

This value is not settable by the user.

=head2 sock

This contains the socket object belonging to a current connection.  It is not
anticipated that this would be used directly.

=head1 METHODS

=head2 listen

  $server.listen;

This creates a listening socket on the address specified by C<my-host> and the
port specified by C<my-port>.

=head2 acceptor

  whenever $server.acceptor -> $conn { … }

This, when executed on a listening socket (one which you previously had
called C<listen()> on) will create a supply of connections, with a new
connection emitted for every new connection.

=head2 connect

  my $conn = $client.connect('127.0.0.1', 8888).result;

Creates a TCP connection to the destination address and port provided.  This
returns a promise that when kept will contain the actual connection object.

=head2 close

  $server.close;

Closes a listening socket.

=head2 add-md5($host, $key)

  my $server = TCP::LowLevel.new;
  $client-tcp.add-md5('127.0.0.1', $key);
  $server-tcp.listen;

On Linux systems, this module supports RFC 2385 MD5 TCP authentication, which
is often used for BGP connections.

It takes two parameters, the host that the MD5 key applies to and the actual
key.

This can be used on inbound or outbound connections.

This will throw an exception if MD5 is not supported on the platform.

=head2 supports-md5

  die("No MD5 support") unless TCP::LowLevel.supports-md5;

Returns C<True> if MD5 authentication is supported on the platform, C<False>
otherwise.

=head1 USING CONNECTION OBJECTS

The objects returned by the C<acceptor> Supply or the C<connect()> Promise
may be Raku native objects or the wrapper around the Linux networking
libraries.

=head2 METHODS

=head3 Supply(:$bin?)

  whenever $conn.Supply(:bin) -> $msg { … }

This returns a supply that emits received messages.  If C<:bin> is C<True>,
the messages are returned as C<buf8> objects, othrwise they are returned as
C<Str> objects.

=head3 print($msg)

  $conn.print("Hello world!\n");

This sends a C<Str> across the TCP session.

=head3 write($msg)

  $conn.write($msg)

This sends a C<buf8> across the TCP session.

=head1 AUTHOR

Joelle Maslak <jmaslak@antelope.net>

=head1 COPYRIGHT AND LICENSE

Copyright © 2018-2022 Joelle Maslak

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod

