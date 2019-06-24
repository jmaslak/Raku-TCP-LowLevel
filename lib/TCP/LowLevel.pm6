use v6;

#
# Copyright © 2018-2019 Joelle Maslak
# All Rights Reserved - See License
#
# Some of this is "borrowed" from https://docs.perl6.org/language/nativecall .
# I do not have copyright to that, so those portions are not subject to my
# copyright.
#

use StrictClass;
unit class TCP::LowLevel:ver<0.0.1>:auth<cpan:JMASLAK> does StrictClass;

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
method socket-post { return $.my-post }

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

